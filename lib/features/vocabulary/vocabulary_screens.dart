import 'package:flutter/material.dart';

import '../../shared/study.dart';

// --- WORD LIST (one HSK level, or the user's own words) ---
class WordListScreen extends StatelessWidget {
  final String title;
  final int level; // 0 = user's own words
  const WordListScreen({super.key, required this.title, required this.level});

  Widget _legend() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final (c, t) in [
        (Colors.grey, 'Mới'),
        (Colors.orange, 'Đang học'),
        (Colors.green, 'Đã thuộc'),
      ]) ...[
        Icon(Icons.circle, size: 10, color: c),
        const SizedBox(width: 4),
        Text(t, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(width: 16),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('Thêm từ'),
      onPressed: () => showWordForm(context, level: level),
    ),
    body: AnimatedBuilder(
      animation: storeChanges,
      builder: (context, _) {
        final words = level == 0
            ? Store.personalWords
            : allWords.where((v) => inScope(v, level)).toList();
        if (words.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Chưa có từ nào.\nNhấn “Thêm từ” hoặc dùng nút + để lưu từ trong từ điển.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: words.length + 4,
          itemBuilder: (context, index) => switch (index) {
            0 => FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.style),
              label: Text(
                'Học flashcard (${words.length} từ)',
                style: const TextStyle(fontSize: 16),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlashcardScreen(title: title, words: words),
                ),
              ),
            ),
            1 || 3 => const SizedBox(height: 12),
            2 => _legend(),
            _ => wordTile(context, words[index - 4]),
          },
        );
      },
    ),
  );
}

// --- FLASHCARD BROWSER (free study; swipe or use arrows) ---
class FlashcardScreen extends StatefulWidget {
  final String title;
  final List<Vocab> words;
  const FlashcardScreen({super.key, required this.title, required this.words});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int _index = 0;
  bool _flipped = false;

  void _go(int delta) {
    final n = _index + delta;
    if (n < 0 || n >= widget.words.length) return;
    setState(() {
      _index = n;
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.words;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: GestureDetector(
              onHorizontalDragEnd: (e) {
                final v = e.primaryVelocity ?? 0;
                if (v.abs() > 300) _go(v < 0 ? 1 : -1);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: (_index + 1) / list.length,
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_index + 1} / ${list.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FlipCard(
                    flipped: _flipped,
                    onTap: () => setState(() => _flipped = !_flipped),
                    front: cardFront(context, list[_index]),
                    back: cardBack(context, list[_index]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vuốt ngang để chuyển thẻ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _index > 0 ? () => _go(-1) : null,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.arrow_back),
                      ),
                      ElevatedButton(
                        onPressed: _index < list.length - 1
                            ? () => _go(1)
                            : null,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
