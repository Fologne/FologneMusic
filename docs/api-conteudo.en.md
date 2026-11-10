# Lyrics and meaning API

[Leia em português](api-conteudo.md)

Django accepts a title, an artist and, when available, an album and duration. The endpoints use JSON. Local playback works independently of the API.

## Resolve a track

`POST /api/v1/tracks/resolve/`

```json
{"title":"Usseewa","artist":"Ado","album":"Kyōgen","duration_ms":202000}
```

`title` and `artist` are required. Send the duration in milliseconds when known. The API compares the title and artist, then uses the album and duration to distinguish recordings.

| Field | Use |
| --- | --- |
| `status` | `matched`, `ambiguous` (multiple recordings or uncertain duration), `identity_ambiguous` (different title and artist pairs), `not_found`, `unavailable` or `provider_rate_limited` |
| `match` | Confirmed recording or `null` |
| `candidates` | Up to 10 recordings to choose from when the match is ambiguous |
| `metadata_match` | Reference for looking up the meaning from the submitted metadata, even without a confirmed recording |

Each reference contains `id`, `track_key` and `track`. Pass `id` to the content endpoints. It is a signed token that expires after 24 hours and can be read by anyone who has it. Use `track_key` as the stable key for content the source permits you to save offline.

Track resolution strips known video labels, normalizes channel names and tests title and artist pairs when both appear in the filename. Duration mismatches and ambiguous identities require manual selection.

## Look up content

- `GET /api/v1/tracks/{id}/lyrics/` looks up the confirmed or selected recording.
- `GET /api/v1/tracks/{id}/meaning/?language=pt-BR` returns sourced editorial commentary or a link for context. Link search supports Portuguese and English.

The body includes `schema_version`, `status`, `language`, `text`, `source` and `fetched_at`. Original lyrics may include `synced_lrc`. LRCLIB does not reliably identify the language, so `language` is null. The meaning API also returns `kind` when it finds commentary or context.

```json
{
  "schema_version": 1,
  "status": "link_only",
  "language": "en",
  "text": null,
  "source": {
    "name": "Wikipédia",
    "title": "Título do artigo",
    "url": "https://en.wikipedia.org/?curid=42",
    "offline_allowed": false
  },
  "fetched_at": "2026-11-06T12:00:00+00:00",
  "kind": "encyclopedic_context"
}
```

| HTTP | Meaning |
| --- | --- |
| 200 | Resource state such as `found`, `not_found`, `not_resolved`, `instrumental`, `link_only` or `language_unavailable`. During resolution, LRCLIB failures also return 200 with a reference for looking up the meaning. |
| 400 | Invalid input. |
| 404 | Unknown or invalid token. |
| 410 | Expired token. Resolve the track again. |
| 429 | Local request limit reached. |
| 503 | Provider unavailable or rate-limited. See `status` for the reason. |

Use `source.offline_allowed` to decide whether to offer an offline copy and retain the source information in the saved file. A `link_only` response should offer a way to open the link.

## Running the API

Set `MUSICAPP_USER_AGENT` to the app name and a real contact for production. The API uses fixed upstream hosts, a four-second socket timeout and a response limit of 512 KiB. The in-memory cache holds metadata and links for five minutes and empty search results for one minute. Lyrics are excluded from the cache. The local limit is 20 calls to track endpoints per minute per IP address per Django process.

For a public installation with multiple processes, enforce a shared rate limit at the proxy or infrastructure level. Configure the log policy for track tokens, which contain the title, artist and other metadata.
