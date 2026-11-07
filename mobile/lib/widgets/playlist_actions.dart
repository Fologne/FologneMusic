import 'package:flutter/material.dart';

import '../library/music_controller.dart';

Future<String?> playlistNameDialog(
  BuildContext context, {
  String initial = '',
}) {
  var value = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(initial.isEmpty ? 'Nova playlist' : 'Renomear playlist'),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Nome'),
          onChanged: (text) => update(() => value = text),
          onFieldSubmitted: (_) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: value.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.trim()),
            child: const Text('Salvar'),
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
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Adicionar à playlist', style: TextStyle(fontSize: 22)),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Nova playlist'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Adicionado a ${playlist.name}')));
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
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Adicionar músicas',
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Pesquisar músicas',
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
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            exists ? 'Já adicionada' : track.artist,
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
                      child: Text('Adicionar (${selected.length})'),
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
