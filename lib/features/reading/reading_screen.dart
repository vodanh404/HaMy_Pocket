import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/news_article.dart';
import '../../data/services/news_feed_service.dart';
import 'news_article_reader_screen.dart';
import '../../shared/study_material_screen.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late Future<List<NewsSourceFeed>> _feeds;

  @override
  void initState() {
    super.initState();
    _feeds = NewsFeedService.instance.loadFeeds();
  }

  Future<void> _refresh() async {
    final feeds = NewsFeedService.instance.loadFeeds();
    setState(() => _feeds = feeds);
    await feeds;
  }

  Future<void> _openArticle(NewsArticle article) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NewsArticleReaderScreen(article: article),
      ),
    );
  }

  Future<void> _openSource(NewsSourceFeed feed) async {
    await _openUrl(feed.homepage);
  }

  Future<void> _openUrl(String value) async {
    try {
      final opened = await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showMessage('Không mở được liên kết bài báo.');
      }
    } on Exception catch (error) {
      if (mounted) _showMessage('Không mở được bài báo: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Đọc báo tiếng Trung'),
      actions: [
        IconButton(
          tooltip: 'Tài liệu & ngữ pháp',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const StudyMaterialScreen(
                title: 'Tài liệu & ngữ pháp',
                materialTypes: {'pdf', 'image'},
              ),
            ),
          ),
          icon: const Icon(Icons.folder_open),
        ),
        IconButton(
          tooltip: 'Tải tin mới',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<NewsSourceFeed>>(
      future: _feeds,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _loadError(snapshot.error.toString());
        }
        final feeds = snapshot.data ?? const <NewsSourceFeed>[];
        if (feeds.every((feed) => feed.articles.isEmpty)) {
          return _loadError(
            feeds
                .map(
                  (feed) => '${feed.name}: ${feed.error ?? 'không có tin mới'}',
                )
                .join('\n'),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text(
                'Chọn một tiêu đề để đọc bài báo và bôi đen đoạn tiếng Trung để dịch.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              for (final feed in feeds) ...[
                _sourceHeading(feed),
                if (feed.error != null)
                  _sourceError(feed)
                else if (feed.articles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Không tìm thấy bài đọc.'),
                  )
                else
                  for (final article in feed.articles) _articleCard(article),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _loadError(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  Widget _sourceHeading(NewsSourceFeed feed) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(feed.name, style: Theme.of(context).textTheme.titleLarge),
        ),
        Text(
          feed.id == 'zaobao' ? 'Trang chủ' : 'RSS',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );

  Widget _sourceError(NewsSourceFeed feed) => Card(
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: const Text('Không tải được nguồn tin'),
      subtitle: Text(feed.error!),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Mở trang nguồn',
            onPressed: () => _openSource(feed),
            icon: const Icon(Icons.open_in_new),
          ),
          IconButton(
            tooltip: 'Thử lại',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    ),
  );

  Widget _articleCard(NewsArticle article) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      title: Text(
        article.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: article.publishedAt == null
          ? null
          : Text(_formatDate(article.publishedAt!)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openArticle(article),
    ),
  );

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
