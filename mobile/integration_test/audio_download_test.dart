import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const fixture = String.fromEnvironment('FOLOGNE_AUDIO_FIXTURE_URL');
  const channel = MethodChannel('musicapp/audioDownloads');

  testWidgets('converte WAV em MP3, publica e evita arquivo duplicado', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(await channel.invokeMethod<bool>('available'), isTrue);
      final args = {'url': fixture};
      final canceled = expectLater(
        channel.invokeMethod<Object?>('startFixture', args),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'canceled'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await channel.invokeMethod<bool>('cancel'), isTrue);
      await canceled;
      final track = await channel.invokeMapMethod<String, String>(
        'startFixture',
        args,
      );
      expect(track?['title'], isNotEmpty);
      expect(
        track?['trackId'],
        startsWith('content://media/external/audio/media/'),
      );
      await expectLater(
        channel.invokeMethod<Object?>('startFixture', args),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'duplicate'),
        ),
      );
    });
  }, skip: fixture.isEmpty);
}
