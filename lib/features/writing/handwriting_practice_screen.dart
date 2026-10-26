import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/models/vocab.dart';

class HandwritingPracticeScreen extends StatefulWidget {
  const HandwritingPracticeScreen({super.key, required this.word});

  final Vocab word;

  @override
  State<HandwritingPracticeScreen> createState() =>
      _HandwritingPracticeScreenState();
}

class _HandwritingPracticeScreenState extends State<HandwritingPracticeScreen> {
  late final List<String> _characters = widget.word.hanzi.runes
      .map(String.fromCharCode)
      .toList();
  final List<List<Offset>> _strokes = [];
  bool _showSample = true;
  bool? _selfAssessment;
  int _index = 0;
  int? _activePointer;

  String get _character => _characters[_index];

  void _clear() {
    setState(() {
      _strokes.clear();
      _selfAssessment = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Luyện viết tay')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.word.meaning,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${widget.word.pinyin} · ${widget.word.hanzi}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        if (_characters.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _index == 0
                    ? null
                    : () => setState(() {
                        _index--;
                        _strokes.clear();
                        _selfAssessment = null;
                      }),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Chữ trước',
              ),
              Text('Chữ ${_index + 1}/${_characters.length}'),
              IconButton(
                onPressed: _index == _characters.length - 1
                    ? null
                    : () => setState(() {
                        _index++;
                        _strokes.clear();
                        _selfAssessment = null;
                      }),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Chữ tiếp theo',
              ),
            ],
          ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) => RawGestureDetector(
                      key: const ValueKey('writing-canvas'),
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        EagerGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              EagerGestureRecognizer
                            >(EagerGestureRecognizer.new, (recognizer) {}),
                      },
                      child: Listener(
                        onPointerDown: (event) {
                          if (_activePointer != null) return;
                          _activePointer = event.pointer;
                          setState(() {
                            _strokes.add([event.localPosition]);
                            _selfAssessment = null;
                          });
                        },
                        onPointerMove: (event) {
                          if (event.pointer != _activePointer ||
                              _strokes.isEmpty) {
                            return;
                          }
                          setState(
                            () => _strokes.last.add(event.localPosition),
                          );
                        },
                        onPointerUp: (event) {
                          if (event.pointer == _activePointer) {
                            _activePointer = null;
                          }
                        },
                        onPointerCancel: (event) {
                          if (event.pointer == _activePointer) {
                            _activePointer = null;
                          }
                        },
                        child: CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: _WritingCanvasPainter(
                            strokes: [
                              for (final stroke in _strokes) [...stroke],
                            ],
                            reference: _showSample ? _character : null,
                            guideColor: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                            referenceColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.15),
                            inkColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Viết theo thứ tự nét cơ bản: ngang trước dọc sau, trái trước phải sau, '
          'trên trước dưới sau. Mẫu chữ chạy hoàn toàn ngoại tuyến.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _showSample = !_showSample),
              icon: Icon(_showSample ? Icons.visibility_off : Icons.visibility),
              label: Text(_showSample ? 'Ẩn chữ mẫu' : 'Hiện chữ mẫu'),
            ),
            OutlinedButton.icon(
              onPressed: _strokes.isEmpty ? null : _clear,
              icon: const Icon(Icons.backspace_outlined),
              label: const Text('Viết lại'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Tự đánh giá bài viết',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _strokes.isEmpty
                  ? null
                  : () => setState(() => _selfAssessment = true),
              icon: const Icon(Icons.thumb_up_outlined),
              label: const Text('Đạt'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _strokes.isEmpty
                  ? null
                  : () => setState(() => _selfAssessment = false),
              icon: const Icon(Icons.refresh),
              label: const Text('Luyện thêm'),
            ),
          ],
        ),
        if (_selfAssessment != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _selfAssessment!
                  ? 'Đã ghi nhận tự đánh giá: đạt.'
                  : 'Hãy thử viết lại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _selfAssessment!
                    ? Colors.green.shade800
                    : Colors.orange.shade800,
              ),
            ),
          ),
      ],
    ),
  );
}

class _WritingCanvasPainter extends CustomPainter {
  const _WritingCanvasPainter({
    required this.strokes,
    required this.guideColor,
    required this.referenceColor,
    required this.inkColor,
    this.reference,
  });

  final List<List<Offset>> strokes;
  final String? reference;
  final Color guideColor;
  final Color referenceColor;
  final Color inkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      guidePaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      guidePaint,
    );
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), guidePaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), guidePaint);

    if (reference != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: reference,
          style: TextStyle(
            color: referenceColor,
            fontSize: size.width * 0.72,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
    }

    final inkPaint = Paint()
      ..color = inkColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, inkPaint);
    }
  }

  @override
  bool shouldRepaint(_WritingCanvasPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.reference != reference ||
      oldDelegate.guideColor != guideColor ||
      oldDelegate.referenceColor != referenceColor ||
      oldDelegate.inkColor != inkColor;
}
