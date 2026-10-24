import 'package:flutter/material.dart';

import '../../data/services/opus_zh_vi_translation_service.dart';
import '../../domain/models/vocab.dart';
import '../../services/storage/storage_service.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key, this.initialText = ''});

  final String initialText;

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  late final TextEditingController _controller;
  String? _translation;
  String? _error;
  bool _translating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    setState(() {
      _translating = true;
      _error = null;
      _translation = null;
    });
    try {
      final result = await OpusZhViTranslationService.instance.translate(
        _controller.text,
      );
      if (mounted) setState(() => _translation = result);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _saveTranslation() async {
    final query = _controller.text.trim();
    final translation = _translation;
    if (query.isEmpty || translation == null) return;

    final word = Vocab(
      id: 'translate_${DateTime.now().microsecondsSinceEpoch}',
      hanzi: query,
      pinyin: '—',
      meaning: translation,
      level: 0,
      custom: true,
    );
    final alreadySaved = Store.personalWords.any(
      (saved) => saved.hanzi == word.hanzi && saved.meaning == word.meaning,
    );
    if (alreadySaved) {
      _showMessage('Bản dịch này đã có trong từ điển cá nhân.');
      return;
    }

    setState(() => _saving = true);
    try {
      await Store.upsert(word);
      if (mounted) _showMessage('Đã lưu vào từ điển cá nhân.');
    } on StateError catch (error) {
      if (mounted) _showMessage('Không thể lưu bản dịch: ${error.message}');
    } on Exception catch (error) {
      if (mounted) _showMessage('Không thể lưu bản dịch: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dịch bằng Opus Trung–Việt')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Dịch tiếng Trung sang tiếng Việt ngoại tuyến bằng Opus zh-vi.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Từ hoặc câu cần dịch',
            hintText: 'Nhập từ hoặc câu tiếng Trung',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _translating ? null : _translate,
          icon: _translating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.translate),
          label: Text(_translating ? 'Đang dịch…' : 'Dịch'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_translation != null) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bản dịch',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _translation!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _saveTranslation,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Lưu vào từ điển cá nhân'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
