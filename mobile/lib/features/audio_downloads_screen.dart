import '../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/youtube_link.dart';
import '../library/audio_download_queue.dart';
import '../library/music_controller.dart';
import 'player_screen.dart';

Future<bool> confirmDownloadLink(
  BuildContext context,
  Uri link, {
  required bool available,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.youtubeLink),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(link.toString()),
            if (available) ...[
              const SizedBox(height: 12),
              Text(context.l10n.downloadPermissionNotice),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              available ? context.l10n.downloadMp3 : context.l10n.confirm,
            ),
          ),
        ],
      ),
    ) ??
    false;

class AudioDownloadsScreen extends StatefulWidget {
  const AudioDownloadsScreen({super.key, required this.queue});

  final AudioDownloadQueue queue;

  @override
  State<AudioDownloadsScreen> createState() => _AudioDownloadsScreenState();
}

class _AudioDownloadsScreenState extends State<AudioDownloadsScreen> {
  final _input = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    final link = youtubeVideoLink(_input.text);
    if (link == null) {
      setState(() => _error = context.l10n.invalidYoutubeLink);
      return;
    }
    if (!await confirmDownloadLink(context, link, available: true) ||
        !mounted) {
      return;
    }
    if (widget.queue.enqueue(link)) {
      widget.queue.requestNotifications().ignore();
      _input.clear();
      setState(() => _error = null);
    } else {
      setState(() => _error = context.l10n.duplicateDownloadLink);
    }
  }

  Future<void> _play(AudioDownload entry) async {
    final state = MusicScope.of(context);
    var track = state.byId(entry.trackId);
    if (track?.available != true) {
      await state.refreshAfterMediaChange();
      if (!mounted) return;
      track = state.byId(entry.trackId);
    }
    if (track == null || !track.available || !state.permitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.downloadFileUnavailable)),
      );
      return;
    }
    await state.select(track, from: [track]);
    if (mounted && state.current?.id == track.id) openPlayer(context);
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.clearDownloadHistory),
        content: Text(context.l10n.clearDownloadHistoryNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.clear),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) widget.queue.clearHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.queue,
    builder: (context, _) {
      final queue = widget.queue;
      final entries = queue.entries;
      return CustomScrollView(
        key: const PageStorageKey('audio-downloads'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList.list(
              children: [
                Text(
                  context.l10n.downloadMp3,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!queue.ready)
                  const LinearProgressIndicator()
                else if (!queue.available)
                  Text(context.l10n.downloadsUnavailable)
                else ...[
                  TextField(
                    controller: _input,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      labelText: context.l10n.youtubeLink,
                      errorText: _error,
                      suffixIcon: IconButton(
                        tooltip: context.l10n.pasteLink,
                        icon: const Icon(Icons.content_paste),
                        onPressed: () async {
                          final clipboard = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (!mounted || clipboard?.text == null) return;
                          _input.text = clipboard!.text!;
                          setState(() => _error = null);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.download),
                    label: Text(context.l10n.addToQueue),
                  ),
                ],
                if (queue.historyError)
                  Text(context.l10n.downloadHistoryUnavailable),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.queueAndHistory,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (entries.any((entry) => entry.finished))
                      IconButton(
                        tooltip: context.l10n.clearHistory,
                        onPressed: _clearHistory,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                if (entries.isEmpty) Text(context.l10n.noDownloadsYet),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) => _downloadTile(entries[index]),
            ),
          ),
        ],
      );
    },
  );

  Widget _downloadTile(AudioDownload entry) {
    final progress = entry.progress;
    final status = switch (entry.status) {
      AudioDownloadStatus.waiting => context.l10n.queued,
      AudioDownloadStatus.running when progress == 100 =>
        context.l10n.convertingAndSavingMp3,
      AudioDownloadStatus.running when progress != null =>
        context.l10n.downloadingAudio(progress),
      AudioDownloadStatus.running => context.l10n.preparingDownload,
      AudioDownloadStatus.canceling => context.l10n.canceling,
      AudioDownloadStatus.completed => context.l10n.completed,
      AudioDownloadStatus.failed =>
        entry.error == null
            ? context.l10n.downloadFailed
            : context.localizedMessage(entry.error!),
      AudioDownloadStatus.canceled => context.l10n.canceled,
    };
    final action = switch (entry.status) {
      AudioDownloadStatus.waiting || AudioDownloadStatus.running => IconButton(
        tooltip: context.l10n.cancelDownload,
        onPressed: () => widget.queue.cancel(entry),
        icon: const Icon(Icons.close),
      ),
      AudioDownloadStatus.failed || AudioDownloadStatus.canceled => IconButton(
        tooltip: context.l10n.tryAgain,
        onPressed: widget.queue.available
            ? () => widget.queue.retry(entry)
            : null,
        icon: const Icon(Icons.refresh),
      ),
      AudioDownloadStatus.completed => IconButton(
        tooltip: context.l10n.playMp3,
        onPressed: () => _play(entry),
        icon: const Icon(Icons.play_arrow),
      ),
      _ => null,
    };
    return ListTile(
      title: Text(
        entry.title ?? entry.link.toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status),
          if (entry.status == AudioDownloadStatus.running)
            LinearProgressIndicator(
              value: progress == null || progress == 100
                  ? null
                  : progress / 100,
            ),
        ],
      ),
      trailing: action,
    );
  }
}
