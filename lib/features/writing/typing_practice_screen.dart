import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'cloze_practice_screen.dart';
import '../../shared/study.dart';

// --- SCREEN 4: CHINESE TYPING PRACTICE ---
class TypingPracticeScreen extends StatefulWidget {
  const TypingPracticeScreen({super.key});

  @override
  State<TypingPracticeScreen> createState() => _TypingPracticeScreenState();
}

class _TypingPracticeScreenState extends State<TypingPracticeScreen> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  int _level = -1;
  int _sessionSize = AppConstants.typingSessionSize;
  late List<Vocab> _queue;
  int _index = 0;
  int _correct = 0;
  bool _checked = false;
  bool _lastCorrect = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _queue = _newQueue(_level);
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  List<Vocab> _newQueue(int level) {
    final seen = <String>{};
    final pool =
        allWords
            .where((word) => inScope(word, level) && seen.add(word.id))
            .toList()
          ..shuffle();
    return _sessionSize == 0 ? pool : pool.take(_sessionSize).toList();
  }

  void _restart({int? level, int? sessionSize}) {
    setState(() {
      _level = level ?? _level;
      _sessionSize = sessionSize ?? _sessionSize;
      _queue = _newQueue(_level);
      _index = 0;
      _correct = 0;
      _checked = false;
      _lastCorrect = false;
      _finished = false;
      _answerController.clear();
    });
    _answerFocus.requestFocus();
  }

  void _checkAnswer() {
    if (_checked || _answerController.text.trim().isEmpty) return;
    final isCorrect = matchesTypingAnswer(
      _queue[_index],
      _answerController.text,
    );
    setState(() {
      _checked = true;
      _lastCorrect = isCorrect;
      if (isCorrect) _correct++;
    });
    _answerFocus.unfocus();
  }

  void _nextQuestion() {
    if (_index + 1 == _queue.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _checked = false;
      _answerController.clear();
    });
    _answerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _finished;
    final word = _queue.isEmpty ? null : _queue[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện gõ tiếng Trung'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ClozePracticeScreen(),
              ),
            ),
            icon: const Icon(Icons.edit_note),
            label: const Text('Điền từ'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _level,
            decoration: const InputDecoration(
              labelText: 'Chọn cấp độ HSK',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final (level, label) in filterItems)
                DropdownMenuItem(value: level, child: Text(label)),
            ],
            onChanged: (level) {
              if (level != null) _restart(level: level);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _sessionSize,
            decoration: const InputDecoration(
              labelText: 'Số từ trong lượt luyện',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10 từ')),
              DropdownMenuItem(value: 25, child: Text('25 từ')),
              DropdownMenuItem(value: 0, child: Text('Toàn bộ từ phù hợp')),
            ],
            onChanged: (size) {
              if (size != null) _restart(sessionSize: size);
            },
          ),
          const SizedBox(height: 24),
          if (word == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có từ trong cấp độ này để luyện gõ.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (finished)
            _finishedView()
          else ...[
            LinearProgressIndicator(
              value: (_index + 1) / _queue.length,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(
              'Câu ${_index + 1}/${_queue.length}  ·  Đúng $_correct',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Gõ từ tiếng Trung có nghĩa là:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  word.meaning.split(';').first.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _answerController,
              focusNode: _answerFocus,
              autofocus: true,
              enabled: !_checked,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _checkAnswer(),
              decoration: const InputDecoration(
                labelText: 'Chữ Hán',
                hintText: 'Nhập chữ Hán bằng bàn phím Trung',
                prefixIcon: Icon(Icons.keyboard),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn bàn phím 中文/Pinyin trong cài đặt thiết bị để nhập chữ Hán.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (_checked) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastCorrect
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _lastCorrect ? 'Chính xác!' : 'Chưa chính xác',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _lastCorrect
                            ? Colors.green.shade800
                            : Colors.deepOrange.shade800,
                      ),
                    ),
                    if (!_lastCorrect) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${word.hanzi}  ·  ${word.pinyin}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _checked
                    ? _nextQuestion
                    : _answerController.text.trim().isEmpty
                    ? null
                    : _checkAnswer,
                icon: Icon(_checked ? Icons.arrow_forward : Icons.check),
                label: Text(_checked ? 'Từ tiếp theo' : 'Kiểm tra'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _finishedView() => Center(
    child: Column(
      children: [
        Icon(Icons.emoji_events, size: 72, color: Colors.amber.shade700),
        const SizedBox(height: 12),
        const Text(
          'Hoàn thành lượt luyện!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Bạn gõ đúng $_correct/${_queue.length} từ.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.refresh),
          label: const Text('Luyện lại'),
        ),
      ],
    ),
  );
}
