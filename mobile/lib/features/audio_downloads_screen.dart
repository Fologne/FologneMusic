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
        title: const Text('Link do YouTube'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(link.toString()),
            if (available) ...[
              const SizedBox(height: 12),
              const Text(
                'Baixe apenas vídeos que você tem autorização para baixar e converter.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(available ? 'Baixar MP3' : 'Confirmar'),
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
      setState(() => _error = 'Cole o link de um vídeo do YouTube.');
      return;
    }
    if (!await confirmDownloadLink(context, link, available: true) ||
        !mounted) {
      return;
    }
    if (widget.queue.enqueue(link)) {
      _input.clear();
      setState(() => _error = null);
    } else {
      setState(() => _error = 'Este link já está na fila ou no histórico.');
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
        const SnackBar(content: Text('Arquivo indisponível na biblioteca.')),
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
        title: const Text('Limpar histórico de downloads?'),
        content: const Text('Os MP3 salvos continuam na biblioteca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
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
                  'Baixar MP3',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!queue.ready)
                  const LinearProgressIndicator()
                else if (!queue.available)
                  const Text(
                    'O download de áudio está disponível no APK experimental em aparelhos compatíveis.',
                  )
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
                      labelText: 'Link do YouTube',
                      errorText: _error,
                      suffixIcon: IconButton(
                        tooltip: 'Colar link',
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
                    label: const Text('Adicionar à fila'),
                  ),
                ],
                if (queue.historyError)
                  const Text(
                    'Não foi possível acessar o histórico de downloads.',
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fila e histórico',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (entries.any((entry) => entry.finished))
                      IconButton(
                        tooltip: 'Limpar histórico',
                        onPressed: _clearHistory,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                if (entries.isEmpty)
                  const Text('Nenhum download por enquanto.'),
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
      AudioDownloadStatus.waiting => 'Na fila',
      AudioDownloadStatus.running when progress == 100 =>
        'Convertendo e salvando MP3…',
      AudioDownloadStatus.running when progress != null =>
        'Baixando áudio · $progress%',
      AudioDownloadStatus.running => 'Preparando download…',
      AudioDownloadStatus.canceling => 'Cancelando…',
      AudioDownloadStatus.completed => 'Concluído',
      AudioDownloadStatus.failed => entry.error ?? 'Falha no download.',
      AudioDownloadStatus.canceled => 'Cancelado',
    };
    final action = switch (entry.status) {
      AudioDownloadStatus.waiting || AudioDownloadStatus.running => IconButton(
        tooltip: 'Cancelar download',
        onPressed: () => widget.queue.cancel(entry),
        icon: const Icon(Icons.close),
      ),
      AudioDownloadStatus.failed || AudioDownloadStatus.canceled => IconButton(
        tooltip: 'Tentar novamente',
        onPressed: widget.queue.available
            ? () => widget.queue.retry(entry)
            : null,
        icon: const Icon(Icons.refresh),
      ),
      AudioDownloadStatus.completed => IconButton(
        tooltip: 'Reproduzir MP3',
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
