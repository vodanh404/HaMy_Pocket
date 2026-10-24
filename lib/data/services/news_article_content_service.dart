import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class NewsArticleContentService {
  NewsArticleContentService({http.Client? client})
    : _client = client ?? http.Client();

  static final instance = NewsArticleContentService();
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;

  Future<String> load(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const FormatException('Đường dẫn bài báo không hợp lệ.');
    }

    final response = await _client
        .get(
          uri,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Nguồn báo trả về HTTP ${response.statusCode}.');
    }

    return parseHtml(response.body);
  }

  static String parseHtml(String page) {
    final document = html_parser.parse(page);
    document
        .querySelectorAll(
          'script, style, nav, header, footer, aside, noscript, form, '
          'iframe, svg, button, [aria-hidden="true"]',
        )
        .forEach((element) => element.remove());

    final content = _contentElement(document);
    final paragraphs = <String>[];
    final seen = <String>{};
    for (final element in content.querySelectorAll(
      'h1, h2, h3, p, blockquote',
    )) {
      final text = _normalize(element.text);
      final isHeading =
          element.localName == 'h1' ||
          element.localName == 'h2' ||
          element.localName == 'h3';
      if (text.isEmpty || (!isHeading && text.length < 12) || !seen.add(text)) {
        continue;
      }
      paragraphs.add(text);
    }
    if (paragraphs.isNotEmpty) return paragraphs.join('\n\n');

    final text = _normalize(content.text);
    if (text.isEmpty) {
      throw const FormatException('Không tìm thấy nội dung bài báo.');
    }
    return text;
  }

  static html_dom.Element _contentElement(html_dom.Document document) {
    for (final selector in ['[itemprop="articleBody"]', 'article', 'main']) {
      final candidates = document.querySelectorAll(selector);
      if (candidates.isNotEmpty) {
        candidates.sort(
          (left, right) =>
              _normalize(right.text).length
                  .compareTo(_normalize(left.text).length),
        );
        return candidates.first;
      }
    }
    final body = document.body;
    if (body == null) {
      throw const FormatException('Trang báo không có nội dung để đọc.');
    }
    return body;
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
