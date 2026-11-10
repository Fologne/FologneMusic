import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../content/content_api.dart';
import '../content/text_store.dart';
import '../core/theme.dart';
import '../l10n/localization.dart';
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
                                  context.localizedMessage(track.artist),
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
                  tooltip: state.playing
                      ? context.l10n.pause
                      : context.l10n.play,
                  onPressed: state.permitted ? state.togglePlaying : null,
                  icon: Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.openQueue,
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
                        tooltip: context.l10n.backToLibrary,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.nowPlaying,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.sleepTimer,
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
                        tooltip: context.l10n.openQueue,
                        onPressed: () => openQueue(context),
                        icon: const Icon(Icons.queue_music_rounded),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: context.l10n.music),
                    Tab(text: context.l10n.lyrics),
                    Tab(text: context.l10n.meaning),
                  ],
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.localizedMessage(state.error!),
                      style: const TextStyle(color: AppColors.accent),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      MusicTab(key: ValueKey(state.current?.id)),
                      for (final kind in TextKind.values)
                        if (track == null)
                          Notice(
                            icon: Icons.music_note,
                            title: context.l10n.chooseATrack,
                            message: context.l10n.chooseTrackHint,
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
          SectionTitle(context.l10n.sleepTimer),
          if (state.sleepUntil case final DateTime until)
            Text(
              context.l10n.playbackWillPauseAt(
                MaterialLocalizations.of(context)
                    .formatTimeOfDay(TimeOfDay.fromDateTime(until)),
              ),
            ),
          for (final minutes in [5, 15, 30, 45, 60])
            ListTile(
              title: Text(context.l10n.minutes(minutes)),
              onTap: () => Navigator.pop(context, minutes),
            ),
          if (state.sleepUntil != null)
            ListTile(
              title: Text(context.l10n.cancelSleepTimer),
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
      return Notice(
        icon: Icons.music_note,
        title: context.l10n.chooseATrack,
        message: context.l10n.chooseTrackHint,
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
                        context.localizedMessage(track.artist),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.favoriteTrack,
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
                  tooltip: context.l10n.toggleShuffle,
                  onPressed: state.toggleShuffle,
                  icon: Icon(
                    Icons.shuffle,
                    color: state.shuffle ? AppColors.accent : AppColors.muted,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.previousTrack,
                  onPressed: () => state.skip(-1),
                  icon: const Icon(Icons.skip_previous_rounded, size: 36),
                ),
                IconButton.filled(
                  key: const Key('player-toggle'),
                  tooltip: state.playing
                      ? context.l10n.pause
                      : context.l10n.play,
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
                  tooltip: context.l10n.nextTrack,
                  onPressed: () => state.skip(1),
                  icon: const Icon(Icons.skip_next_rounded, size: 36),
                ),
                IconButton(
                  tooltip: [
                    context.l10n.repeatOff,
                    context.l10n.repeatAll,
                    context.l10n.repeatOne,
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
              label: Text(context.l10n.addToPlaylist),
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.upNext),
              subtitle: Text(context.l10n.tracksInQueue(state.queue.length)),
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
  builder: (_) => const _QueueSheet(),
);

class _QueueSheet extends StatefulWidget {
  const _QueueSheet();

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  ScrollController? _scroll;
  String? _focusedTrack;
  bool _dragging = false;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final tracks = state.playbackQueue;
    final currentId = state.current?.id;
    final currentIndex = tracks.indexWhere((track) => track.id == currentId);
    final scaler = MediaQuery.textScalerOf(context);
    final rowHeight = math.max(
      84.0,
      scaler.scale(16) * 1.5 + scaler.scale(14) * 1.43 + 32,
    );
    final targetOffset = math.max(0, currentIndex) * rowHeight;
    if (_scroll == null) {
      _focusedTrack = currentId;
      _scroll = ScrollController(
        initialScrollOffset: targetOffset,
        keepScrollOffset: false,
      );
    } else if (!_dragging && _focusedTrack != currentId) {
      _focusedTrack = currentId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _dragging || _focusedTrack != currentId) return;
        final scroll = _scroll!;
        if (scroll.hasClients) {
          scroll.jumpTo(targetOffset.clamp(0, scroll.position.maxScrollExtent));
        }
      });
    }
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.playQueue,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.closeQueue,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => ReorderableListView.builder(
                  scrollController: _scroll,
                  itemExtent: rowHeight,
                  // Leave enough room to align even the last track at the top.
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    tracks.isEmpty
                        ? 0
                        : math.max(0, constraints.maxHeight - rowHeight),
                  ),
                  itemCount: tracks.length,
                  onReorderItem: state.reorder,
                  onReorderStart: (_) => _dragging = true,
                  onReorderEnd: (_) => setState(() => _dragging = false),
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return TrackTile(
                      key: ValueKey(track.id),
                      track: track,
                      onTap: () => state.selectInQueue(track),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.drag_handle,
                            semanticLabel: context.l10n.dragToReorder,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
