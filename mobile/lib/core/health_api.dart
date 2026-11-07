import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_info.dart';

enum ConnectionStatus { idle, loading, online, offline, error }

class HealthApi {
  HealthApi({String? baseUrl}) : baseUrl = baseUrl ?? defaultApiBaseUrl;

  final String baseUrl;

  Future<ConnectionStatus> check() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1/health/',
      );
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != 200) return ConnectionStatus.error;
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 6));
      final data = jsonDecode(body);
      return data is Map &&
              data['status'] == 'ok' &&
              data['service'] == 'musicapp' &&
              data['api_version'] == 'v1'
          ? ConnectionStatus.online
          : ConnectionStatus.error;
    } on SocketException {
      return ConnectionStatus.offline;
    } on TimeoutException {
      return ConnectionStatus.offline;
    } catch (_) {
      return ConnectionStatus.error;
    } finally {
      client.close(force: true);
    }
  }
}
