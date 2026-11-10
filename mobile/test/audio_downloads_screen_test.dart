import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/l10n/localization.dart';
import 'package:music_app/library/audio_download_queue.dart';
import 'package:music_app/library/music_controller.dart';
import 'package:music_app/main.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('aba Downloads valida o link e abre o MP3 no player', (
    tester,
  ) async {
    const channel = MethodChannel('musicapp/audioDownloads-screen-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final download = Completer<Map<String, String>>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'start') return download.future;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('fologne-screen-'),
    ))!;
    final history = File('${directory.path}/history.json');
    final state = MusicController(
      media: FakeMedia(),
      store: MemoryStore(),
      handler: FakeHandler(),
      language: AppLanguage.pt,
    );
    await state.initialize();
    final queue = AudioDownloadQueue(
      historyFile: history,
      refreshLibrary: state.refreshAfterMediaChange,
      channel: channel,
    );
    await tester.runAsync(queue.initialize);
    await tester.pumpWidget(MusicApp(controller: state, audioQueue: queue));
    await tester.pumpAndSettle();
    final tab = find.text('Downloads');
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'texto sem link');
    await tester.tap(find.text('Adicionar à fila'));
    await tester.pump();
    expect(find.text('Cole o link de um vídeo do YouTube.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/AbCde1234_-',
    );
    await tester.tap(find.text('Adicionar à fila'));
    await tester.pumpAndSettle();
    expect(
      find.text('https://www.youtube.com/watch?v=AbCde1234_-'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Baixar MP3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Preparando download…'), findsOneWidget);
    download.complete({
      'trackId': testTracks.first.id,
      'title': testTracks.first.title,
    });
    await tester.pumpAndSettle();
    expect(find.text('Concluído'), findsOneWidget);
    await tester.tap(find.byTooltip('Reproduzir MP3'));
    await tester.pumpAndSettle();
    expect(find.text('TOCANDO AGORA'), findsOneWidget);
    expect(state.current?.id, testTracks.first.id);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
