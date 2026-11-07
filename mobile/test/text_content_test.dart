import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/content/content_api.dart';
import 'package:music_app/content/text_store.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';

Map<String, dynamic> response(String text, {bool allowed = true}) => {
  'schema_version': 1,
  'status': 'found',
  'language': 'pt-BR',
  'text': text,
  'source': {
    'name': 'Fonte de teste',
    'url': 'https://example.test/music',
    'offline_allowed': allowed,
  },
};

void main() {
  test('HTTP distingue demora, limite e JSON inválido', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final base = 'http://127.0.0.1:${server.port}';
    final track = SearchTrack.fromTrack(testTracks.first);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      switch (payload['title']) {
        case 'Lenta':
          return;
        case 'Limite':
          request.response.statusCode = 429;
          break;
        default:
          request.response.write('html ou JSON corrompido');
      }
      await request.response.close();
    });
    final api = ContentApi(base);
    await expectLater(api.resolve(track), throwsFormatException);
    await expectLater(
      api.resolve(const SearchTrack('Limite', 'Artista', '', null)),
      throwsA(
        isA<ContentFailure>().having(
          (e) => e.message,
          'mensagem',
          contains('Limite'),
        ),
      ),
    );
    await expectLater(
      ContentApi(
        base,
        timeout: const Duration(milliseconds: 100),
      ).resolve(const SearchTrack('Lenta', 'Artista', '', null)),
      throwsA(
        isA<ContentFailure>().having(
          (e) => e.message,
          'mensagem',
          contains('demorou'),
        ),
      ),
    );
  });
  test(
    'LRC acompanha a posição e retorna a linha anterior até o próximo tempo',
    () {
      final trackText = TrackText.fromJson({
        ...response('Texto completo'),
        'synced_lrc': '[00:01.20]Primeira\n[00:03.00]Segunda',
      });
      expect(trackText.currentLine(1199), isNull);
      expect(trackText.currentLine(1200), 'Primeira');
      expect(trackText.currentLine(2999), 'Primeira');
      expect(trackText.currentLine(3000), 'Segunda');
    },
  );
  test(
    'JSON preserva dois textos independentes após reabrir e respeita permissão',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'fologne-download-test',
      );
      addTearDown(() => dir.delete(recursive: true));
      final store = TextStore(dir);
      final track = testTracks.first;
      final lyric = TrackText.fromJson(
        response('Primeira linha\nVersão com acento'),
      );
      final meaning = TrackText.fromJson(response('Contexto da faixa'));
      await Future.wait([
        store.save(track, TextKind.lyrics, 'lyrics-ref', lyric),
        store.save(track, TextKind.meaning, 'meaning-ref', meaning),
      ]);
      await expectLater(
        store.save(
          track,
          TextKind.lyrics,
          'other',
          TrackText.fromJson(response('restrita', allowed: false)),
        ),
        throwsA(isA<ContentFailure>()),
      );
      final reopened = TextStore(dir);
      expect((await reopened.read(track, TextKind.lyrics))?.text, lyric.text);
      expect(
        (await reopened.read(track, TextKind.meaning))?.text,
        meaning.text,
      );
      expect(await reopened.read(testTracks.last, TextKind.meaning), isNull);
      final entry = (await reopened.entries()).single;
      expect(entry.kinds, {TextKind.lyrics, TextKind.meaning});
      expect(entry.bytes, greaterThan(0));
      await reopened.remove(entry.key);
      expect(await reopened.entries(), isEmpty);
    },
  );

  test(
    'arquivo inválido é ignorado e limite não apaga download existente',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'fologne-download-test',
      );
      addTearDown(() => dir.delete(recursive: true));
      final store = TextStore(dir, maxBytes: 500);
      final track = testTracks.first;
      final file = File(p.join(dir.path, '${TextStore.keyFor(track)}.json'));
      await file.writeAsString('{interrompido');
      expect(await store.read(track, TextKind.lyrics), isNull);
      await store.save(
        track,
        TextKind.lyrics,
        'ref',
        TrackText.fromJson(response('salva')),
      );
      await expectLater(
        store.save(
          track,
          TextKind.meaning,
          'ref',
          TrackText.fromJson(response('x' * 600)),
        ),
        throwsA(isA<ContentFailure>()),
      );
      expect((await store.read(track, TextKind.lyrics))?.text, 'salva');
      expect(await store.read(track, TextKind.meaning), isNull);
    },
  );

  test('cliente envia apenas metadados e usa a referência escolhida', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    Map<String, dynamic>? requestData;
    server.listen((request) async {
      paths.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'POST') {
        expect(request.contentLength, greaterThan(0));
        requestData = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        final match = {
          'id': '.signed:reference:token',
          'track_key': 'stable-id',
          'track': requestData,
        };
        request.response.write(
          jsonEncode({
            'schema_version': 1,
            'status': 'ambiguous',
            'match': null,
            'metadata_match': match,
            'candidates': [match],
          }),
        );
      } else {
        request.response.write(
          jsonEncode(response('Letra de teste', allowed: false)),
        );
      }
      await request.response.close();
    });
    final api = ContentApi('http://127.0.0.1:${server.port}');
    final resolution = await api.resolve(
      SearchTrack.fromTrack(testTracks.first),
    );
    expect(resolution.status, 'ambiguous');
    expect(
      requestData!.keys,
      unorderedEquals(['title', 'artist', 'album', 'duration_ms']),
    );
    final text = await api.fetch(resolution.candidates.single, TextKind.lyrics);
    expect(text.text, 'Letra de teste');
    expect(text.offlineAllowed, isFalse);
    expect(paths, [
      '/api/v1/tracks/resolve/',
      '/api/v1/tracks/.signed:reference:token/lyrics/',
    ]);
  });
}
