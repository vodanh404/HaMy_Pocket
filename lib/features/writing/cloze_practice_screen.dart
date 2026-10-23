import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/news_article.dart';
import '../../data/services/news_feed_service.dart';
import '../dictionary/translation_screen.dart';
import '../../domain/models/vocab.dart';
import '../../services/storage/storage_service.dart';
import '../../shared/news_vocabulary.dart';

class _ClozeQuestion {
  const _ClozeQuestion({
    required this.article,
    required this.text,
    required this.answer,
    required this.vocab,
  });

  final NewsArticle article;
  final String text;
  final String answer;
  final Vocab vocab;

  String get prompt => text.replaceFirst(answer, '____');
}

class ClozePracticeScreen extends StatefulWidget {
  const ClozePracticeScreen({super.key});

  @override
  State<ClozePracticeScreen> createState() => _ClozePracticeScreenState();
}

class _ClozePracticeScreenState extends State<ClozePracticeScreen> {
  final _answerController = TextEditingController();
  late Future<List<NewsSourceFeed>> _feeds;
  List<_ClozeQuestion> _questions = [];
  int _index = 0;
  bool _checked = false;
  bool _correct = false;

  @override
  void initState() {
    super.initState();
    _feeds = _loadQuestions();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<List<NewsSourceFeed>> _loadQuestions() async {
    final feeds = await NewsFeedService.instance.loadFeeds();
    _questions = [
      for (final feed in feeds)
        for (final article in feed.articles.take(20))
          if (_questionFor(article) case final question?) question,
    ];
    _index = 0;
    _resetAnswer();
    return feeds;
  }

  _ClozeQuestion? _questionFor(NewsArticle article) {
    final titleMatches = findNewsWords(article.title);
    final text = titleMatches.any((match) => match.text.length >= 2)
        ? article.title
        : article.description;
    final matches =
        findNewsWords(text)
            .where((match) => match.text.length >= 2)
            .toList()
          ..sort(
            (left, right) => right.text.length.compareTo(left.text.length),
          );
    if (matches.isEmpty) return null;
    final target = matches.first;
    return _ClozeQuestion(
      article: article,
      text: text,
      answer: target.text,
      vocab: target.vocab,
    );
  }

  void _resetAnswer() {
    _answerController.clear();
    _checked = false;
    _correct = false;
  }

  void _checkAnswer() {
    if (_checked || _answerController.text.trim().isEmpty) return;
    setState(() {
      _checked = true;
      _correct = _answerController.text.trim() == _questions[_index].answer;
    });
  }

  void _nextQuestion() {
    if (_index + 1 >= _questions.length) {
      setState(() {
        _index = 0;
        _resetAnswer();
      });
      return;
    }
    setState(() {
      _index++;
      _resetAnswer();
    });
  }

  Future<void> _openArticle(NewsArticle article) async {
    try {
      final opened = await launchUrl(
        Uri.parse(article.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _showMessage('Không mở được liên kết bài báo.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Không mở được bài báo: $error');
    }
  }

  Future<void> _saveWord(_ClozeQuestion question) async {
    try {
      await Store.togglePersonal(question.vocab);
      if (mounted) _showMessage('Đã lưu “${question.answer}” vào từ điển.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Không thể lưu từ: $error');
    } on StateError catch (error) {
      if (mounted) _showMessage('Không thể lưu từ: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Điền từ từ bản tin'),
      actions: [
        IconButton(
          tooltip: 'Tải bài mới',
          onPressed: () => setState(() => _feeds = _loadQuestions()),
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
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (_questions.isEmpty) {
          final errors = (snapshot.data ?? const <NewsSourceFeed>[])
              .where((feed) => feed.error != null)
              .map((feed) => '${feed.name}: ${feed.error}')
              .join('\n');
          return _error(
            errors.isEmpty
                ? 'Chưa tìm được từ vựng phù hợp trong tiêu đề mới.'
                : errors,
          );
        }
        return _questionView(_questions[_index]);
      },
    ),
  );

  Widget _error(String message) => Center(
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
            onPressed: () => setState(() => _feeds = _loadQuestions()),
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại'),
          ),
        ],
      ),
    ),
  );

  Widget _questionView(_ClozeQuestion question) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      LinearProgressIndicator(value: (_index + 1) / _questions.length),
      const SizedBox(height: 8),
      Text(
        'Câu ${_index + 1}/${_questions.length} · ${question.article.sourceName}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 24),
      Text(
        question.article.title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Điền từ còn thiếu trong tiêu đề:',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _answerController,
        enabled: !_checked,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _checkAnswer(),
        decoration: const InputDecoration(
          labelText: 'Từ tiếng Trung',
          hintText: 'Nhập từ còn thiếu',
          prefixIcon: Icon(Icons.edit),
          border: OutlineInputBorder(),
        ),
      ),
      if (_checked) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _correct ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                _correct ? 'Chính xác!' : 'Đáp án: ${question.answer}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('${question.vocab.pinyin} · ${question.vocab.meaning}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: Store.isPersonal(question.vocab)
                    ? null
                    : () => _saveWord(question),
                icon: const Icon(Icons.bookmark_add),
                label: Text(
                  Store.isPersonal(question.vocab)
                      ? 'Đã lưu vào từ điển'
                      : 'Lưu từ vào từ điển',
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _checked
              ? _nextQuestion
              : _answerController.text.trim().isEmpty
              ? null
              : _checkAnswer,
          icon: Icon(_checked ? Icons.arrow_forward : Icons.check),
          label: Text(_checked ? 'Câu tiếp theo' : 'Kiểm tra'),
        ),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => _openArticle(question.article),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Mở bài gốc'),
      ),
      TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                TranslationScreen(initialText: question.article.title),
          ),
        ),
        icon: const Icon(Icons.translate),
        label: const Text('Dịch tiêu đề'),
      ),
    ],
  );
}
