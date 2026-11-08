import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/library/music_controller.dart';

import 'support/fakes.dart';

void main() {
  test(
    'exclusão cancelada preserva a faixa e confirmação atualiza a fila',
    () async {
      final media = FakeMedia()..allowDelete = false;
      final state = MusicController(
        media: media,
        store: MemoryStore(),
        handler: FakeHandler(),
      );
      addTearDown(state.dispose);
      await state.initialize();
      await state.select(testTracks.first, from: testTracks);
      expect(await state.deleteFromDevice(testTracks.first), isFalse);
      expect(state.tracks, hasLength(2));
      media.allowDelete = true;
      expect(await state.deleteFromDevice(testTracks.first), isTrue);
      expect(state.tracks.single.id, testTracks.last.id);
      expect(state.queue.single.id, testTracks.last.id);
    },
  );

  test(
    'restaura playlists, favoritos, ordem e posição sem tocar automaticamente',
    () async {
      final store = MemoryStore();
      final first = MusicController(
        media: FakeMedia(),
        store: store,
        handler: FakeHandler(),
      );
      await first.initialize();
      final playlist = await first.createPlaylist('Minha lista');
      await first.addToPlaylist(playlist, testTracks);
      await first.addToPlaylist(playlist, [testTracks.first]);
      expect(playlist.trackIds.length, 2);
      await first.reorderPlaylist(playlist, 0, 1);
      await first.renamePlaylist(playlist, 'Noite');
      await first.setCover(playlist, testTracks.last);
      await first.toggleFavorite(testTracks.first);
      await first.select(testTracks.first, from: testTracks);
      await first.seek(12);
      await first.togglePlaying();
      await first.setSort(TrackSort.newest);
      await first.save();
      first.dispose();
      final restored = MusicController(
        media: FakeMedia(),
        store: store,
        handler: FakeHandler(),
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.playlists.single.name, 'Noite');
      expect(restored.playlists.single.trackIds.first, testTracks.last.id);
      expect(restored.playlists.single.coverId, testTracks.last.id);
      expect(restored.favorites, contains(testTracks.first.id));
      expect(restored.current?.id, testTracks.first.id);
      expect(restored.position, closeTo(12, .5));
      expect(restored.playing, isFalse);
      expect(restored.sort, TrackSort.newest);
      await restored.deletePlaylist(restored.playlists.single);
      expect(restored.tracks.length, 2);
      expect((await store.readState())['playlists'], isEmpty);
    },
  );

  test('arquivo removido permanece na playlist, falha de scan não apaga biblioteca', () async {
    final media = FakeMedia();
    final state = MusicController(
      media: media,
      store: MemoryStore(),
      handler: FakeHandler(),
    );
    addTearDown(state.dispose);
    await state.initialize();
    final playlist = await state.createPlaylist('Guardadas');
    await state.addToPlaylist(playlist, testTracks);
    media.rows = [testTracks.last];
    await state.refresh();
    expect(state.tracks.length, 1);
    expect(state.playlistTracks(playlist).first.available, isFalse);
    media.failScan = true;
    await state.refresh();
    expect(state.error, isNotNull);
    expect(state.tracks.single.id, testTracks.last.id);
    media.allowed = false;
    await state.refresh();
    expect(state.permitted, isFalse);
    expect(playlist.trackIds.length, 2);
    expect(state.playing, isFalse);
  });

  test(
    'scan deduplica URIs e pesquisa artista sem depender do backend',
    () async {
      final media = FakeMedia()..rows = [...testTracks, testTracks.first];
      final state = MusicController(
        media: media,
        store: MemoryStore(),
        handler: FakeHandler(),
      );
      addTearDown(state.dispose);
      await state.initialize();
      expect(state.tracks.length, 2);
      expect(state.filtered('outro artista').single.id, testTracks.last.id);
      expect(state.filtered('não existe'), isEmpty);
    },
  );
}
