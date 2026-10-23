import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/news_article.dart';

class NewsFeedService {
  NewsFeedService._();

  static final instance = NewsFeedService._();
  static const _timeout = Duration(seconds: 15);

  static const _sources = [
    (
      id: 'zaobao',
      name: '联合早报',
      homepage: 'https://www.zaobao.com.sg',
      feedUrl: 'https://www.zaobao.com.sg',
    ),
    (
      id: 'bbc',
      name: 'BBC 中文',
      homepage: 'https://www.bbc.com/zhongwen',
      feedUrl: 'https://feeds.bbci.co.uk/zhongwen/simp/rss.xml',
    ),
    (
      id: 'dw',
      name: 'DW 中文',
      homepage: 'https://www.dw.com/zh',
      feedUrl: 'https://rss.dw.com/xml/rss-chi-all',
    ),
  ];

  Future<List<NewsSourceFeed>> loadFeeds() => Future.wait(
    _sources.map((source) async {
      try {
        final response = await http
            .get(Uri.parse(source.feedUrl))
            .timeout(_timeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw FormatException('服务器返回 HTTP ${response.statusCode}.');
        }
        final articles = source.id == 'zaobao'
            ? parseZaobaoHomepage(response.body)
            : parseRss(
                response.body,
                sourceId: source.id,
                sourceName: source.name,
              );
        return NewsSourceFeed(
          id: source.id,
          name: source.name,
          homepage: source.homepage,
          articles: articles,
        );
      } on http.ClientException catch (error) {
        return _failed(source, error.message);
      } on FormatException catch (error) {
        return _failed(source, error.message);
      } on XmlException catch (error) {
        return _failed(source, error.message);
      } on Exception catch (error) {
        return _failed(source, error.toString());
      }
    }),
  );

  static NewsSourceFeed _failed(
    ({String id, String name, String homepage, String feedUrl}) source,
    String message,
  ) => NewsSourceFeed(
    id: source.id,
    name: source.name,
    homepage: source.homepage,
    articles: const [],
    error: message,
  );

  static List<NewsArticle> parseRss(
    String xml, {
    required String sourceId,
    required String sourceName,
  }) {
    final document = XmlDocument.parse(xml);
    final articles = <NewsArticle>[];
    for (final item in document.findAllElements('item')) {
      final title = item.getElement('title')?.innerText.trim() ?? '';
      final url = item.getElement('link')?.innerText.trim() ?? '';
      if (title.isEmpty || Uri.tryParse(url)?.hasScheme != true) continue;
      final description =
          item.getElement('description')?.innerText.trim() ?? '';
      final dateText = item.getElement('pubDate')?.innerText.trim();
      articles.add(
        NewsArticle(
          sourceId: sourceId,
          sourceName: sourceName,
          title: title,
          description: description,
          url: url,
          publishedAt: dateText == null ? null : _parseDate(dateText),
        ),
      );
    }
    return articles;
  }

  static List<NewsArticle> parseZaobaoHomepage(String page) {
    final document = html_parser.parse(page);
    final articles = <NewsArticle>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null ||
          !RegExp(r'^/(news|finance|lifestyle|sports|entertainment|opinion)/')
              .hasMatch(href)) {
        continue;
      }
      final title = anchor.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.length < 4 ||
          title.length > 120 ||
          !RegExp(r'[\u3400-\u9fff]').hasMatch(title)) {
        continue;
      }
      final uri = Uri.parse('https://www.zaobao.com.sg').resolve(href);
      if (!seen.add(uri.path)) continue;
      articles.add(
        NewsArticle(
          sourceId: 'zaobao',
          sourceName: '联合早报',
          title: title,
          description: _zaobaoTeaser(anchor, title),
          url: uri.toString(),
        ),
      );
      if (articles.length == 30) break;
    }
    return articles;
  }

  static String _zaobaoTeaser(html_dom.Element anchor, String title) {
    if (anchor.parent?.querySelectorAll('a').length != 1) return '';
    final parentText = anchor.parent?.text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(title, '')
        .trim();
    if (parentText == null ||
        parentText.length < 20 ||
        !RegExp(r'[\u3400-\u9fff]').hasMatch(parentText)) {
      return '';
    }
    return parentText.length > 240
        ? '${parentText.substring(0, 240)}…'
        : parentText;
  }

  static DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }
}
