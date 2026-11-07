import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/health_api.dart';

void main() {
  test(
    'aceita contrato do Django e rejeita JSON estranho e erro HTTP',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var mode = 0;
      server.listen((request) async {
        expect(request.uri.path, '/api/v1/health/');
        request.response.statusCode = mode == 2 ? 503 : 200;
        request.response.write(
          mode == 0
              ? '{"status":"ok","service":"musicapp","api_version":"v1"}'
              : '{"status":"ok","service":"other"}',
        );
        await request.response.close();
      });
      final api = HealthApi(baseUrl: 'http://127.0.0.1:${server.port}/');
      expect(await api.check(), ConnectionStatus.online);
      mode = 1;
      expect(await api.check(), ConnectionStatus.error);
      mode = 2;
      expect(await api.check(), ConnectionStatus.error);
      await server.close(force: true);
      expect(await api.check(), ConnectionStatus.offline);
    },
  );
}
