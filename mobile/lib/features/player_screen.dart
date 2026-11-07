import 'package:flutter/material.dart';

import '../content/content_api.dart';
import '../content/text_store.dart';
import '../core/theme.dart';
import '../library/music_controller.dart';
import '../widgets/common.dart';
import '../widgets/playlist_actions.dart';
import 'content_tab.dart';

void openPlayer(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
);

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final track = state.current;
    if (track == null) return const SizedBox.shrink();
    return Material(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: state.buffering
                ? null
                : state.duration <= 0
                ? 0
                : state.position / state.duration,
            minHeight: 2,
            backgroundColor: AppColors.border,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('open-player'),
                    onTap: () => openPlayer(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CoverArt(track: track, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: state.playing ? 'Pausar' : 'Reproduzir',
                  onPressed: state.permitted ? state.togglePlaying : null,
                  icon: Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Abrir fila',
                  onPressed: () => openQueue(context),
                  icon: const Icon(Icons.queue_music_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final track = state.current;
    final contentKey = track == null ? '' : TextStore.keyFor(track);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: AppBackground(
          cover: state.coverBackground ? track : null,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Voltar à biblioteca',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'TOCANDO AGORA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Temporizador',
                        onPressed: () => _openSleepTimer(context, state),
                        icon: Icon(
                          state.sleepUntil == null
                              ? Icons.bedtime_outlined
                              : Icons.bedtime,
                          color: state.sleepUntil == null
                              ? null
                              : AppColors.accent,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Abrir fila',
                        onPressed: () => openQueue(context),
                        icon: const Icon(Icons.queue_music_rounded),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: 'Música'),
                    Tab(text: 'Letra'),
                    Tab(text: 'Significado'),
                  ],
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.accent),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      MusicTab(key: ValueKey(state.current?.id)),
                      for (final kind in TextKind.values)
                        if (track == null)
                          const Notice(
                            icon: Icons.music_note,
                            title: 'Escolha uma música',
                            message: 'Selecione uma faixa na biblioteca.',
                          )
                        else
                          ContentTab(
                            key: ValueKey('${kind.name}:$contentKey'),
                            track: track,
                            kind: kind,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openSleepTimer(
  BuildContext context,
  MusicController state,
) async {
  final choice = await showModalBottomSheet<int>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          const SectionTitle('Temporizador'),
          if (state.sleepUntil case final DateTime until)
            Text(
              'Pausa programada para ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(until))}.',
            ),
          for (final minutes in [5, 15, 30, 45, 60])
            ListTile(
              title: Text('$minutes minutos'),
              onTap: () => Navigator.pop(context, minutes),
            ),
          if (state.sleepUntil != null)
            ListTile(
              title: const Text('Cancelar temporizador'),
              onTap: () => Navigator.pop(context, 0),
            ),
        ],
      ),
    ),
  );
  if (choice != null && context.mounted) {
    await state.setSleepTimer(choice);
  }
}

class MusicTab extends StatefulWidget {
  const MusicTab({super.key});
  @override
  State<MusicTab> createState() => _MusicTabState();
}

class _MusicTabState extends State<MusicTab> {
  double? dragging;
  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final track = state.current;
    if (track == null) {
      return const Notice(
        icon: Icons.music_note,
        title: 'Escolha uma música',
        message: 'Selecione uma faixa na biblioteca.',
      );
    }
    final position = (dragging ?? state.position).clamp(0.0, state.duration);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          children: [
            Center(
              child: CoverArt(
                track: track,
                size: (constraints.maxWidth - 72).clamp(140, 320),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Favoritar música',
                  onPressed: () => state.toggleFavorite(track),
                  icon: Icon(
                    state.favorites.contains(track.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              value: position,
              max: state.duration <= 0 ? 1 : state.duration,
              onChanged: state.duration <= 0
                  ? null
                  : (value) => setState(() => dragging = value),
              onChangeEnd: (value) async {
                await state.seek(value);
                if (mounted) setState(() => dragging = null);
              },
              semanticFormatterCallback: durationLabel,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  durationLabel(position),
                  style: const TextStyle(color: AppColors.muted),
                ),
                Text(
                  durationLabel(state.duration),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.buffering)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Alternar aleatório',
                  onPressed: state.toggleShuffle,
                  icon: Icon(
                    Icons.shuffle,
                    color: state.shuffle ? AppColors.accent : AppColors.muted,
                  ),
                ),
                IconButton(
                  tooltip: 'Música anterior',
                  onPressed: () => state.skip(-1),
                  icon: const Icon(Icons.skip_previous_rounded, size: 36),
                ),
                IconButton.filled(
                  key: const Key('player-toggle'),
                  tooltip: state.playing ? 'Pausar' : 'Reproduzir',
                  style: IconButton.styleFrom(minimumSize: const Size(72, 72)),
                  onPressed: state.permitted ? state.togglePlaying : null,
                  icon: Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 36,
                  ),
                ),
                IconButton(
                  tooltip: 'Próxima música',
                  onPressed: () => state.skip(1),
                  icon: const Icon(Icons.skip_next_rounded, size: 36),
                ),
                IconButton(
                  tooltip: [
                    'Repetição desligada',
                    'Repetir todas',
                    'Repetir uma',
                  ][state.repeat],
                  onPressed: state.cycleRepeat,
                  icon: Icon(
                    state.repeat == 2 ? Icons.repeat_one : Icons.repeat,
                    color: state.repeat == 0
                        ? AppColors.muted
                        : AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => addTracksToPlaylist(context, [track]),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Adicionar à playlist'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('A seguir'),
              subtitle: Text('${musicCount(state.queue.length)} na fila'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openQueue(context),
            ),
          ],
        ),
      ),
    );
  }
}

void openQueue(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) {
    final state = MusicScope.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Fila de reprodução',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar fila',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: state.queue.length,
                onReorderItem: state.reorder,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final track = state.queue[index];
                  return TrackTile(
                    key: ValueKey(track.id),
                    track: track,
                    onTap: () => state.selectInQueue(track),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.drag_handle,
                          semanticLabel: 'Arraste para reordenar',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  },
);
