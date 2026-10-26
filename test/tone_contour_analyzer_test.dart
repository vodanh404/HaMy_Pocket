import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/features/speaking/tone_contour_analyzer.dart';

const sampleRate = 16000;
const duration = 1.2;

void main() {
  const analyzer = ToneContourAnalyzer();

  test('scores a level tone above a rising contour', () {
    final result = analyzer.analyze(
      samples: _synthesize((_) => 200),
      sampleRate: sampleRate,
      targetTone: 1,
    );

    expect(result.pitchContour, isNotEmpty);
    expect(result.score, greaterThanOrEqualTo(85));
  });

  test('recognizes rising, dipping, and falling contours', () {
    final rising = analyzer.analyze(
      samples: _synthesize((time) => 150 + 100 * time / duration),
      sampleRate: sampleRate,
      targetTone: 2,
    );
    final dipping = analyzer.analyze(
      samples: _synthesize(
        (time) =>
            time < 0.6 ? 220 - 75 * time / 0.6 : 145 + 50 * (time - 0.6) / 0.6,
      ),
      sampleRate: sampleRate,
      targetTone: 3,
    );
    final falling = analyzer.analyze(
      samples: _synthesize((time) => 280 - 140 * time / duration),
      sampleRate: sampleRate,
      targetTone: 4,
    );

    expect(rising.score, greaterThanOrEqualTo(70));
    expect(dipping.score, greaterThanOrEqualTo(70));
    expect(falling.score, greaterThanOrEqualTo(70));
  });

  test('returns no score when the recording is too short or unvoiced', () {
    final result = analyzer.analyze(
      samples: List<double>.filled(sampleRate ~/ 10, 0),
      sampleRate: sampleRate,
      targetTone: 1,
    );

    expect(result.score, 0);
    expect(result.pitchContour, isEmpty);
  });
}

List<double> _synthesize(double Function(double time) frequencyAt) {
  final sampleCount = (sampleRate * duration).round();
  var phase = 0.0;
  return List<double>.generate(sampleCount, (index) {
    final time = index / sampleRate;
    phase += 2 * math.pi * frequencyAt(time) / sampleRate;
    return 0.5 * math.sin(phase);
  });
}
