import 'package:flutter/material.dart';

import '../../shared/study.dart';

// --- SCREEN 2: SRS REVIEW ---
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<Vocab> _queue = _load();
  int _index = 0;
  int _done = 0;
  bool _flipped = false;
  bool _saving = false;

  List<Vocab> _load() => buildQueue(allWords, Store.srs.value, DateTime.now());

  Srs _current(Vocab v) => Store.srs.value[v.id] ?? Srs.fresh();

  Future<void> _grade(int q) async {
    if (_saving) return;
    final v = _queue[_index];
    setState(() => _saving = true);
    try {
      await Store.putSrs(v.id, nextSrs(_current(v), q, DateTime.now()));
      if (!mounted) return;
      setState(() {
        if (q == 0) {
          _queue = [..._queue, v]; // relearn again later in this session
        }
        _index++;
        _done++;
        _flipped = false;
      });
    } catch (error) {
      debugPrint('Saving review result failed: $error');
      if (mounted) {
        showAppToast(context, 'Không thể lưu kết quả ôn tập. Thử lại sau.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _grades = [
    ('Lại', Colors.red),
    ('Khó', Colors.orange),
    ('Tốt', Colors.green),
    ('Dễ', Colors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    final finished = _index >= _queue.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ôn Tập Ngắt Quãng')),
      body: finished ? _finishedView() : _cardView(_queue[_index]),
    );
  }

  Widget _finishedView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 96, color: Colors.green.shade600),
        const SizedBox(height: 16),
        Text(
          _done == 0
              ? 'Chưa có thẻ nào cần ôn!'
              : 'Xong rồi! Đã ôn $_done lượt 🎉',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quay lại sau để ôn các thẻ đến hạn.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại'),
          onPressed: () => setState(() {
            _queue = _load();
            _index = 0;
            _done = 0;
          }),
        ),
      ],
    ),
  );

  Widget _cardView(Vocab v) {
    final now = DateTime.now();
    final s = _current(v);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: _index / _queue.length,
                backgroundColor: Colors.grey.shade300,
              ),
              const SizedBox(height: 8),
              Text(
                'Còn ${_queue.length - _index} thẻ',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              FlipCard(
                flipped: _flipped,
                onTap: () => setState(() => _flipped = true),
                front: cardFront(context, v),
                back: cardBack(context, v),
              ),
              const SizedBox(height: 24),
              if (!_flipped)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _flipped = true),
                    child: const Text(
                      'Hiện đáp án',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    for (var q = 0; q < 4; q++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _grades[q].$2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _saving ? null : () => _grade(q),
                            child: Column(
                              children: [
                                Text(
                                  _grades[q].$1,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  fmtDuration(
                                    nextSrs(s, q, now).due.difference(now),
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
