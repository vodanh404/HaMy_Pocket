import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/data/services/libre_translate_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses the official LibreTranslate endpoint by default', () {
    expect(
      LibreTranslateService.defaultEndpoint.toString(),
      'https://libretranslate.com/translate',
    );
  });

  test(
    'translates Chinese text into Vietnamese and detects the response',
    () async {
      Uri? requestedUri;
      Map<String, dynamic>? requestedBody;
      final service = LibreTranslateService(
        endpoint: Uri.parse('https://translate.example/translate'),
        client: MockClient((request) async {
          requestedUri = request.url;
          requestedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response.bytes(
            utf8.encode(jsonEncode({'translatedText': 'Bảo vệ môi trường'})),
            200,
          );
        }),
      );

      final result = await service.translate('保护环境');

      expect(result, 'Bảo vệ môi trường');
      expect(requestedUri!.host, 'translate.example');
      expect(requestedBody, containsPair('source', 'auto'));
      expect(requestedBody, containsPair('target', 'vi'));
    },
  );

  test('translates Vietnamese text into Chinese', () async {
    Map<String, dynamic>? requestedBody;
    final service = LibreTranslateService(
      client: MockClient((request) async {
        requestedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'translatedText': '你好'})),
          200,
        );
      }),
    );

    expect(await service.translate('Xin chào'), '你好');
    expect(requestedBody, containsPair('target', 'zh'));
  });

  test('retries a same-origin 301 as a POST to its target', () async {
    final requests = <http.BaseRequest>[];
    final service = LibreTranslateService(
      endpoint: Uri.parse('https://translate.example/translate'),
      client: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            '',
            301,
            headers: const {'location': '/api/translate'},
          );
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({'translatedText': 'Xin chào'})),
          200,
        );
      }),
    );

    expect(await service.translate('你好'), 'Xin chào');
    expect(requests, hasLength(2));
    expect(requests[0].method, 'POST');
    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, '/api/translate');
  });

  test('rejects insecure or cross-origin redirects', () async {
    final service = LibreTranslateService(
      endpoint: Uri.parse('https://translate.example/translate'),
      client: MockClient(
        (_) async => http.Response(
          '',
          301,
          headers: const {'location': 'https://other.example/translate'},
        ),
      ),
    );

    await expectLater(
      service.translate('你好'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('địa chỉ HTTPS khác máy chủ'),
        ),
      ),
    );
  });

  test('rejects empty queries and reports endpoint errors', () async {
    final service = LibreTranslateService(
      client: MockClient(
        (_) async => http.Response('{"error":"Unavailable"}', 503),
      ),
    );

    await expectLater(service.translate('  '), throwsFormatException);
    await expectLater(service.translate('你好'), throwsA(isA<StateError>()));
  });
}
