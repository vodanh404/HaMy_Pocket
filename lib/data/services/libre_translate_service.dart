import 'dart:convert';

import 'package:http/http.dart' as http;

class LibreTranslateService {
  LibreTranslateService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? defaultEndpoint;

  static final instance = LibreTranslateService();
  static final defaultEndpoint = Uri.parse(
    'https://libretranslate.com/translate',
  );
  static const _maxRedirects = 3;

  final http.Client _client;
  final Uri _endpoint;

  Future<String> translate(String text) async {
    final query = text.trim();
    if (query.isEmpty) {
      throw const FormatException('Hãy nhập từ hoặc câu cần dịch.');
    }

    final containsChinese = RegExp(r'[\u3400-\u9fff]').hasMatch(query);
    final body = jsonEncode({
      'q': query,
      'source': 'auto',
      'target': containsChinese ? 'vi' : 'zh',
      'format': 'text',
    });
    final response = await _postFollowingRedirects(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _errorMessage(utf8.decode(response.bodyBytes));
      if (response.statusCode == 429) {
        throw StateError(
          'Máy chủ dịch đang giới hạn lượt truy cập. Thử lại sau.',
        );
      }
      if (response.statusCode == 403 || response.statusCode == 401) {
        throw StateError(
          'Máy chủ LibreTranslate yêu cầu API key hoặc không cho phép truy cập.',
        );
      }
      throw StateError(
        'LibreTranslate trả về HTTP ${response.statusCode}'
        '${detail.isEmpty ? '.' : ': $detail'}',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const FormatException('Máy chủ dịch trả về dữ liệu không hợp lệ.');
    }
    if (decoded is! Map || decoded['translatedText'] is! String) {
      throw const FormatException(
        'Phản hồi LibreTranslate không có bản dịch hợp lệ.',
      );
    }
    final result = (decoded['translatedText'] as String).trim();
    if (result.isEmpty) {
      throw const FormatException('LibreTranslate không trả về nội dung dịch.');
    }
    return result;
  }

  Future<http.Response> _postFollowingRedirects(String body) async {
    var uri = _endpoint;
    for (var redirects = 0; ; redirects++) {
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..body = body;
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 20));
      if (![301, 302, 303, 307, 308].contains(response.statusCode)) {
        return response;
      }
      if (redirects >= _maxRedirects) {
        throw StateError('Máy chủ LibreTranslate chuyển hướng quá nhiều lần.');
      }

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        throw StateError(
          'LibreTranslate trả về HTTP ${response.statusCode} nhưng không có '
          'địa chỉ chuyển hướng.',
        );
      }
      final redirectedUri = uri.resolve(location);
      if (redirectedUri.scheme != 'https' ||
          redirectedUri.origin != _endpoint.origin) {
        throw StateError(
          'LibreTranslate chuyển hướng sang địa chỉ HTTPS khác máy chủ. '
          'Hãy cập nhật endpoint dịch trong ứng dụng.',
        );
      }
      uri = redirectedUri;
    }
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return (decoded['error'] as String).trim();
      }
    } on FormatException {
      return '';
    }
    return '';
  }

  void close() {
    _client.close();
  }
}
