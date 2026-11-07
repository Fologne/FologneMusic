import json
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

SAMPLES = [
    ("Ado", "うっせぇわ"),
    ("Sabaton", "The Red Baron"),
    ("Кино", "Кукушка"),
    ("Legião Urbana", "Tempo Perdido"),
]


def probe():
    results = []
    for artist, title in SAMPLES:
        url = "https://lrclib.net/api/search?" + urlencode(
            {"artist_name": artist, "track_name": title}
        )
        request = Request(url, headers={"User-Agent": "MusicAPP/0.1.0 (local development probe)"})
        try:
            with urlopen(request, timeout=15) as response:
                records = json.load(response)
            if not isinstance(records, list):
                raise ValueError("Unexpected response")
            results.append(
                {
                    "artist": artist,
                    "title": title,
                    "candidates": len(records),
                    "with_plain_lyrics": sum(bool(row.get("plainLyrics")) for row in records),
                    "with_synced_lyrics": sum(bool(row.get("syncedLyrics")) for row in records),
                    "candidate_ids": [row["id"] for row in records[:3]],
                }
            )
        except (HTTPError, URLError, ValueError, TimeoutError) as error:
            results.append({"artist": artist, "title": title, "error": str(error)})
    return results


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(probe(), ensure_ascii=False, indent=2))
