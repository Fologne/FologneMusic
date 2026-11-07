from hashlib import sha256

from django.core import signing
from django.utils import timezone
from rest_framework import serializers

from core.providers import (
    LRCLIB,
    ProviderError,
    lrclib_candidates,
    lrclib_lyrics,
    wikipedia_context_link,
)
from core.track_metadata import artist_key, normalize, search_metadata, title_key

TRACK_SALT = "musicapp.track.v1"
ADO_COMMENTARY = (
    "Ado descreve a faixa como uma expressão de raiva. Para ela, a combinação "
    "do tema com uma interpretação vocal áspera era incomum na época.",
    {
        "name": "The Guardian",
        "title": "Entrevista com Ado",
        "url": (
            "https://www.theguardian.com/music/2024/mar/11/"
            "ado-platinum-selling-pop-star-secret-identity-troxy-london"
        ),
    },
)
ARTIST_COMMENTARY = {
    ("ado", "usseewa"): ADO_COMMENTARY,
    ("ado", "うっせぇわ"): ADO_COMMENTARY,
    ("sabaton", "the red baron"): (
        "A banda se inspirou em Manfred von Richthofen, piloto alemão da Primeira Guerra "
        "Mundial. O apelido Barão Vermelho veio da cor de seu avião. A faixa evoca "
        "a velocidade dos combates aéreos e a fama que o piloto conquistou.",
        {
            "name": "Sabaton",
            "title": "The Great War — comentário sobre The Red Baron",
            "url": "https://www.sabaton.net/discography/the-great-war/",
        },
    ),
    ("arcticmonkeys", "505"): (
        "Alex Turner descreveu 505 como uma canção de amor sobre a pressa de reencontrar "
        "alguém num quarto de hotel em Nova York. A viagem dá forma à expectativa "
        "desse reencontro.",
        {
            "name": "NME",
            "title": "Entrevista com Arctic Monkeys de 2007",
            "url": (
                "https://www.nme.com/blogs/nme-blogs/"
                "arctic-monkeys-nme-interview-2007-favourite-worst-nightmare-2307701"
            ),
        },
    ),
}
EDITORIAL_CONTEXT = {
    ("orangerange", "asterisk"): (
        "A letra usa a luz das estrelas como imagem do que atravessa o tempo e ainda "
        "alcança outras pessoas. Uma leitura é que sentimentos e gestos podem inspirar "
        "alguém muito depois de acontecerem. O asterisco do título lembra uma pequena "
        "estrela, e a faixa foi a primeira abertura de Bleach.",
        {
            "name": "Real Sound",
            "title": "Conversa sobre Asterisk com NAOTO e JABBA DA FOOTBALL CLUB",
            "url": "https://realsound.jp/2021/02/post-707602.html",
        },
    ),
}


class TrackInput(serializers.Serializer):
    title = serializers.CharField(max_length=240)
    artist = serializers.CharField(max_length=240)
    album = serializers.CharField(max_length=240, allow_blank=True, default="")
    duration_ms = serializers.IntegerField(
        min_value=1, max_value=86400000, allow_null=True, default=None
    )


class LanguageInput(serializers.Serializer):
    language = serializers.RegexField(
        regex=r"^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8}){0,2}\Z", max_length=24, default="pt-BR"
    )


def track_reference(track, provider_id=None):
    identity = (
        f"lrclib:{provider_id}"
        if provider_id
        else repr(
            (
                normalize(track["title"]),
                normalize(track["artist"]),
                normalize(track["album"]),
                track["duration_ms"],
            )
        )
    )
    return {
        "id": signing.dumps(
            {"track": track, "provider_id": provider_id}, salt=TRACK_SALT, compress=True
        ),
        "track_key": sha256(identity.encode()).hexdigest(),
        "track": track,
    }


def resolve_track(track):
    preferred, searches = search_metadata(track)
    identities = []
    failure = None
    for search in searches:
        try:
            rows = lrclib_candidates(search)
        except ProviderError as exc:
            failure = exc.status
            if failure == "provider_rate_limited":
                break
            continue
        if rows:
            identities.append((search, rows))
            if search is preferred:
                break
    fallback = track_reference(preferred)
    if not identities:
        return {
            "status": failure or "not_found",
            "match": None,
            "candidates": [],
            "metadata_match": fallback,
        }
    if len(identities) > 1:
        return {
            "status": "identity_ambiguous",
            "match": None,
            "candidates": [
                track_reference({key: row[key] for key in track}, row["provider_id"])
                for _, rows in identities
                for row in rows[:5]
            ],
            "metadata_match": fallback,
        }
    track, rows = identities[0]
    fallback = track_reference(track)
    ranked = []
    for row in rows:
        duration, found_duration = track["duration_ms"], row["duration_ms"]
        distance = abs(duration - found_duration) if duration and found_duration else None
        close = distance is not None and distance <= 4000
        album_agrees = bool(track["album"]) and normalize(row["album"]) == normalize(track["album"])
        rank = 2 * album_agrees + close
        ranked.append((rank, distance, row))
    if any(distance is not None and distance <= 4000 for _, distance, _ in ranked):
        ranked = [
            (rank, distance, row)
            for rank, distance, row in ranked
            if distance is not None and distance <= 4000
        ]
    ranked.sort(
        key=lambda item: (
            -item[0],
            item[1] if item[1] is not None else float("inf"),
            item[2]["provider_id"],
        )
    )
    candidates = [
        track_reference({key: row[key] for key in track}, row["provider_id"])
        for _, _, row in ranked[:10]
    ]
    best_rank, distance, best = ranked[0]
    confirmed = (
        (len(ranked) == 1 or best_rank > ranked[1][0])
        and (not track["album"] or normalize(track["album"]) == normalize(best["album"]))
        and (not track["duration_ms"] or (distance is not None and distance <= 4000))
    )
    return {
        "status": "matched" if confirmed else "ambiguous",
        "match": candidates[0] if confirmed else None,
        "candidates": [] if confirmed else candidates,
        "metadata_match": fallback,
    }


def result(status, *, source=None, language=None, text=None, **extra):
    return {
        "schema_version": 1,
        "status": status,
        "language": language,
        "text": text,
        "source": source,
        "fetched_at": timezone.now().isoformat(),
        **extra,
    }


def lyrics(reference, _language):
    provider_id = reference["provider_id"]
    if provider_id is None:
        return result("not_resolved")
    row = lrclib_lyrics(provider_id)
    if row is None:
        return result("not_found")
    title, artist = row.get("trackName"), row.get("artistName")
    track = reference["track"]
    if (
        not isinstance(title, str)
        or not isinstance(artist, str)
        or artist_key(artist) != artist_key(track["artist"])
        or title_key(title, artist) != title_key(track["title"], track["artist"])
    ):
        raise ProviderError()
    source = {"name": "LRCLIB", "url": f"{LRCLIB}/get/{provider_id}", "offline_allowed": False}
    if row.get("instrumental") is True:
        return result("instrumental", source=source)
    plain, synced = row.get("plainLyrics"), row.get("syncedLyrics")
    plain = plain if isinstance(plain, str) and plain.strip() else None
    synced = synced if isinstance(synced, str) and synced.strip() else None
    if not (plain or synced):
        return result("not_found", source=source)
    # LRCLIB does not supply a reliable language tag. Return the original only.
    return result("found", text=plain, source=source, synced_lrc=synced)


def meaning(reference, language):
    language = language.lower().split("-")[0]
    if language not in ("pt", "en"):
        return result("language_unavailable")
    track = reference["track"]
    key = (artist_key(track["artist"]), title_key(track["title"], track["artist"]))
    entry = ARTIST_COMMENTARY.get(key)
    kind = "artist_commentary"
    if entry is None:
        entry = EDITORIAL_CONTEXT.get(key)
        kind = "editorial_context"
    if language == "pt" and entry is not None:
        text, source = entry
        return result(
            "found",
            language="pt-BR",
            kind=kind,
            text=text,
            source={**source, "offline_allowed": True},
        )
    source = wikipedia_context_link(track, language)
    if source is None and language == "pt":
        language = "en"
        source = wikipedia_context_link(track, language)
    if source is None:
        return result("not_found")
    return result(
        "link_only",
        language=language,
        kind="encyclopedic_context",
        source={**source, "offline_allowed": False},
    )
