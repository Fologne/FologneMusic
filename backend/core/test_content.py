from unittest.mock import patch

from django.core.cache import cache
from django.test import SimpleTestCase
from django.urls import reverse

from core.providers import ProviderError

TRACK = {"title": "Usseewa", "artist": "Ado", "album": "Kyōgen", "duration_ms": 202000}


def row(provider_id, duration=202, **fields):
    return {
        "id": provider_id,
        "trackName": "Usseewa",
        "artistName": "Ado",
        "albumName": "Kyōgen",
        "duration": duration,
        **fields,
    }


class TrackContentTests(SimpleTestCase):
    def setUp(self):
        cache.clear()
        self.addCleanup(cache.clear)

    def resolve(self, payload=None):
        return self.client.post(
            reverse("resolve-track"),
            TRACK if payload is None else payload,
            content_type="application/json",
        )

    def get(self, resource, reference, **query):
        return self.client.get(reverse(resource, args=[reference["id"]]), query)

    @patch("core.providers.get_json")
    def test_resolves_duration_and_reads_original_lyrics_without_offline_permission(self, upstream):
        upstream.side_effect = [
            [row(4), row(5, 216), {**row(6), "artistName": "Outro artista"}],
            row(4, plainLyrics="Linha de teste", syncedLyrics="[00:00.00]Linha de teste"),
        ]
        match = self.resolve().json()["match"]
        response = self.get("lyrics", match, language="pt-BR")
        self.assertEqual(response.status_code, 200)
        content = response.json()
        self.assertEqual(content["status"], "found")
        self.assertIsNone(content["language"])
        self.assertFalse(content["source"]["offline_allowed"])
        self.assertEqual(content["synced_lrc"], "[00:00.00]Linha de teste")
        self.assertIn("no-store", response["Cache-Control"])
        self.assertEqual(upstream.call_args.args[0], "https://lrclib.net/api/get/4")

    @patch("core.providers.get_json", return_value=[row(4), row(5)])
    def test_equal_recordings_require_selection_and_resolution_caches_metadata(self, upstream):
        data = self.resolve().json()
        self.assertEqual(data["status"], "ambiguous")
        self.assertIsNone(data["match"])
        self.assertEqual(len({item["track_key"] for item in data["candidates"]}), 2)
        self.resolve()
        upstream.assert_called_once()

    @patch("core.providers.get_json", side_effect=ProviderError("provider_rate_limited"))
    def test_lyrics_provider_failure_does_not_block_editorial_meaning(self, upstream):
        data = self.resolve().json()
        self.assertEqual(data["status"], "provider_rate_limited")
        fallback = data["metadata_match"]
        self.assertEqual(self.get("lyrics", fallback).json()["status"], "not_resolved")
        content = self.get("meaning", fallback).json()
        self.assertEqual(content["kind"], "artist_commentary")
        self.assertTrue(content["source"]["offline_allowed"])
        self.assertEqual(
            self.get("meaning", fallback, language="ja").json()["status"], "language_unavailable"
        )
        upstream.assert_called_once()

    @patch("core.providers.get_json")
    def test_context_link_has_no_text_and_ignores_unrelated_wikipedia_page(self, upstream):
        upstream.side_effect = [
            [],
            {
                "query": {
                    "pages": [
                        {"title": "Usseewa", "pageid": 42, "extract": "Usseewa is a song by Ado."},
                        {"title": "Unrelated", "pageid": 43, "extract": "A song by Ado."},
                    ]
                }
            },
        ]
        fallback = self.resolve().json()["metadata_match"]
        content = self.get("meaning", fallback, language="en").json()
        self.assertEqual(content["status"], "link_only")
        self.assertIsNone(content["text"])
        self.assertFalse(content["source"]["offline_allowed"])
        self.assertEqual(content["source"]["url"], "https://en.wikipedia.org/?curid=42")

    @patch("core.providers.get_json")
    def test_distinguishes_missing_lyrics_from_provider_unavailability(self, upstream):
        upstream.side_effect = [[row(4)], None, ProviderError()]
        match = self.resolve().json()["match"]
        self.assertEqual(self.get("lyrics", match).json()["status"], "not_found")
        response = self.get("lyrics", match)
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["status"], "unavailable")

    @patch("core.providers.get_json")
    def test_rejects_invalid_input_and_unsigned_references_without_network(self, upstream):
        self.assertEqual(self.resolve({"title": "", "artist": "Ado"}).status_code, 400)
        self.assertEqual(self.get("lyrics", {"id": "123"}).status_code, 404)
        upstream.assert_not_called()

    def test_limits_track_requests_but_leaves_health_available(self):
        for _ in range(20):
            self.assertEqual(self.resolve({}).status_code, 400)
        self.assertEqual(self.resolve({}).status_code, 429)
        self.assertEqual(self.client.get(reverse("health")).status_code, 200)

    @patch("core.providers.get_json")
    def test_video_upload_title_resolves_to_numeric_song_and_its_meaning(self, upstream):
        upstream.return_value = [
            {
                "id": 8,
                "trackName": "505",
                "artistName": "Arctic Monkeys",
                "albumName": "Favourite Worst Nightmare",
                "duration": 254,
            },
            {"id": 9, "trackName": "505", "artistName": "Outro", "duration": 254},
        ]
        resolved = self.resolve(
            {
                "title": "505 - Arctic Monkeys (Tradução/Letra)",
                "artist": "Ghot_Stich",
                "album": "Ghot_Stich",
                "duration_ms": 254000,
            }
        ).json()
        self.assertEqual(resolved["status"], "matched")
        self.assertEqual(resolved["match"]["track"]["artist"], "Arctic Monkeys")
        self.assertEqual(
            upstream.call_args.args[1], {"track_name": "505", "artist_name": "Arctic Monkeys"}
        )
        self.assertEqual(
            self.get("meaning", resolved["metadata_match"]).json()["kind"], "artist_commentary"
        )

    @patch("core.providers.get_json")
    def test_asterisk_matches_japanese_title_and_requires_choice_for_other_duration(self, upstream):
        candidate = {
            "id": 8,
            "trackName": "＊～アスタリスク～",
            "artistName": "ORANGE RANGE",
            "albumName": "BLEACH THE BEST",
            "duration": 257,
        }
        upstream.side_effect = [[candidate], {**candidate, "plainLyrics": "Letra de teste"}]
        resolved = self.resolve(
            {
                "title": "*Asterisk",
                "artist": "ORANGE RANGE - Topic",
                "duration_ms": 238000,
            }
        ).json()
        self.assertEqual(resolved["status"], "ambiguous")
        self.assertIsNone(resolved["match"])
        self.assertEqual(self.get("lyrics", resolved["candidates"][0]).json()["status"], "found")
        self.assertEqual(
            self.get("meaning", resolved["metadata_match"]).json()["kind"], "editorial_context"
        )

    @patch("core.providers.get_json")
    def test_artist_channel_matches_embedded_artist_without_spaces(self, upstream):
        upstream.return_value = [
            {
                "id": 8,
                "trackName": "Money for Nothing",
                "artistName": "Dire Straits",
                "albumName": "Brothers in Arms",
                "duration": 248,
            }
        ]
        resolved = self.resolve(
            {
                "title": "Dire Straits - Money for Nothing (Official Music Video)",
                "artist": "DireStraitsVEVO",
            }
        ).json()
        self.assertEqual(resolved["status"], "matched")
        self.assertEqual(resolved["match"]["track"]["artist"], "Dire Straits")
