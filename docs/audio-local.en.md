# Local library and playback

[Leia em português](audio-local.md)

## Using the library

On first launch, tap **Allow audio access**. If Android blocks another prompt, use **Open app permissions**. The app reads files indexed by Android. Copy your music to the phone and refresh the library.

Search by title, artist or album. Sort tracks by title, artist, album or date added. Long-press a track to select several and add them to a playlist. Folders and albums are grouped by the available metadata.

The track menu lets you add a favorite, add a track to a playlist or see its details. You can add or remove playlist tracks, rename or delete a playlist, use one of its tracks as the cover and drag to reorder. Use the original order and clear the search to reorder manually. A playlist skips duplicates. Deleting a playlist leaves the audio files on the phone.

The player supports pause, previous and next, seeking, shuffle, repeat and an editable queue. **Previous** moves to the preceding track on the first tap. With repeat off, playback stops at the end of the queue. The queue opens with the current track at the top and scrolls to the next current track as playback advances. **Stop playback** in Settings stops the audio service.

The **Sleep timer** schedules a pause in 5 to 60 minutes. In **Settings**, adjust reading text size, choose a darker theme, toggle artwork backgrounds or change the interface language. In title order, libraries with at least 20 tracks show the side index.

## Lyrics and meanings

Start the search from the corresponding player tab. The app recognizes video titles such as `505 - Arctic Monkeys (Tradução/Letra)`, `- Topic` and `VEVO` channels, and title variants such as `*Asterisk`. Use **Edit search** if the match is wrong or missing. Lyrics keep the source language. When the selected recording has a different duration, lyrics appear without synchronization.

Use **Save offline** for eligible results. Open **Menu → Saved texts** to see storage usage and remove a track's saved texts. The app stores a UTF-8 JSON file per track in private storage, with separate records for lyrics and meanings and a total limit of 20 MiB.

LRCLIB lyrics are available online. The app's own song-meaning texts can be saved. Wikipedia provides links for context. [Lyrics and meaning sources](fontes.en.md).

## Storage

A native worker queries the library through MediaStore. Playback uses `content://` URIs and keeps audio files on the device. The app extracts embedded artwork on demand, scales it to at most 512 pixels and keeps a bounded cache. Files without artwork use the default image.

SQLite stores the tracks and a versioned state document. State covers playlists, favorites, history, sort order, queue, position and playback modes. Writes are serialized and atomic. The library is saved on refresh. The position is saved every five seconds, on player actions and on app lifecycle changes. An abrupt shutdown can lose the last few seconds of position.

The app restores the queue and position while paused. Playlists mark removed files as unavailable and preserve their references. A library refresh removes missing files from the playback queue. Revoking audio permission stops file access and preserves the saved organization.

History counts playback after 30 seconds of actual listening or halfway through a shorter track. Seeking adds no listening time. The app keeps up to 1,000 history entries and uses that window for **Most played**. Clearing history leaves favorites and playlists in place.

## Android

`just_audio` handles playback, `audio_service` integrates the media session, notifications and controls, and `audio_session` configures audio focus for music. The service stays in the foreground during pauses to allow resuming with system controls. **Stop playback** ends the service.

The notification uses the embedded cover's original colors. On the POCO, HyperOS derives the media card color from that artwork. Tracks without artwork use a navy default image. [Xiaomi media notification documentation](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2161).

The app requests `READ_MEDIA_AUDIO` on Android 13 and later, or `READ_EXTERNAL_STORAGE` on earlier versions, along with the playback service permissions. These requests are limited to the access needed for local audio.

The playback engine handles audio focus and headphone removal. On the POCO X5 Pro with Android 14 and HyperOS 2.0.17.0, the debug APK kept playing with the screen off and responded to pause and resume while locked. Real calls, headphone and Bluetooth behavior, and long playback under battery restrictions still need verification.

On the emulator, an active simulated GSM call paused playback. Playback remained paused after the call ended.

To check a debug APK on the POCO, play a local track, go to the home screen and lock the device. Use the media card to pause, resume and skip tracks. Try an incoming call, unplugging headphones and the buttons on a Bluetooth accessory. Observe playback after several minutes with the screen off and record the app's HyperOS battery setting.

## Integration tests

The test files are locally generated synthetic tones.

```powershell
python mobile/tool/create_test_audio.py artifacts/test-audio
adb shell mkdir -p /sdcard/Music/MusicAPP_Test
adb push artifacts/test-audio/. /sdcard/Music/MusicAPP_Test/
```

Ask Android to index each file before the test.

```powershell
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/MusicAPP_Test/MusicAPP_Test_01.wav
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/MusicAPP_Test/MusicAPP_Test_02.wav
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/MusicAPP_Test/MusicAPP_Test_03.wav
```

Install the debug APK and grant audio access on an Android 13 or later emulator.

```powershell
cd mobile
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant com.musicapp.music_app android.permission.READ_MEDIA_AUDIO
flutter test integration_test/app_test.dart -d emulator-5554 --no-enable-impeller
```

Replace the device ID as needed. The test uses local files and real SQLite and runs without Django or an internet connection. Use a test device because the test creates a playlist, changes the queue and adds the tones to listening history.

## References

- [Android MediaStore and shared audio access](https://developer.android.com/training/data-storage/shared/media).
- [just_audio](https://pub.dev/packages/just_audio).
- [audio_service](https://pub.dev/packages/audio_service).
- [audio_session](https://pub.dev/packages/audio_session).
