import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/library/audio_download_queue.dart';

Future<void> until(String description, bool Function() condition) async {
  for (var count = 0; count < 300 && !condition(); count++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: description);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('musicapp/audioDownloads-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final first = Uri.parse('https://www.youtube.com/watch?v=AbCde1234_-');
  final second = Uri.parse('https://www.youtube.com/watch?v=LkMNopQ1234');

  test(
    'processa fila, cancela, tenta novamente e restaura histórico',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fologne-downloads-',
      );
      final history = File('${directory.path}/history.json');
      final starts = <String>[];
      final jobs = <Completer<Map<String, String>>>[];
      var refreshes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'available':
            return true;
          case 'start':
            starts.add((call.arguments as Map)['url'] as String);
            final job = Completer<Map<String, String>>();
            jobs.add(job);
            return job.future;
          case 'cancel':
            return true;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final queue = AudioDownloadQueue(
        historyFile: history,
        refreshLibrary: () async => refreshes++,
        channel: channel,
      );
      await queue.initialize();
      expect(queue.enqueueShared('texto sem link'), 'invalid');
      expect(queue.enqueueShared(first.toString()), 'started');
      expect(queue.enqueueShared('https://youtu.be/LkMNopQ1234'), 'queued');
      expect(queue.enqueueShared(second.toString()), 'duplicate');
      expect(starts, [first.toString()]);
      final queued = queue.entries.last;
      expect(queued.status, AudioDownloadStatus.waiting);
      await queue.cancel(queued);
      expect(queued.status, AudioDownloadStatus.canceled);
      queue.retry(queued);
      expect(queued.status, AudioDownloadStatus.waiting);

      final active = queue.entries.first;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('progress', 57),
        ),
        (_) {},
      );
      expect(active.progress, 57);
      await queue.cancel(active);
      expect(active.status, AudioDownloadStatus.canceling);
      jobs.first.completeError(PlatformException(code: 'canceled'));
      await until('próximo item iniciou', () => jobs.length == 2);
      expect(active.status, AudioDownloadStatus.canceled);
      jobs.last.completeError(
        PlatformException(code: 'download_failed', message: 'Sem conexão'),
      );
      await until(
        'falha recebida',
        () => queued.status == AudioDownloadStatus.failed,
      );
      expect(queued.error, 'Sem conexão');
      queue.retry(queued);
      await until('nova tentativa iniciou', () => jobs.length == 3);
      jobs.last.complete({
        'trackId': 'content://media/external/audio/media/3',
        'title': 'Faixa salva',
      });
      await until(
        'conclusão e atualização da biblioteca',
        () => queued.status == AudioDownloadStatus.completed && refreshes == 1,
      );
      await queue.historySaved;
      expect(await history.readAsString(), contains('Faixa salva'));
      queue.dispose();

      final reopened = AudioDownloadQueue(
        historyFile: history,
        refreshLibrary: () async {},
        channel: channel,
      );
      await reopened.initialize();
      expect(reopened.entries.map((entry) => entry.status), [
        AudioDownloadStatus.canceled,
        AudioDownloadStatus.completed,
      ]);
      expect(reopened.entries.last.trackId, queued.trackId);
      reopened.clearHistory();
      await reopened.historySaved;
      expect(await history.readAsString(), '[]');
      reopened.dispose();
      await directory.delete(recursive: true);
    },
  );

  test(
    'download interrompido volta como erro que pode ser tentado novamente',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fologne-downloads-',
      );
      final history = File('${directory.path}/history.json');
      await history.writeAsString(
        jsonEncode([
          {'link': first.toString(), 'status': 'running'},
          {'link': second.toString(), 'status': 'waiting'},
        ]),
      );
      final queue = AudioDownloadQueue(
        historyFile: history,
        refreshLibrary: () async {},
        channel: channel,
      );
      await queue.initialize();
      expect(queue.entries, hasLength(2));
      expect(
        queue.entries.every(
          (entry) => entry.status == AudioDownloadStatus.failed,
        ),
        isTrue,
      );
      queue.dispose();
      await directory.delete(recursive: true);
    },
  );
}
