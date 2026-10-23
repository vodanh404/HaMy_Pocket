class NewsArticle {
  const NewsArticle({
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.url,
    this.description = '',
    this.publishedAt,
  });

  final String sourceId;
  final String sourceName;
  final String title;
  final String description;
  final String url;
  final DateTime? publishedAt;
}

class NewsSourceFeed {
  const NewsSourceFeed({
    required this.id,
    required this.name,
    required this.homepage,
    required this.articles,
    this.error,
  });

  final String id;
  final String name;
  final String homepage;
  final List<NewsArticle> articles;
  final String? error;
}
