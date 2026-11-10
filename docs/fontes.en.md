# Content source evaluation

[Leia em português](fontes.md)

Updated November 6, 2026. Django queries real sources. Integration into the Android player tabs and offline downloads was planned for stage 7.

## Lyrics

LRCLIB was the initial candidate. Its documentation describes how to search and retrieve plain and synchronized lyrics, identify the client and handle request limits. Configure a real project URL or contact before deploying an integration. [LRCLIB documentation](https://lrclib.net/docs).

The read-only script `backend/scripts/probe_sources.py` prints counts and IDs and saves no lyrics. A search may return several recordings. Matching a file on the phone requires selecting the correct recording.

| Artist | Track | Candidates returned | With plain lyrics | With synchronized lyrics |
| --- | --- | --- | --- | --- |
| Ado | うっせぇわ | 20 | 20 | 20 |
| Sabaton | The Red Baron | 20 | 20 | 19 |
| Кино | Кукушка | 20 | 20 | 20 |
| Legião Urbana | Tempo Perdido | 20 | 20 | 20 |

Results vary over time, and the search limit caps the returned sample. Compare the artist, title, album and duration and offer manual selection for ambiguous matches.

The backend returns the original lyrics, the source and LRC when available. The documentation review did not confirm general permission to store lyrics offline, so the API marks LRCLIB lyrics `offline_allowed: false`. The server caches only the search metadata.

The November 6 test used these four tracks against the real LRCLIB service. The Django API found candidates and returned lyrics after a candidate was selected in each case. The test used manually entered metadata.

## Song meanings

Genius remains a candidate. Its official documentation returned HTTP 403 in this environment, leaving the API contract, credentials, pricing, sample coverage and offline permissions unverified. No Genius integration was implemented. [Genius API documentation](https://docs.genius.com/).

The initial catalog includes original Portuguese texts that can be saved offline with their references. The `kind` field distinguishes commentary attributed to the artist from editorial interpretation. The Asterisk matcher also accepts the Japanese spelling in the official Aniplex catalog. [Usseewa](https://www.theguardian.com/music/2024/mar/11/ado-platinum-selling-pop-star-secret-identity-troxy-london), [The Red Baron](https://www.sabaton.net/discography/the-great-war/), [505](https://www.nme.com/blogs/nme-blogs/arctic-monkeys-nme-interview-2007-favourite-worst-nightmare-2307701), [Asterisk](https://realsound.jp/2021/02/post-707602.html), [Aniplex catalog](https://www.aniplex.co.jp/lineup/bleach/products/detail/?id=980).

For other songs, the MediaWiki API can find a Portuguese or English article. The backend filters by title and artist and returns a context link when it identifies a single plausible article. A live test found Usseewa in English and Tempo Perdido in Portuguese. The Portuguese edition returned no match for Кукушка. The app labels these links as encyclopedic context. [MediaWiki TextExtracts API](https://www.mediawiki.org/wiki/Extension:TextExtracts), [Wikimedia terms of use](https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use).

## Integration tasks

- Obtain a source or permission that allows offline lyric storage.
- Expand the meaning catalog with verifiable texts and permission to copy them.
- Repeat the sample with real file metadata from the device.
- Integrate recording selection and offline storage of authorized texts in Flutter.

The two tabs remain independent. Keep the source, language and date when handling API results. [Content API contract](api-conteudo.en.md).
