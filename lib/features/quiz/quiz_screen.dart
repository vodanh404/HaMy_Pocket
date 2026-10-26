import 'dart:math';

import 'package:flutter/material.dart';

import '../../shared/study.dart';

// --- SCREEN 3: QUIZ (filter by HSK level or own words) ---
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _filter = -1, _score = 0, _total = 0;
  Vocab? _q;
  List<String> _options = [];
  String? _picked;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final pool = allWords.where((v) => inScope(v, _filter)).toList();
    final meanings = pool.map((v) => v.meaning).toSet();
    if (meanings.length < 4) {
      setState(() => _q = null);
      return;
    }
    final q = pool[Random().nextInt(pool.length)];
    final others = (meanings..remove(q.meaning)).toList()..shuffle();
    setState(() {
      _q = q;
      _picked = null;
      _options = [...others.take(3), q.meaning]..shuffle();
    });
  }

  void _pick(String o) {
    if (_picked != null) return;
    setState(() {
      _picked = o;
      _total++;
      if (o == _q!.meaning) _score++;
    });
  }

  Color? _tint(String o) => _picked == null
      ? null
      : o == _q!.meaning
      ? Colors.green.shade200
      : o == _picked
      ? Colors.red.shade200
      : null;

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm Tra Nhanh')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ChipRow(
            items: filterItems,
            selected: _filter,
            scroll: true,
            onChanged: (f) {
              _filter = f;
              _next();
            },
          ),
          if (q == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Cần ít nhất 4 nghĩa khác nhau trong phạm vi này để tạo câu hỏi.\nHãy chọn phạm vi khác hoặc thêm từ.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Điểm: $_score / $_total',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Từ này có nghĩa là gì?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      q.hanzi,
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    q.pinyin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, color: Colors.grey),
                  ),
                  Center(child: speakerButton(context, q.hanzi)),
                  const SizedBox(height: 12),
                  for (final o in _options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.tonal(
                        onPressed: () => _pick(o),
                        style: FilledButton.styleFrom(
                          backgroundColor: _tint(o),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: Text(o),
                      ),
                    ),
                  if (_picked != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        'Câu tiếp theo',
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed: _next,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
