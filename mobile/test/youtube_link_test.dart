import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/youtube_link.dart';

void main() {
  const id = 'AbCde1234_-';
  const canonical = 'https://www.youtube.com/watch?v=$id';

  test('normaliza links de vídeo compartilhados com texto', () {
    for (final text in [
      'Confira: https://youtu.be/$id?si=example',
      'Veja ($canonical&t=42s).',
      'https://m.youtube.com/shorts/$id?feature=share',
      'https://music.youtube.com/watch?v=$id',
      'https://example.com antes de https://youtu.be/$id',
    ]) {
      expect(youtubeVideoLink(text), Uri.parse(canonical), reason: text);
    }
  });

  test('rejeita texto, endereços de terceiros e links sem vídeo válido', () {
    for (final text in [
      'Um texto sem link',
      'https://youtube.com.example.org/watch?v=$id',
      'https://example.org@youtube.com/watch?v=$id',
      'https://youtube.com:1234/watch?v=$id',
      'https://www.youtube.com/playlist?list=$id',
      'https://www.youtube.com/watch?v=$id&v=$id',
      'https://youtu.be/curto',
      'https://youtu.be/$id/extra',
      'https://youtu.be/%FF',
    ]) {
      expect(youtubeVideoLink(text), isNull, reason: text);
    }
  });
}
