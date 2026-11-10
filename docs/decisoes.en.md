# Initial decisions

[Leia em português](decisoes.md)

This document records the initial scope and configuration.

## Product

MusicAPP was the working name. The development package ID was `com.musicapp.music_app`. The Android preview used the default Flutter icon, with final branding planned for the release APK.

The first physical target was the POCO X5 Pro running Android 14 and HyperOS 2.0.17.0. The initial minimum was Android 7.0, API 24. The available emulator used API 37.

The MVP covered playback of local files without accounts or ads. Streaming and audio downloads were outside its scope. Lyrics and meanings were planned to support manual download, versioned UTF-8 JSON and offline reading. The initial proposal was a 20 MiB limit with manual cleanup.

Development used a local Django server. The hosting decision was deferred to deployment.

## Interface

The palette used black `#05080F`, navy `#0A1730`, surfaces `#101D31`, primary text `#F2F5FC`, secondary text `#A4B1C6` and a blue accent `#8FBEFF`.

The design references guided the tabbed library, mini player, playlist details and bottom queue sheet. The player added a Meaning tab beside Music and Lyrics. The preview generated artwork in Flutter for use offline.

Version 0.2.0 replaced sample data with real files indexed on the device, audio playback and local persistence. The Lyrics and Meaning tabs indicated that the features were pending.

## Technical structure

| Path | Purpose |
| --- | --- |
| `mobile/lib/core` | Theme and HTTP health client |
| `mobile/lib/library` | Models, media queries, SQLite and library state |
| `mobile/lib/playback` | Playback engine and Android media session |
| `mobile/lib/features` | Library, details, player, texts and settings |
| `mobile/lib/widgets` | Reusable UI components |
| `backend/config` | Settings, routes and WSGI and ASGI entry points |
| `backend/core` | Health endpoint and tests |

Flutter used Material 3, Brazilian Portuguese localization and `ChangeNotifier` for UI state. Playback used just_audio, audio_service and audio_session. Persistence used sqflite. The app queried the Android catalog over a native channel. Resolved versions are in `pubspec.lock`.

Django used REST Framework and SQLite for development. The health endpoint accepted no authentication or personal data. Content routes and abuse protection were planned for a later stage. Django required a secret key whenever `DJANGO_DEBUG` was disabled.

## Initial API contract

`GET /api/v1/health/` returned HTTP 200.

```json
{"status":"ok","service":"musicapp","api_version":"v1"}
```

The response bypassed the cache and required neither external providers nor a database. It checked the availability of the HTTP process. Other methods returned 405. Content routes were still pending and returned 404.

## Technical references

- [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup).
- [Django 5.2 Python compatibility](https://docs.djangoproject.com/en/5.2/releases/5.2/).
