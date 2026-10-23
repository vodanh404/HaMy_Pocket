import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/data/services/news_feed_service.dart';
import 'package:hamy_poket/main.dart' as app;
import 'package:hamy_poket/shared/news_vocabulary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses RSS items and their original article links', () {
    const rss = '''
      <rss version="2.0"><channel>
        <item>
          <title>环境新闻</title>
          <description><![CDATA[保护环境需要大家一起努力。]]></description>
          <link>https://example.com/news/1</link>
          <pubDate>Fri, 23 Oct 2026 17:18:43 GMT</pubDate>
        </item>
        <item><title>Incomplete</title></item>
      </channel></rss>
    ''';

    final articles = NewsFeedService.parseRss(
      rss,
      sourceId: 'test',
      sourceName: '测试来源',
    );

    expect(articles, hasLength(1));
    expect(articles.single.title, '环境新闻');
    expect(articles.single.description, '保护环境需要大家一起努力。');
    expect(articles.single.url, 'https://example.com/news/1');
  });

  test('extracts only Zaobao article links from homepage HTML', () {
    const homepage = '''
      <html><body>
        <a href="/news/singapore/story1">新加坡新闻标题</a>
        <a href="/news/singapore/story1">新加坡新闻标题</a>
        <a href="/about">关于我们</a>
      </body></html>
    ''';

    final articles = NewsFeedService.parseZaobaoHomepage(homepage);

    expect(articles, hasLength(1));
    expect(articles.single.title, '新加坡新闻标题');
    expect(
      articles.single.url,
      'https://www.zaobao.com.sg/news/singapore/story1',
    );
  });

  test('finds dictionary translations in source headlines', () async {
    await app.loadDictionary();

    final matches = findNewsWords('保护环境需要大家一起努力');

    expect(matches, isNotEmpty);
    expect(matches.any((match) => match.vocab.meaning.isNotEmpty), isTrue);
    expect(matches.every((match) => match.end > match.start), isTrue);
  });
}
