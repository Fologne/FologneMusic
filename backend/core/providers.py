import json
import re
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from hashlib import sha256
from http.client import HTTPException
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from django.conf import settings
from django.core.cache import cache

from core.track_metadata import artist_key, normalize, title_key

LRCLIB = "https://lrclib.net/api"
WIKIPEDIA = {"pt": "https://pt.wikipedia.org", "en": "https://en.wikipedia.org"}


class ProviderError(Exception):
    def __init__(self, status="unavailable"):
        self.status = status
        super().__init__(status)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def get_json(url, params=None, *, allow_missing=False):
    cooldown = f"musicapp:provider-cooldown:{urlsplit(url).netloc}"
    if cache.get(cooldown):
        raise ProviderError("provider_rate_limited")
    if params:
        url = f"{url}?{urlencode(params)}"
    request = Request(
        url,
        headers={"User-Agent": settings.MUSICAPP_USER_AGENT, "Accept": "application/json"},
    )
    try:
        with build_opener(NoRedirect()).open(request, timeout=4) as response:
            data = response.read(512 * 1024 + 1)
        if len(data) > 512 * 1024:
            raise ProviderError()
        return json.loads(data)
    except HTTPError as exc:
        if allow_missing and exc.code == 404:
            return None
        if exc.code in (429, 503):
            retry = exc.headers.get("Retry-After") if exc.headers else None
            delay = 30
            if retry:
                try:
                    delay = int(retry)
                except ValueError:
                    try:
                        delay = int(
                            (parsedate_to_datetime(retry) - datetime.now(UTC)).total_seconds()
                        )
                    except TypeError, ValueError, OverflowError:
                        pass
            cache.set(cooldown, True, timeout=max(1, min(delay, 86400)) + 1)
        raise ProviderError("provider_rate_limited" if exc.code == 429 else "unavailable") from exc
    except (URLError, OSError, HTTPException, ValueError) as exc:
        raise ProviderError() from exc


def cached_metadata(namespace, query, fetch):
    key = f"musicapp:{namespace}:{sha256(json.dumps(query, sort_keys=True).encode()).hexdigest()}"
    cached = cache.get(key)
    if cached is not None:
        return cached["value"]
    value = fetch()
    cache.set(key, {"value": value}, timeout=300 if value else 60)
    return value


def lrclib_candidates(track):
    title = track["title"].strip(" *~〜♪♫") or track["title"]
    query = {"track_name": title, "artist_name": track["artist"]}

    def fetch():
        data = get_json(f"{LRCLIB}/search", query)
        if not isinstance(data, list):
            raise ProviderError()
        candidates = {}
        for row in data[:100]:
            if not isinstance(row, dict):
                continue
            title, artist, album = (
                row.get(key) for key in ("trackName", "artistName", "albumName")
            )
            provider_id = row.get("id")
            if (
                type(provider_id) is not int
                or provider_id <= 0
                or not isinstance(title, str)
                or not isinstance(artist, str)
                or title_key(title, artist) != title_key(track["title"], track["artist"])
                or artist_key(artist) != artist_key(track["artist"])
            ):
                continue
            duration = row.get("duration")
            candidates[provider_id] = {
                "provider_id": provider_id,
                "title": title,
                "artist": artist,
                "album": album[:240] if isinstance(album, str) else "",
                "duration_ms": (
                    round(duration * 1000)
                    if type(duration) in (int, float) and 0 < duration <= 86400
                    else None
                ),
            }
        return list(candidates.values())

    rows = cached_metadata("lrclib-search-v2", query, fetch)
    if (
        not rows
        and artist_key(track["artist"]) == "orangerange"
        and title_key(track["title"], track["artist"]) == "asterisk"
        and title != "アスタリスク"
    ):
        return lrclib_candidates({**track, "title": "アスタリスク"})
    return rows


def lrclib_lyrics(provider_id):
    data = get_json(f"{LRCLIB}/get/{provider_id}", allow_missing=True)
    if data is not None and (
        not isinstance(data, dict) or type(data.get("id")) is not int or data["id"] != provider_id
    ):
        raise ProviderError()
    return data


def wikipedia_context_link(track, language):
    domain = WIKIPEDIA[language]
    if "|" in track["title"]:
        return None
    suffix = "song" if language == "en" else "canção"
    titles = [track["title"], f"{track['title']} ({suffix})"]
    expected_titles = {normalize(title) for title in titles}
    query = {"title": track["title"], "artist": track["artist"], "language": language}

    def fetch():
        data = get_json(
            f"{domain}/w/api.php",
            {
                "action": "query",
                "format": "json",
                "formatversion": 2,
                "redirects": 1,
                "titles": "|".join(titles),
                "prop": "extracts|pageprops",
                "ppprop": "disambiguation",
                "exintro": 1,
                "explaintext": 1,
            },
        )
        response_query = data.get("query") if isinstance(data, dict) else None
        pages = response_query.get("pages") if isinstance(response_query, dict) else None
        if not isinstance(pages, list):
            raise ProviderError()
        matches = []
        for page in pages:
            if not isinstance(page, dict):
                continue
            pageprops = page.get("pageprops", {})
            if not isinstance(pageprops, dict) or "disambiguation" in pageprops:
                continue
            extract, page_id, title = (page.get(key) for key in ("extract", "pageid", "title"))
            if (
                not isinstance(extract, str)
                or type(page_id) is not int
                or page_id <= 0
                or not isinstance(title, str)
                or normalize(title) not in expected_titles
            ):
                continue
            intro = normalize(extract[:600])
            artist = re.escape(normalize(track["artist"]))
            if re.search(rf"\b{artist}\b", intro) and re.search(
                r"\b(song|single|canção|música)\b", intro
            ):
                matches.append(
                    {"name": "Wikipédia", "title": title, "url": f"{domain}/?curid={page_id}"}
                )
        return matches[0] if len(matches) == 1 else None

    return cached_metadata("wikipedia-link-v1", query, fetch)
