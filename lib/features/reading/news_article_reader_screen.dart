import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/news_article.dart';
import '../../data/services/news_article_content_service.dart';
import '../../data/services/opus_zh_vi_translation_service.dart';

class NewsArticleReaderScreen extends StatefulWidget {
  const NewsArticleReaderScreen({super.key, required this.article});

  final NewsArticle article;

  @override
  State<NewsArticleReaderScreen> createState() =>
      _NewsArticleReaderScreenState();
}

class _NewsArticleReaderScreenState extends State<NewsArticleReaderScreen> {
  late Future<String> _content;
  String? _selectedText;
  String? _translation;
  String? _translationError;
  bool _translating = false;
  int _translationRequest = 0;

  @override
  void initState() {
    super.initState();
    _content = NewsArticleContentService.instance.load(widget.article.url);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _selectionChanged(
    String content,
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    _translationRequest++;
    if (selection.isCollapsed ||
        selection.start < 0 ||
        selection.end > content.length) {
      setState(() {
        _selectedText = null;
        _translation = null;
        _translationError = null;
      });
      return;
    }

    final selected = content.substring(selection.start, selection.end).trim();
    if (selected.isEmpty) {
      setState(() {
        _selectedText = null;
        _translation = null;
        _translationError = null;
      });
      return;
    }
    setState(() {
      _selectedText = selected;
      _translation = null;
      _translationError = null;
    });
  }

  Future<void> _translateSelection() async {
    final text = _selectedText;
    if (_translating ||
        text == null ||
        !OpusZhViTranslationService.containsChinese(text)) {
      return;
    }
    final request = ++_translationRequest;
    setState(() {
      _translation = null;
      _translationError = null;
      _translating = true;
    });
    try {
      final result = await OpusZhViTranslationService.instance.translate(text);
      if (!mounted) return;
      setState(() {
        if (request == _translationRequest) _translation = result;
        _translating = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        if (request == _translationRequest) {
          _translationError = error is StateError
              ? error.message
              : error.toString();
        }
        _translating = false;
      });
    }
  }

  Future<void> _openOriginal() async {
    try {
      final opened = await launchUrl(
        Uri.parse(widget.article.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không mở được bài báo trên trang nguồn.'),
          ),
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được bài báo: $error')));
    }
  }

  Future<void> _retry() async {
    setState(() {
      _content = NewsArticleContentService.instance.load(widget.article.url);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.article.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: 'Mở bài trên trang báo',
          onPressed: _openOriginal,
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: FutureBuilder<String>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _loadError(snapshot.error.toString());
        }

        final content = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final article = _articlePane(content);
            if (constraints.maxWidth < 900) return article;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: article),
                const SizedBox(width: 16),
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 20, 32),
                    child: _translationCard(),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );

  Widget _articlePane(String content) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    children: [
      Text(
        '${widget.article.sourceName}'
        '${widget.article.publishedAt == null ? '' : ' · ${_formatDate(widget.article.publishedAt!)}'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      Text(
        MediaQuery.sizeOf(context).width >= 900
            ? 'Bôi đen đoạn tiếng Trung để xem bản dịch ở bên phải.'
            : 'Bôi đen đoạn tiếng Trung để xem bản dịch bên dưới.',
        style: const TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 16),
      SelectableText(
        content,
        onSelectionChanged: (selection, cause) =>
            _selectionChanged(content, selection, cause),
        style: const TextStyle(fontSize: 17, height: 1.75),
      ),
      if (_selectedText != null && MediaQuery.sizeOf(context).width < 900) ...[
        const SizedBox(height: 20),
        _translationCard(),
      ],
    ],
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
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử tải lại'),
              ),
              FilledButton.icon(
                onPressed: _openOriginal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Mở trang báo'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _translationCard() => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đoạn đã chọn', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (_selectedText == null)
            const Text('Bôi đen một đoạn tiếng Trung trong bài báo.')
          else
            SelectableText(_selectedText!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _translating ||
                      _selectedText == null ||
                      !OpusZhViTranslationService.containsChinese(
                        _selectedText!,
                      )
                  ? null
                  : _translateSelection,
              icon: _translating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.translate),
              label: Text(_translating ? 'Đang dịch…' : 'Dịch đoạn chọn'),
            ),
          ),
          if (_selectedText != null &&
              !OpusZhViTranslationService.containsChinese(_selectedText!))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Đoạn chọn chưa có chữ tiếng Trung.'),
            ),
          const Divider(height: 24),
          Text('Bản dịch', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (_translating)
            const LinearProgressIndicator()
          else if (_translationError != null)
            Text(
              _translationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_translation != null)
            SelectableText(_translation!),
        ],
      ),
    ),
  );

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
