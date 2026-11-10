# Development

[Leia em português](desenvolvimento.md)

## Environment

The project used Flutter 3.47.8, Dart 3.13.7, Python 3.14.7 and Django 5.2.19. Flutter detected the installed Android SDK and the Java runtime from Android Studio. Chrome is optional for the Android target.

Run the PowerShell commands from the repository root unless a section specifies a different directory. GitHub access is optional for local development and testing.

## Backend

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -r backend/requirements-dev.txt
$env:DJANGO_DEBUG = 'true'
backend/.venv/Scripts/python.exe backend/manage.py migrate
backend/.venv/Scripts/python.exe backend/manage.py runserver 127.0.0.1:8000
```

`backend/.env.example` documents the variables. Set them in the terminal with `$env:NAME = 'value'` before starting Django. Production requires `DJANGO_SECRET_KEY` and disables `DJANGO_DEBUG`.

## Flutter on the emulator

In a separate terminal, run the following commands.

```powershell
cd mobile
flutter pub get
flutter emulators
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use the ID from `flutter devices`. The example emulator name is specific to the development machine. `10.0.2.2` reaches the host computer from the Android emulator.

Under **Settings**, tap **Check connection**. Expect **Server connected**. The local library works independently of the backend.

## POCO X5 Pro over USB

Enable USB debugging and authorize the computer on the phone. With Django running, use these commands.

```powershell
adb devices
adb -s DEVICE_ID reverse tcp:8000 tcp:8000
cd mobile
flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Replace `DEVICE_ID` with the identifier reported by ADB. If `adb` is missing from PATH, find it under `Android/Sdk/platform-tools`. USB forwarding works without opening a network port.

For Wi-Fi, use the computer's IPv4 address in `API_BASE_URL`, add it to `DJANGO_ALLOWED_HOSTS` and start Django on `0.0.0.0:8000` on a trusted network. Open the firewall port only if needed. Use the computer's address from the phone.

The debug manifest permits plain HTTP. The release APK uses a dedicated signing key and HTTPS for lookups.

This setup sends lookups through the local Django server over USB. Change it in **Menu → Settings → Text search**. The release APK queries the sources directly over the phone's internet connection by default.

## Checks

### Audio download prototype

MP3 downloads require Android 10 or later on ARM64 or x86-64. The standard build can receive links. To compile with download support, get the pinned `yt-dlp` file and enable the integration. Gradle verifies its SHA-256. [yt-dlp 2026.10.26](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.26).

```powershell
$env:FOLOGNE_EXPERIMENTAL_DOWNLOADS = 'true'
$env:FOLOGNE_YTDLP_ZIPAPP = 'C:/path/to/yt-dlp'
cd mobile
flutter build apk --debug
```

This debug variant uses the package ID `com.musicapp.music_app.qa`. For the integration test, serve a test WAV file as `fologne-test.wav` on a local port and forward that port to the emulator with `adb reverse`. Run the following command from `mobile`.

```powershell
flutter test integration_test/audio_download_test.dart -d emulator-5554 --dart-define=FOLOGNE_AUDIO_FIXTURE_URL=http://127.0.0.1:18791/fologne-test.wav
```

The local server serves only the test file. The APK processes shared links on Android and bundles yt-dlp, Python, QuickJS and FFmpeg. To update the extractor, review the version, SHA-256 and marker in `AudioDownloads.kt`, then rebuild the APK. See the delivery guide for the review of bundled licenses. [youtubedl-android](https://github.com/yausername/youtubedl-android), [Licenses and source code](entrega.en.md#licenses-and-source-code).

### Routine checks

Run the backend checks from the repository root.

```powershell
$env:DJANGO_DEBUG = 'true'
backend/.venv/Scripts/python.exe backend/manage.py check
backend/.venv/Scripts/python.exe backend/manage.py test core --top-level-directory backend
backend/.venv/Scripts/python.exe -m ruff check backend
backend/.venv/Scripts/python.exe -m ruff format --check backend
```

Run the Flutter checks from `mobile`.

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d emulator-5554
flutter build apk --debug
```

The integration test needs an emulator with audio permission and prepared WAV files. It runs without Django. The local tests use no external services. The HTTP health test uses a temporary server. [Prepare the test audio](audio-local.en.md#integration-tests).

On the development machine, the emulator quit during tests with its default graphics settings. The test passed with the emulator started using `-gpu swangle -feature -Vulkan -cores 2 -no-snapshot` and the command `flutter test integration_test/app_test.dart -d emulator-5554 --no-enable-impeller`. Use `--no-enable-impeller` with `flutter run` to preview in that test environment. These flags apply only to the emulator test. [Flutter documentation for Impeller](https://docs.flutter.dev/perf/impeller).

## Local files

The `.gitignore` allowlist explicitly includes project files. It excludes virtual environments, caches, SQLite databases, logs, APKs, keys and local settings. Add newly created source directories to the allowlist.
