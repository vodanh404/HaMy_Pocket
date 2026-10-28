import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../../services/speech/speech_service.dart';
import 'tone_contour_analyzer.dart';

class TonePracticeScreen extends StatefulWidget {
  const TonePracticeScreen({super.key});

  @override
  State<TonePracticeScreen> createState() => _TonePracticeScreenState();
}

class _TonePracticeScreenState extends State<TonePracticeScreen> {
  static const _items = [
    _TonePracticeItem(hanzi: '妈', pinyin: 'mā', tone: 1, direction: 'cao, đều'),
    _TonePracticeItem(hanzi: '麻', pinyin: 'má', tone: 2, direction: 'đi lên'),
    _TonePracticeItem(
      hanzi: '马',
      pinyin: 'mǎ',
      tone: 3,
      direction: 'hạ xuống rồi nâng lên',
    ),
    _TonePracticeItem(hanzi: '骂', pinyin: 'mà', tone: 4, direction: 'đi xuống'),
  ];
  static const _sampleRate = 16000;
  static const _maxSamples = _sampleRate * 6;

  final AudioRecorder _recorder = AudioRecorder();
  final ToneContourAnalyzer _analyzer = const ToneContourAnalyzer();
  final List<double> _samples = [];
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _recordingTimer;
  ToneContourResult? _result;
  Object? _recordingError;
  int _toneIndex = 0;
  bool _isRecording = false;
  bool _isPlayingSample = false;
  int? _trailingByte;

  _TonePracticeItem get _item => _items[_toneIndex];

  Future<void> _playSample() async {
    setState(() => _isPlayingSample = true);
    try {
      await speak(_item.hanzi);
    } finally {
      if (mounted) setState(() => _isPlayingSample = false);
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _recordingError = null;
      _result = null;
      _samples.clear();
      _trailingByte = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        throw StateError('Cần cấp quyền micro để luyện thanh điệu.');
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: 4096,
        ),
      );
      _audioSubscription = stream.listen(
        _captureAudio,
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _recordingError = error);
          unawaited(_stopRecording());
        },
      );
      _recordingTimer = Timer(
        const Duration(seconds: 6),
        () => unawaited(_stopRecording()),
      );
      if (mounted) setState(() => _isRecording = true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingError = error;
        });
      }
    }
  }

  void _captureAudio(Uint8List bytes) {
    var index = 0;
    if (_trailingByte != null && bytes.isNotEmpty) {
      _appendPcmSample(_trailingByte!, bytes[0]);
      _trailingByte = null;
      index = 1;
    }
    while (index + 1 < bytes.length && _samples.length < _maxSamples) {
      _appendPcmSample(bytes[index], bytes[index + 1]);
      index += 2;
    }
    if (index < bytes.length) _trailingByte = bytes[index];
    if (_samples.length >= _maxSamples) unawaited(_stopRecording());
  }

  void _appendPcmSample(int lowByte, int highByte) {
    final value = (highByte << 8) | lowByte;
    final signedValue = value >= 0x8000 ? value - 0x10000 : value;
    _samples.add(signedValue / 32768);
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      await _recorder.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      if (!mounted) return;
      final result = _analyzer.analyze(
        samples: _samples,
        sampleRate: _sampleRate,
        targetTone: _item.tone,
      );
      if (result.pitchContour.isNotEmpty) {
        unawaited(HapticFeedback.mediumImpact());
      }
      setState(() {
        _isRecording = false;
        _result = result;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingError = error;
        });
      }
    }
  }

  void _selectTone(int index) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _toneIndex = index;
      _result = null;
      _recordingError = null;
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    final subscription = _audioSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Luyện thanh điệu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Nghe mẫu, đọc theo rồi xem đường cao độ ước lượng của mình.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (var index = 0; index < _items.length; index++)
                ChoiceChip(
                  label: Text('Thanh ${index + 1}'),
                  selected: _toneIndex == index,
                  onSelected: _isRecording ? null : (_) => _selectTone(index),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    _item.hanzi,
                    style: Theme.of(context).textTheme.displayLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _item.pinyin,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: colors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text('Thanh ${_item.tone}: ${_item.direction}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isPlayingSample ? null : _playSample,
                icon: _isPlayingSample
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up),
                label: const Text('Nghe mẫu Sherpa'),
              ),
              FilledButton.icon(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Dừng ghi âm' : 'Đọc và ghi âm'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording
                ? 'Đang nghe... tối đa 6 giây. Đọc nguyên âm “a” rõ và liền mạch.'
                : 'Bản ghi chỉ được xử lý trên thiết bị và không lưu lại.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_recordingError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Không thể ghi âm: $_recordingError',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error),
              ),
            ),
          if (_result case final result?) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      result.pitchContour.isEmpty
                          ? 'Chưa nhận được cao độ rõ'
                          : 'Độ gần với thanh ${_item.tone}: ${result.score}%',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (result.pitchContour.isNotEmpty)
                      SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _PitchContourPainter(
                            pitches: result.pitchContour,
                            color: colors.primary,
                            guideColor: colors.outlineVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(result.feedback, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Điểm số chỉ ước lượng hướng lên/xuống của cao độ (không đánh giá chuẩn người bản xứ). '
            'Môi trường ồn hoặc âm lượng nhỏ có thể làm kết quả kém chính xác.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TonePracticeItem {
  const _TonePracticeItem({
    required this.hanzi,
    required this.pinyin,
    required this.tone,
    required this.direction,
  });

  final String hanzi;
  final String pinyin;
  final int tone;
  final String direction;
}

class _PitchContourPainter extends CustomPainter {
  const _PitchContourPainter({
    required this.pitches,
    required this.color,
    required this.guideColor,
  });

  final List<double> pitches;
  final Color color;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (pitches.length < 2) return;
    final minimum = pitches.reduce(math.min);
    final maximum = pitches.reduce(math.max);
    final range = math.max(maximum - minimum, 1);
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      guidePaint,
    );

    final line = Path();
    for (var index = 0; index < pitches.length; index++) {
      final x = size.width * index / (pitches.length - 1);
      final y =
          size.height -
          (pitches[index] - minimum) / range * (size.height - 12) -
          6;
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_PitchContourPainter oldDelegate) =>
      oldDelegate.pitches != pitches ||
      oldDelegate.color != color ||
      oldDelegate.guideColor != guideColor;
}
