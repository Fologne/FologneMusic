import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/content/content_api.dart';
import 'package:music_app/content/direct_content_api.dart';

Map<String, Object> record(
  int id,
  String title,
  String artist, {
  int duration = 255,
}) => {
  'id': id,
  'trackName': title,
  'artistName': artist,
  'duration': duration,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'busca direta corrige título de vídeo e filtra outro artista e versão',
    () async {
      final calls = <Uri>[];
      final api = DirectContentApi(
        request: (uri) async {
          calls.add(uri);
          final song = record(10, '505', 'Arctic Monkeys');
          if (uri.path == '/api/get/10') {
            return {...song, 'plainLyrics': 'Linha de teste'};
          }
          return [
            song,
            record(11, '505', 'Outro'),
            record(12, '505', 'Arctic Monkeys', duration: 290),
          ];
        },
      );
      const track = SearchTrack(
        '505 - Arctic Monkeys (Tradução/Letra)',
        'Ghot_Stich',
        '',
        255000,
      );
      final result = await api.resolve(track, kind: TextKind.lyrics);
      expect(result.match?.id, '10');
      expect(calls.single.host, 'lrclib.net');
      expect(calls.single.queryParameters, {
        'track_name': '505',
        'artist_name': 'Arctic Monkeys',
      });
      final lyric = await api.fetch(result.match!, TextKind.lyrics);
      expect(lyric.status, 'found');
      expect(lyric.offlineAllowed, isFalse);
      final meaning = await api.resolve(track, kind: TextKind.meaning);
      expect(
        (await api.fetch(meaning.metadata, TextKind.meaning)).offlineAllowed,
        isTrue,
      );
      expect(calls.length, 2);
    },
  );

  test(
    'Asterisk encontra variante japonesa e não confirma uma duração divergente',
    () async {
      final api = DirectContentApi(
        request: (uri) async {
          final song = record(20, '＊～アスタリスク～', 'ORANGE RANGE');
          if (uri.path == '/api/get/20') return {...song, 'instrumental': true};
          return [song];
        },
      );
      final result = await api.resolve(
        const SearchTrack('*Asterisk', 'ORANGE RANGE - Topic', '', 120000),
      );
      expect(result.status, 'ambiguous');
      expect(result.match, isNull);
      final lyric = await api.fetch(result.candidates.single, TextKind.lyrics);
      expect(lyric.status, 'instrumental');
      expect(lyric.offlineAllowed, isFalse);
      final meaning = await api.fetch(result.metadata, TextKind.meaning);
      expect(meaning.kind, 'editorial_context');
    },
  );

  test('contexto ignora página incompatível e preserva o idioma do link encontrado', () async {
    final api = DirectContentApi(
      request: (uri) async {
        final english = uri.host == 'en.wikipedia.org';
        return {
          'query': {
            'pages': [
              {
                'pageid': 32,
                'title': english ? 'Night (Band X song)' : 'Night',
                'extract': english
                    ? 'Night is a single by Band X.'
                    : 'Night é uma música de outra pessoa.',
              },
            ],
          },
        };
      },
    );
    final resolution = await api.resolve(
      const SearchTrack('Night', 'Band X', '', null),
      kind: TextKind.meaning,
    );
    final result = await api.fetch(resolution.metadata, TextKind.meaning);
    expect(result.status, 'link_only');
    expect(result.language, 'en');
    expect(result.sourceUrl?.host, 'en.wikipedia.org');
    expect(result.text, isNull);
  });

  test(
    'provedor sem correspondência e resposta inválida são estados distintos',
    () async {
      const track = SearchTrack('Журавли', 'Artista de teste', '', 4000);
      final empty = DirectContentApi(request: (_) async => []);
      final broken = DirectContentApi(
        request: (_) async => {'unexpected': true},
      );
      expect((await empty.resolve(track)).status, 'not_found');
      await expectLater(broken.resolve(track), throwsFormatException);
    },
  );
}
