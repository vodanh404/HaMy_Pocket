import 'dart:math' as math;

class ToneContourResult {
  const ToneContourResult({
    required this.score,
    required this.pitchContour,
    required this.feedback,
  });

  final int score;
  final List<double> pitchContour;
  final String feedback;
}

class ToneContourAnalyzer {
  const ToneContourAnalyzer();

  ToneContourResult analyze({
    required List<double> samples,
    required int sampleRate,
    required int targetTone,
  }) {
    if (targetTone < 1 || targetTone > 4) {
      throw RangeError.range(targetTone, 1, 4, 'targetTone');
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }

    final pitches = _extractPitchContour(samples, sampleRate);
    if (pitches.length < 3) {
      return const ToneContourResult(
        score: 0,
        pitchContour: [],
        feedback:
            'Chưa nghe rõ giọng. Hãy nói to hơn và giữ nguyên âm lâu hơn.',
      );
    }

    final early = _median(pitches.take((pitches.length / 3).ceil()).toList());
    final middleStart = (pitches.length / 3).floor();
    final middleEnd = (pitches.length * 2 / 3).ceil();
    final middle = _median(pitches.sublist(middleStart, middleEnd));
    final late = _median(
      pitches.skip((pitches.length * 2 / 3).floor()).toList(),
    );
    final minimumPitch = pitches.reduce((a, b) => a < b ? a : b);
    final maximumPitch = pitches.reduce((a, b) => a > b ? a : b);
    final wholeRange = math.log(maximumPitch / minimumPitch);
    final earlyToLate = math.log(late / early);
    final earlyToMiddle = math.log(middle / early);
    final middleToLate = math.log(late / middle);
    final dip = -earlyToMiddle;
    final rise = middleToLate;
    final score = switch (targetTone) {
      1 => _score(1 - (earlyToLate.abs() * 80) - (wholeRange * 60)),
      2 => _score(earlyToLate >= 0 ? earlyToLate / 0.4 : 0),
      3 => _score(
        dip >= 0.08 && rise >= 0.05
            ? 0.70 + (math.min(dip + rise, 0.45) * 0.60)
            : 0.65 -
                  (math.max(0, 0.08 - dip) * 2) -
                  (math.max(0, 0.05 - rise) * 2),
      ),
      4 => _score(earlyToLate <= 0 ? -earlyToLate / 0.4 : 0),
      _ => 0,
    };
    final feedback = switch (targetTone) {
      2 when earlyToLate < 0.12 =>
        'Thanh 2 chưa đi lên đủ rõ. Hãy nâng cao độ đều từ đầu đến cuối.',
      3 when dip < 0.08 =>
        'Thanh 3 cần hạ giọng sâu hơn ở giữa âm tiết trước khi nâng lên.',
      3 when rise < 0.05 =>
        'Thanh 3 đã hạ giọng, nhưng cần nâng cao độ rõ hơn ở cuối âm tiết.',
      4 when earlyToLate > -0.12 => 'Thanh 4 chưa đi xuống đủ rõ. Hãy bắt đầu cao hơn rồi hạ giọng dứt khoát.',
      _ when score >= 70 =>
        'Đường cao độ khá gần thanh $targetTone. Hãy nghe mẫu rồi thử lại để ổn định hơn.',
      _ =>
        'Đường cao độ chưa giống thanh $targetTone. Nghe mẫu và chú ý hướng lên/xuống của giọng.',
    };
    return ToneContourResult(
      score: score,
      pitchContour: List.unmodifiable(pitches),
      feedback: feedback,
    );
  }

  List<double> _extractPitchContour(List<double> samples, int sampleRate) {
    const frameDuration = 0.04;
    const hopDuration = 0.02;
    final frameSize = (sampleRate * frameDuration).round();
    final hopSize = (sampleRate * hopDuration).round();
    final minimumLag = (sampleRate / 450).floor();
    final maximumLag = (sampleRate / 70).ceil();
    final pitches = <double>[];

    for (var start = 0; start + frameSize <= samples.length; start += hopSize) {
      var mean = 0.0;
      for (var i = 0; i < frameSize; i++) {
        mean += samples[start + i];
      }
      mean /= frameSize;

      var energy = 0.0;
      for (var i = 0; i < frameSize; i++) {
        final value = samples[start + i] - mean;
        energy += value * value;
      }
      if (energy / frameSize < 0.00008) continue;

      var bestLag = 0;
      var bestCorrelation = 0.0;
      final correlations = List<double>.filled(maximumLag + 1, 0);
      for (var lag = minimumLag; lag <= maximumLag; lag++) {
        var correlation = 0.0;
        var leftEnergy = 0.0;
        var rightEnergy = 0.0;
        for (var i = 0; i < frameSize - lag; i++) {
          final left = samples[start + i] - mean;
          final right = samples[start + i + lag] - mean;
          correlation += left * right;
          leftEnergy += left * left;
          rightEnergy += right * right;
        }
        final normalization = math.sqrt(leftEnergy * rightEnergy);
        if (normalization == 0) continue;
        final normalizedCorrelation = correlation / normalization;
        correlations[lag] = normalizedCorrelation;
        if (normalizedCorrelation > bestCorrelation) {
          bestCorrelation = normalizedCorrelation;
          bestLag = lag;
        }
      }
      if (bestLag > 0 && bestCorrelation >= 0.45) {
        var selectedLag = bestLag;
        for (var lag = minimumLag + 1; lag < maximumLag; lag++) {
          final isPeak =
              correlations[lag] >= correlations[lag - 1] &&
              correlations[lag] >= correlations[lag + 1];
          if (isPeak && correlations[lag] >= bestCorrelation - 0.025) {
            selectedLag = lag;
            break;
          }
        }
        pitches.add(sampleRate / selectedLag);
      }
    }

    return pitches;
  }

  int _score(double value) => (value * 100).round().clamp(0, 100);

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
