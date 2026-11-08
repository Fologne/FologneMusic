import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/theme.dart';
import '../library/audio_download_queue.dart';
import '../library/music_controller.dart';
import '../widgets/common.dart';
import '../widgets/playlist_actions.dart';
import 'audio_downloads_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.audioQueue});
  final AudioDownloadQueue? audioQueue;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String query = '';
  bool searching = false;
  final selected = <String>{};
  final sectionKeys = <String, GlobalKey>{};
  static final letterPattern = RegExp(r'^[A-Z]$');

  String _initial(String title) {
    final runes = title.trimLeft().runes;
    if (runes.isEmpty) return '*';
    final letter = String.fromCharCode(runes.first).toUpperCase();
    return letterPattern.hasMatch(letter) ? letter : '*';
  }

  void openCollection(String title, String kind, [String? value]) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              CollectionScreen(title: title, kind: kind, value: value),
        ),
      );

  Widget collection(
    String title,
    String kind,
    int count,
    IconData icon, [
    String? value,
  ]) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    leading: Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.accent),
    ),
    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(musicCount(count)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => openCollection(title, kind, value),
  );

  Widget _refreshList(
    MusicController state,
    List<Widget> children, {
    EdgeInsetsGeometry? padding,
  }) => RefreshIndicator(
    onRefresh: state.refresh,
    semanticsLabel: 'Atualizar biblioteca',
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: children,
    ),
  );

  Widget _trackPage(MusicController state, List<Track> filtered) {
    final useIndex =
        state.sort == TrackSort.title && query.isEmpty && filtered.length >= 20;
    final groups = <String, List<Track>>{};
    if (useIndex) {
      for (final track in filtered) {
        (groups[_initial(track.title)] ??= []).add(track);
      }
      final special = groups.remove('*');
      if (special != null) groups['*'] = special;
    } else {
      groups[''] = filtered;
    }
    sectionKeys.removeWhere((letter, _) => !groups.containsKey(letter));
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: state.refresh,
          semanticsLabel: 'Atualizar biblioteca',
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const PageStorageKey('track-list'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 12, useIndex ? 60 : 16, 8),
                sliver: SliverList.list(
                  children: [
                    SectionTitle(
                      selected.isEmpty
                          ? musicCount(filtered.length)
                          : '${selected.length} selecionadas',
                      trailing: selected.isEmpty
                          ? PopupMenuButton<TrackSort>(
                              tooltip: 'Ordenar músicas',
                              icon: const Icon(Icons.sort),
                              onSelected: state.setSort,
                              itemBuilder: (_) => [
                                for (final value in TrackSort.values)
                                  PopupMenuItem(
                                    value: value,
                                    child: Text(sortLabel(value)),
                                  ),
                              ],
                            )
                          : IconButton(
                              tooltip: 'Limpar seleção',
                              onPressed: () => setState(selected.clear),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    if (selected.isEmpty)
                      PlaybackButtons(tracks: filtered)
                    else
                      FilledButton.icon(
                        onPressed: () async {
                          await addTracksToPlaylist(
                            context,
                            selected
                                .map(state.byId)
                                .whereType<Track>()
                                .toList(),
                          );
                          if (mounted) setState(selected.clear);
                        },
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('Adicionar à playlist'),
                      ),
                    if (filtered.isEmpty)
                      Notice(
                        icon: query.isEmpty
                            ? Icons.music_note_outlined
                            : Icons.search_off,
                        title: query.isEmpty
                            ? 'Nenhuma música no aparelho'
                            : 'Nenhuma música encontrada',
                        message: query.isEmpty
                            ? 'Copie arquivos de áudio para o celular e toque em atualizar.'
                            : 'Tente outro título, artista ou álbum.',
                      ),
                  ],
                ),
              ),
              for (final group in groups.entries) ...[
                if (useIndex)
                  SliverToBoxAdapter(
                    child: Padding(
                      key: sectionKeys.putIfAbsent(group.key, GlobalKey.new),
                      padding: const EdgeInsets.fromLTRB(24, 16, 56, 4),
                      child: Semantics(
                        header: true,
                        child: Text(
                          group.key,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 8, useIndex ? 60 : 24, 16),
                  sliver: SliverList.builder(
                    itemCount: group.value.length,
                    itemBuilder: (context, index) {
                      final track = group.value[index];
                      void toggleSelection() => setState(() {
                        if (!selected.add(track.id)) selected.remove(track.id);
                      });
                      return TrackTile(
                        track: track,
                        onLongPress: toggleSelection,
                        trailing: selected.isEmpty
                            ? null
                            : Checkbox(
                                value: selected.contains(track.id),
                                onChanged: (_) => toggleSelection(),
                              ),
                        onTap: () async {
                          if (selected.isNotEmpty) {
                            toggleSelection();
                            return;
                          }
                          await state.select(track, from: filtered);
                          if (context.mounted && state.current != null) {
                            openPlayer(context);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (useIndex)
          Positioned(
            top: 8,
            bottom: 8,
            right: 4,
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: AppColors.surface.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(22),
                child: ListView(
                  primary: false,
                  shrinkWrap: true,
                  children: [
                    for (final letter in groups.keys)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: () {
                          final target = sectionKeys[letter]?.currentContext;
                          if (target != null) {
                            Scrollable.ensureVisible(
                              target,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                            );
                          }
                        },
                        child: Text(
                          letter,
                          semanticsLabel: letter == '*'
                              ? 'Ir para outros caracteres'
                              : 'Ir para $letter',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final filtered = state.filtered(query);
    final tracks = state.tracks;
    return DefaultTabController(
      length: widget.audioQueue == null ? 5 : 6,
      initialIndex: 1,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'android/app/src/main/res/drawable-nodpi/fologne_launcher_art.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Pesquisar músicas',
                        onPressed: () => setState(() {
                          searching = !searching;
                          if (!searching) query = '';
                        }),
                        icon: Icon(searching ? Icons.close : Icons.search),
                      ),
                      IconButton(
                        tooltip: 'Atualizar biblioteca',
                        onPressed: state.loading ? null : () => state.refresh(),
                        icon: const Icon(Icons.refresh),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Menu',
                        onSelected: (value) {
                          final store = state.downloads;
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  value == 'downloads' && store != null
                                  ? DownloadsScreen(store: store)
                                  : const SettingsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'settings',
                            child: Text('Configurações'),
                          ),
                          if (state.downloads != null)
                            const PopupMenuItem(
                              value: 'downloads',
                              child: Text('Textos salvos'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (searching)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Título, artista ou álbum',
                      ),
                      onChanged: (value) => setState(() => query = value),
                    ),
                  ),
                TabBar(
                  isScrollable: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tabs: [
                    const Tab(text: 'Para você'),
                    const Tab(text: 'Faixas'),
                    const Tab(text: 'Playlists'),
                    const Tab(text: 'Pastas'),
                    const Tab(text: 'Álbuns'),
                    if (widget.audioQueue != null) const Tab(text: 'Downloads'),
                  ],
                ),
                if (state.loading) const LinearProgressIndicator(minHeight: 2),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.error!,
                            style: const TextStyle(color: AppColors.accent),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar aviso',
                          onPressed: state.clearError,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      if (!state.permitted && !state.loading)
                        for (var index = 0; index < 5; index++)
                          _refreshList(state, [
                            Notice(
                              icon: Icons.library_music_outlined,
                              title: 'Sua música começa aqui',
                              message: 'Permita o acesso aos arquivos de áudio para encontrar as músicas do celular. Seus arquivos não serão enviados ao servidor.',
                              action: Column(
                                children: [
                                  FilledButton(
                                    onPressed: () =>
                                        state.refresh(request: true),
                                    child: const Text(
                                      'Permitir acesso ao áudio',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: state.media.openSettings,
                                    child: const Text(
                                      'Abrir permissões do aplicativo',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ])
                      else ...[
                        _refreshList(state, [
                          const Text(
                            'NO SEU RITMO',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontSize: 11,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sua música.\nSempre por perto.',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ouça seus arquivos, mesmo sem internet.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SectionTitle('Sua atividade'),
                          collection(
                            'Meus favoritos',
                            'favorites',
                            tracks
                                .where((t) => state.favorites.contains(t.id))
                                .length,
                            Icons.favorite_border,
                          ),
                          collection(
                            'Reproduzidas recentemente',
                            'recent',
                            state.recent.length,
                            Icons.history,
                          ),
                          collection(
                            'Mais ouvidas',
                            'most',
                            state.mostPlayed.length,
                            Icons.equalizer,
                          ),
                          if (state.history.isEmpty)
                            const Text(
                              'Seu histórico aparece após ouvir 30 segundos ou metade de uma música curta.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                        ], padding: const EdgeInsets.all(24)),
                        _trackPage(state, filtered),
                        _refreshList(state, [
                          const SectionTitle('Sua coleção'),
                          collection(
                            'Meus favoritos',
                            'favorites',
                            tracks
                                .where((t) => state.favorites.contains(t.id))
                                .length,
                            Icons.favorite_border,
                          ),
                          collection(
                            'Adicionadas recentemente',
                            'added',
                            state.recentlyAdded.length,
                            Icons.library_add_outlined,
                          ),
                          collection(
                            'Reproduzidas recentemente',
                            'recent',
                            state.recent.length,
                            Icons.history,
                          ),
                          collection(
                            'Mais ouvidas',
                            'most',
                            state.mostPlayed.length,
                            Icons.equalizer,
                          ),
                          SectionTitle(
                            'Minhas playlists',
                            trailing: IconButton(
                              tooltip: 'Criar playlist',
                              onPressed: () async {
                                final name = await playlistNameDialog(context);
                                if (name != null) {
                                  await state.createPlaylist(name);
                                }
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ),
                          if (state.playlists.isEmpty)
                            const Text(
                              'Crie uma playlist para organizar suas músicas.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          for (final playlist in state.playlists)
                            collection(
                              playlist.name,
                              'playlist',
                              playlist.trackIds.length,
                              Icons.queue_music,
                              playlist.id,
                            ),
                        ], padding: const EdgeInsets.all(24)),
                        _refreshList(state, [
                          const SectionTitle('Suas pastas'),
                          for (final folder
                              in tracks.map((t) => t.folder).toSet().toList()
                                ..sort())
                            collection(
                              folder,
                              'folder',
                              tracks.where((t) => t.folder == folder).length,
                              Icons.folder_outlined,
                              folder,
                            ),
                        ], padding: const EdgeInsets.all(24)),
                        _refreshList(state, [
                          const SectionTitle('Seus álbuns'),
                          for (final album
                              in tracks
                                  .map((t) => '${t.album}\u0000${t.artist}')
                                  .toSet()
                                  .toList()
                                ..sort())
                            collection(
                              album.split('\u0000').first,
                              'album',
                              tracks
                                  .where(
                                    (t) =>
                                        '${t.album}\u0000${t.artist}' == album,
                                  )
                                  .length,
                              Icons.album_outlined,
                              album,
                            ),
                        ], padding: const EdgeInsets.all(24)),
                      ],
                      if (widget.audioQueue case final queue?)
                        AudioDownloadsScreen(queue: queue),
                    ],
                  ),
                ),
                const MiniPlayer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String sortLabel(TrackSort value) => switch (value) {
  TrackSort.title => 'Título',
  TrackSort.artist => 'Artista',
  TrackSort.album => 'Álbum',
  TrackSort.newest => 'Adição mais recente',
};

class PlaybackButtons extends StatelessWidget {
  const PlaybackButtons({super.key, required this.tracks});
  final List<Track> tracks;
  @override
  Widget build(BuildContext context) {
    final available = tracks.where((t) => t.available).toList();
    Future<void> start(bool random) async {
      final state = MusicScope.of(context);
      final order = List<Track>.of(available);
      if (random) order.shuffle();
      await state.select(order.first, from: available, random: random);
      if (context.mounted && state.current != null) openPlayer(context);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: available.isEmpty ? null : () => start(false),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Reproduzir'),
        ),
        OutlinedButton.icon(
          onPressed: available.isEmpty ? null : () => start(true),
          icon: const Icon(Icons.shuffle),
          label: const Text('Aleatório'),
        ),
      ],
    );
  }
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.title,
    required this.kind,
    this.value,
  });
  final String title;
  final String kind;
  final String? value;
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String query = '';
  bool sorted = false;
  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final playlist = widget.kind == 'playlist'
        ? state.playlistById(widget.value!)
        : null;
    var tracks = switch (widget.kind) {
      'playlist' =>
        playlist == null ? <Track>[] : state.playlistTracks(playlist),
      'favorites' =>
        state.tracks.where((t) => state.favorites.contains(t.id)).toList(),
      'recent' => state.recent,
      'most' => state.mostPlayed,
      'added' => state.recentlyAdded,
      'folder' => state.tracks.where((t) => t.folder == widget.value).toList(),
      'album' =>
        state.tracks
            .where((t) => '${t.album}\u0000${t.artist}' == widget.value)
            .toList(),
      _ => <Track>[],
    };
    final all = List<Track>.of(tracks);
    if (sorted) {
      tracks.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    tracks = tracks
        .where(
          (t) => '${t.title} ${t.artist}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    final cover = state.byId(playlist?.coverId) ?? all.firstOrNull;
    final canReorder = playlist != null && query.isEmpty && !sorted;
    return Scaffold(
      body: AppBackground(
        cover: state.coverBackground ? cover : null,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text(playlist?.name ?? widget.title),
                actions: [
                  if (playlist != null)
                    PopupMenuButton<String>(
                      tooltip: 'Editar playlist',
                      onSelected: (action) async {
                        if (action == 'rename') {
                          final name = await playlistNameDialog(
                            context,
                            initial: playlist.name,
                          );
                          if (name != null) {
                            await state.renamePlaylist(playlist, name);
                          }
                        } else if (action == 'cover') {
                          final trackId = await showDialog<String>(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('Capa da playlist'),
                              children: [
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(context, ''),
                                  child: const Text('Usar primeira música'),
                                ),
                                for (final track in all)
                                  SimpleDialogOption(
                                    onPressed: () =>
                                        Navigator.pop(context, track.id),
                                    child: Text(track.title),
                                  ),
                              ],
                            ),
                          );
                          if (trackId != null) {
                            await state.setCover(playlist, state.byId(trackId));
                          }
                        } else if (action == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Excluir playlist?'),
                              content: const Text(
                                'Os arquivos de música serão mantidos no celular.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await state.deletePlaylist(playlist);
                            if (context.mounted) Navigator.pop(context);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Renomear')),
                        PopupMenuItem(
                          value: 'cover',
                          child: Text('Alterar capa'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir playlist'),
                        ),
                      ],
                    ),
                ],
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList.list(
                        children: [
                          if (cover != null)
                            Center(child: CoverArt(track: cover, size: 160)),
                          const SizedBox(height: 20),
                          Text(
                            playlist?.name ?? widget.title,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            musicCount(all.length),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 20),
                          PlaybackButtons(tracks: tracks),
                          const SizedBox(height: 20),
                          if (playlist != null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  pickPlaylistTracks(context, playlist),
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Adicionar músicas'),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Pesquisar nesta lista',
                                  ),
                                  onChanged: (text) =>
                                      setState(() => query = text),
                                ),
                              ),
                              IconButton(
                                tooltip: sorted
                                    ? 'Ordem original'
                                    : 'Ordenar por título',
                                onPressed: () =>
                                    setState(() => sorted = !sorted),
                                icon: const Icon(Icons.sort_by_alpha),
                              ),
                            ],
                          ),
                          if (all.isEmpty)
                            Notice(
                              icon: Icons.queue_music,
                              title: 'Ainda sem músicas',
                              message: widget.kind == 'added'
                                  ? 'Nenhum arquivo de áudio dos últimos 90 dias.'
                                  : 'Adicione músicas ou ouça sua biblioteca para preencher esta lista.',
                            ),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverReorderableList(
                        itemCount: tracks.length,
                        proxyDecorator: (child, _, _) => Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          elevation: 4,
                          child: child,
                        ),
                        onReorderItem: (from, to) {
                          if (canReorder) {
                            state.reorderPlaylist(playlist, from, to);
                          }
                        },
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return TrackTile(
                            key: ValueKey(track.id),
                            track: track,
                            onTap: () async {
                              await state.select(track, from: tracks);
                              if (context.mounted &&
                                  track.available &&
                                  state.current != null) {
                                openPlayer(context);
                              }
                            },
                            trailing: playlist == null
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Remover da playlist',
                                        onPressed: () =>
                                            state.removeFromPlaylist(
                                              playlist,
                                              track,
                                            ),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      if (canReorder)
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Icon(
                                              Icons.drag_handle,
                                              semanticLabel:
                                                  'Arraste para reordenar',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
              const MiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}
