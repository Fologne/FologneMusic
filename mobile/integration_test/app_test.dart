import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:music_app/main.dart' as app;
import 'package:music_app/features/library_screen.dart';
import 'package:music_app/library/music_controller.dart';
import 'package:music_app/library/music_store.dart';
import 'package:music_app/library/media_library.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android lê arquivos, toca áudio e salva organização em SQLite', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final state = MusicScope.of(tester.element(find.byType(LibraryScreen)));
    for (var i = 0; i < 30 && (!state.initialized || state.loading); i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      state.permitted,
      isTrue,
      reason: 'Conceda READ_MEDIA_AUDIO ao APK antes do teste.',
    );
    final tracks = state.tracks
        .where((t) => t.title.startsWith('MusicAPP_Test'))
        .toList();
    expect(
      tracks.length,
      greaterThanOrEqualTo(2),
      reason: 'Copie os WAVs de teste para Music/MusicAPP_Test.',
    );
    debugPrint('MediaStore lido');
    final playlist = await state.createPlaylist('Integração Android');
    await state.addToPlaylist(playlist, tracks);
    await state.reorderPlaylist(playlist, 0, tracks.length - 1);
    if (!state.favorites.contains(tracks.first.id)) {
      await state.toggleFavorite(tracks.first);
    }
    debugPrint('Playlist salva');
    await state.select(tracks.first, from: tracks);
    await tester.pump(const Duration(seconds: 3));
    expect(state.playing, isTrue);
    expect(state.position, greaterThan(0));
    debugPrint('Áudio em reprodução');
    await state.seek(4);
    await tester.pump(const Duration(seconds: 1));
    expect(state.position, greaterThanOrEqualTo(4));
    debugPrint('Seek validado');
    await state.toggleShuffle();
    final shuffled = state.playbackQueue.map((track) => track.id).toList();
    expect(shuffled.first, state.current!.id);
    await state.skip(1);
    expect(state.current!.id, shuffled[1]);
    final expectedRepeat = (state.repeat + 1) % 3;
    await state.cycleRepeat();
    await state.reorder(0, tracks.length - 1);
    final reordered = [...shuffled.skip(1), shuffled.first];
    expect(state.playbackQueue.map((track) => track.id), reordered);
    expect(state.shuffle, isTrue);
    expect(state.repeat, expectedRepeat);
    await state.togglePlaying();
    await state.save();
    debugPrint('Fila salva');
    final db = await SqliteMusicStore.open();
    final saved = await db.readState();
    expect(
      (saved['playlists'] as List).any((p) => p['id'] == playlist.id),
      isTrue,
    );
    expect(saved['current'], state.current!.id);
    expect((await db.readTracks()).length, greaterThanOrEqualTo(2));
    debugPrint('SQLite validado');
    final savedId = state.current!.id;
    final savedPosition = state.position;
    final handler = state.handler;
    state.dispose();
    await handler.customAction('load', {
      'tracks': <Map<String, dynamic>>[],
      'index': 0,
      'play': false,
    });
    final restored = MusicController(
      media: AndroidMediaLibrary(),
      store: db,
      handler: handler,
    );
    debugPrint('Restaurando sessão');
    await restored.initialize();
    expect(restored.current?.id, savedId);
    expect(restored.playing, isFalse);
    expect(restored.position, closeTo(savedPosition, 1));
    expect(restored.favorites, contains(tracks.first.id));
    expect(restored.playbackQueue.map((track) => track.id), reordered);
    debugPrint('Sessão restaurada');
    await tester.pumpWidget(app.MusicApp(controller: restored));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letra'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar Letra'), findsOneWidget);
    await tester.tap(find.text('Significado'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar Significado'), findsOneWidget);
    debugPrint('Interface validada');
    final shortest = tracks.reduce(
      (a, b) => a.durationMs < b.durationMs ? a : b,
    );
    await restored.select(shortest, from: tracks);
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      restored.history.any((entry) => entry.trackId == shortest.id),
      isTrue,
    );
    debugPrint('Histórico validado');
    await restored.handler.stop();
    await restored.save();
    restored.dispose();
    expect(tester.takeException(), isNull);
  });
}
