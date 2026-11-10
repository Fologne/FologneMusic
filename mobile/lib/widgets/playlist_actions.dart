import '../l10n/localization.dart';

import 'package:flutter/material.dart';

import '../library/music_controller.dart';
import 'common.dart';

Future<String?> playlistNameDialog(
  BuildContext context, {
  String initial = '',
}) {
  var value = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(
          initial.isEmpty
              ? context.l10n.newPlaylist
              : context.l10n.renamePlaylist,
        ),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(labelText: context.l10n.name),
          onChanged: (text) => update(() => value = text),
          onFieldSubmitted: (_) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: value.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    ),
  );
}

Future<void> addTracksToPlaylist(
  BuildContext context,
  List<Track> tracks,
) async {
  final state = MusicScope.of(context);
  final id = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              context.l10n.addToPlaylist,
              style: TextStyle(fontSize: 22),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(context.l10n.newPlaylist),
            onTap: () => Navigator.pop(context, 'new'),
          ),
          for (final playlist in state.playlists)
            ListTile(
              title: Text(playlist.name),
              onTap: () => Navigator.pop(context, playlist.id),
            ),
        ],
      ),
    ),
  );
  if (id == null || !context.mounted) return;
  MusicPlaylist? playlist;
  if (id == 'new') {
    final name = await playlistNameDialog(context);
    if (name == null) return;
    playlist = await state.createPlaylist(name);
  } else {
    playlist = state.playlistById(id);
  }
  if (playlist != null) {
    await state.addToPlaylist(playlist, tracks);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addedTo(playlist.name))),
      );
    }
  }
}

Future<void> pickPlaylistTracks(
  BuildContext context,
  MusicPlaylist playlist,
) async {
  final state = MusicScope.of(context);
  final selected = <String>{};
  var query = '';
  final ids = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final tracks = state.filtered(query);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .7,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      context.l10n.addTracks,
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: context.l10n.searchTracks,
                      ),
                      onChanged: (text) => update(() => query = text),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final exists = playlist.trackIds.contains(track.id);
                        return CheckboxListTile(
                          secondary: CoverArt(track: track, size: 44),
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            exists
                                ? context.l10n.alreadyAdded
                                : context.localizedMessage(track.artist),
                          ),
                          value: exists || selected.contains(track.id),
                          onChanged: exists
                              ? null
                              : (checked) => update(() {
                                  if (checked!) {
                                    selected.add(track.id);
                                  } else {
                                    selected.remove(track.id);
                                  }
                                }),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, selected),
                      child: Text(context.l10n.add(selected.length)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  if (ids != null) {
    await state.addToPlaylist(playlist, ids.map(state.byId).whereType<Track>());
  }
}
