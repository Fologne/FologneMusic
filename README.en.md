# FologneMusic

[Leia em português](README.md)

An Android player for music stored on your phone, built with Flutter. Lyrics and song meanings use the phone's internet connection. The Django server and Docker setup are optional.

## Installation

Requires Android 7.0 or later.

1. Open [Releases](https://github.com/Fologne/FologneMusic/releases). Once version 2.0.0 is published, download `FologneMusic-2.0.0.apk` under **Assets**.
2. Open the APK from **Downloads** in your Android file manager. If Android asks, allow installation from that file manager and confirm.
3. Open FologneMusic and grant audio access. The app loads the music that Android has indexed on your device.

To update, install a newer APK over the existing app. Android preserves app data when the APKs use the same package name and signing key. [Android update rules](https://developer.android.com/google/play/app-updates).

## Features

- Browse tracks, folders and albums. Search by title, artist or album, sort tracks or jump to a letter.
- Refresh the library when opening or returning to the app, by pulling down the list or by tapping the refresh button.
- Play local files in the background with a mini player, editable queue, seeking, shuffle and repeat. **Previous** and **Next** move through the queue with one tap.
- Control playback from the notification and lock screen, with original track artwork and an X button to stop. Android chooses the card's color.
- Restore your previous queue and playback position when you reopen the app. Press play to resume.
- Create and edit playlists, add tracks in selection order, see covers in the picker, drag to reorder with a navy highlight, and choose a cover from the playlist.
- Browse favorites, play history and your most played tracks. **Recently Added** shows files from the last 90 days, newest first, using the creation date when Android provides it and the modification date otherwise.
- Delete music from the device through the track menu, with confirmation.
- Switch between **Music**, **Lyrics** and **Meaning** in the player, and set a sleep timer.
- Use a navy and black theme with a darker option, optional artwork backgrounds and adjustable reading text size.

## Audio downloads

Available on Android 10 and later. Select **FologneMusic** from YouTube's **Share** menu, or paste a link into the **Downloads** tab. Tap **Baixar MP3** (Download MP3) for videos you have permission to download and convert.

The tab shows the queue, progress and local history. You can cancel, retry or play completed files. Conversion runs on your phone and saves MP3s to `Music/FologneMusic`. [Build with download support](docs/desenvolvimento.md#protótipo-de-download-de-áudio).

## Lyrics and meanings

Tap **Buscar Letra** (Find Lyrics) or **Buscar Significado** (Find Meaning) in the player. If a file has incorrect tags, use **Corrigir busca** (Edit Search) to change the title or artist.

Lyrics come from LRCLIB and are displayed online. The Meaning tab shows notes from the app's catalog and links to Wikipedia when a matching article is available. Availability varies by track.

When a source permits downloads, tap **Salvar offline** (Save Offline). Manage saved texts under **Menu → Textos salvos** (Saved Texts). Local music and saved texts work offline.

## Development

The following guides are in Portuguese.

- [Run and test the app](docs/desenvolvimento.md)
- [Local library and playback](docs/audio-local.md)
- [Project decisions](docs/decisoes.md)
- [Lyrics and meaning sources](docs/fontes.md)
- [Content API](docs/api-conteudo.md)
- [Installation, signing and Docker](docs/entrega.md)

## License

The original FologneMusic code is distributed under the GNU General Public License, version 3 (`GPL-3.0-only`). Third-party components retain their own licenses. [License text](LICENSE) · [Component licenses and sources](docs/entrega.md#licenças-e-código-fonte)
