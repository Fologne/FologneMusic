# FologneMusic delivery guide

[Leia em português](entrega.md)

## Version 2.1.0

The signed `FologneMusic-2.1.0.apk` updates the playback queue, adds Portuguese and English interface options, and opens shared downloads in a dialog. It uses the existing Android package ID and signing key.

| Item | Value |
| --- | --- |
| Version code | 20 |
| APK size | 128,623,205 bytes |
| APK SHA-256 | `7bdc393dd0c3fd30d9f1307e5680990d78314015f158458f817ec7e22c857c6b` |
| Certificate SHA-256 | `f2921d73b8caa843456b9fb36efae838e27723135d7e556a1f57f66eaf7a9a21` |
| Android versions | Android 7.0 for playback and Android 10 for audio downloads |
| ABIs | `arm64-v8a` and `x86_64` |

Use `FologneMusic-2.1.0.apk` for the `v2.1.0` release. The bundled download components remain the same as in 2.0.0. See [Licenses and source code](#licenses-and-source-code) for the recorded source and notice review.

## Version 2.0.0

The `FologneMusic-2.0.0.apk` uses package ID `com.musicapp.music_app`, the 1.0.0 signing key and version code 16. The queue shows the shuffled order and restores it when the app reopens. The **Downloads** tab uses the same queue for shared and pasted links. Its history is separate from the library's SQLite database. Clearing history leaves the MP3 files in `Music/FologneMusic`.

Audio downloads require Android 10 or later on ARM64 or x86-64. A test of the signed rc.3 on the emulator downloaded an authorized video's audio, converted it to MP3 and opened the track in the player. [Build configuration for downloads](desenvolvimento.en.md#audio-download-prototype).

### File and verification

| Item | Value |
| --- | --- |
| APK | `FologneMusic-2.0.0.apk` |
| Size | 128,478,945 bytes |
| APK SHA-256 | `5b6af1c691826f912094249a65f21eb1a203b0771169d3801a808614e13a6628` |
| Certificate SHA-256 | `f2921d73b8caa843456b9fb36efae838e27723135d7e556a1f57f66eaf7a9a21` |
| App source used for the build | Base commit `f90d0acd4b158e19e04464810ac8e0fc10ca4a4c` plus the queue fix included in the source archive |
| Android versions | Android 7.0 for playback and Android 10 for downloads and conversion |
| ABIs | `arm64-v8a` and `x86_64` |

### Licenses and source code

The original FologneMusic code is distributed under `GPL-3.0-only`. [License text](../LICENSE).

The APK's native binaries match the contents of the 0.18.1 AARs byte for byte for both architectures. Gradle pins the SHA-256 of the main yt-dlp zipapp. The library also bundles its own copy of yt-dlp as a resource.

| Component | Identified license and source |
| --- | --- |
| youtubedl-android 0.18.1 | Maven Central declares GPL-3.0. The tag points to `d725d5c9a18c3a99a13ee0308bf78275dc310760`. Source archives are available for [library](https://repo.maven.apache.org/maven2/io/github/junkfood02/youtubedl-android/library/0.18.1/library-0.18.1-sources.jar), [common](https://repo.maven.apache.org/maven2/io/github/junkfood02/youtubedl-android/common/0.18.1/common-0.18.1-sources.jar) and [ffmpeg](https://repo.maven.apache.org/maven2/io/github/junkfood02/youtubedl-android/ffmpeg/0.18.1/ffmpeg-0.18.1-sources.jar). [Library tag](https://github.com/yausername/youtubedl-android/tree/0.18.1) |
| FFmpeg and FFprobe 7.1.1 | The binaries use `--enable-gpl` and `--enable-version3`. The package also includes the libraries they load. [Binary update](https://github.com/yausername/youtubedl-android/commit/f2280ae7d8bc8d59590c8727a89f047983867c10), [Base source 7.1.1](https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz), [Library build instructions](https://github.com/yausername/youtubedl-android/blob/0.18.1/BUILD_FFMPEG.md) |
| CPython 3.12.11 and QuickJS 2025-04-26 | The CPython base source includes the PSF license. QuickJS uses MIT. The Python package also includes mutagen 1.47.0 (GPL-2.0-or-later), pycryptodomex 3.23.0 and native libraries including GNU Readline. [CPython](https://www.python.org/downloads/release/python-31211/), [QuickJS](https://bellard.org/quickjs/), [Library build instructions](https://github.com/yausername/youtubedl-android/blob/0.18.1/BUILD_PYTHON.md) |
| yt-dlp and yt-dlp-ejs | The app uses zipapp 2026.10.26 with EJS 0.8.0. The library resource bundles yt-dlp 2025.11.12 with EJS 0.3.1. yt-dlp uses the Unlicense, and the zipapps include ISC and MIT code. [App zipapp notices](https://github.com/yt-dlp/yt-dlp/blob/2026.10.26/THIRD_PARTY_LICENSES.txt), [Bundled zipapp notices](https://github.com/yt-dlp/yt-dlp/blob/2025.11.12/THIRD_PARTY_LICENSES.txt) |

The Termux recipes at `8ddd9a7fc8e06330545487d81bb7591cb40f1aa6` provide a reference for FFmpeg 7.1.1 and its dependencies. The library guides describe the general build process. The exact revisions, patches and build steps for the Android 0.18.1 binaries of FFmpeg, Python, QuickJS and bundled libraries still need verification for ARM64 and x86-64. [Termux recipes](https://github.com/termux/termux-packages/tree/8ddd9a7fc8e06330545487d81bb7591cb40f1aa6/packages), [Sieve's review of the same package](https://github.com/Massivemiike/sieve-android/blob/e8467a8691dcdaf8aa5b26056ca5b2f3e7a10e76/licenses/FFMPEG_SOURCE.txt#L93).

The `FologneMusic-2.0.0-fontes-e-avisos.zip` archive includes the collected sources, notices found in the sources and APK, binary hashes and reference recipes. `FONTES.json` lists the collected sources and pending URLs. Before publishing an APK with Downloads, confirm the corresponding source for the remaining binaries and complete the applicable notices. Provide equivalent online access to the source and APK, and identify the source in the release notes. [GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#SourceAndBinaryOnDifferentSites), [FFmpeg licensing](https://ffmpeg.org/legal.html).

### GitHub release draft

1. Include the documentation in the commit and push it to `master`.
2. Open [FologneMusic Releases](https://github.com/Fologne/FologneMusic/releases) and select **Draft a new release**.
3. Use tag `v2.0.0`, title `FologneMusic 2.0.0` and the updated `master` branch. Paste the [release notes](release-2.0.0.en.md).
4. Attach `FologneMusic-2.0.0.apk` and `FologneMusic-2.0.0-fontes-e-avisos.zip` under **Assets**. Both files are in `D:/FologneMusicBuild/release/v2.0.0/` on the build machine.
5. Select **Save draft**. Publish after verifying the outstanding sources and notices. [GitHub release instructions](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#creating-a-release).

## Install and use on Android

Open the signed APK with the Android installer and grant audio access on first launch. The app reads the library when you open it or return to it. To refresh, pull down from the top of the library or use the refresh button. Newly copied files appear after Android indexes them.

In the player, tap **Search for Lyrics** or **Search for Meaning**. Direct search uses the phone's internet connection by default. Lyrics come from LRCLIB. The app can show sourced catalog texts and a Wikipedia link when it finds a matching article. **Save offline** is available when the source allows it. Local music and saved texts work in airplane mode. [LRCLIB](https://lrclib.net/docs).

The release APK uses a dedicated key. Android preserves app data when an update uses the same package ID and signature. A debug installation with a different signature must be removed before installing the release APK. Back up anything you need from a debug installation before removing it. [Android update rules](https://developer.android.com/google/play/app-updates).

## Build a signed version

Use the same release key for future updates. On the build machine, the PKCS#12 key is stored under `%LOCALAPPDATA%\FologneMusic\signing`. Windows protects the local password for the current user. Keep a separate, recoverable backup of the key and password.

Set `FOLOGNE_KEYSTORE` to the key path and `FOLOGNE_KEYSTORE_PASSWORD` in the build environment. The alias is `folognemusic`. Run these commands from `mobile`.

```powershell
$env:FOLOGNE_EXPERIMENTAL_DOWNLOADS = 'true'
$env:FOLOGNE_YTDLP_ZIPAPP = 'C:/path/to/yt-dlp'
flutter build apk --release --target-platform android-arm64,android-x64
```

Version 2.0.0 used Flutter 3.47.8. Use the `yt-dlp` file from release 2026.10.26. The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Check the certificate with the Android SDK's `apksigner verify --print-certs` and calculate SHA-256 with `Get-FileHash -Algorithm SHA256`. [yt-dlp 2026.10.26](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.26).

Direct mode requires no server URL. To use an existing HTTPS Django server, enter its address under **Menu → Settings → Text search → Use Django server**. Set `--dart-define=API_BASE_URL=https://your-domain` at build time to use it from first launch.

## Optional Django server with Docker

For local development, run these commands from the repository root.

```powershell
docker compose up -d --build --wait
docker compose exec django python manage.py migrate --noinput
docker compose logs -f django
docker compose down
```

The development service listens on `127.0.0.1:8000` by default. Set `FOLOGNE_PORT` to change the port. To test a debug APK over USB, use `adb reverse tcp:8000 tcp:8000` and enter `http://127.0.0.1:8000` in Settings.

`compose.production.yaml` runs Gunicorn without root privileges and publishes the port on loopback only. For an optional deployment, set `FOLOGNE_DJANGO_SECRET_FILE` to a key file outside the project, configure `DJANGO_ALLOWED_HOSTS` and put an HTTPS proxy in front of the service. Enable `DJANGO_REQUIRE_HTTPS=true` and `DJANGO_TRUST_PROXY=true` when the proxy replaces the `X-Forwarded-Proto` header. Run `docker compose -f compose.production.yaml up -d --build --wait` and run migrations with the same Compose file. Configure public access and rate limits at the proxy. HSTS for subdomains and preload depend on the domain you control.

The `django-data` volume stores SQLite and persists after `down`. To back up the database, stop the service and copy `/data/db.sqlite3` from the container to a private location. To restore it, stop the service, replace the file in the volume, preserve ownership by user 10001, then run migrations before starting the service. Android playlists and downloads are stored on the device.
