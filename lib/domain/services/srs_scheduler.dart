import 'dart:math';

import '../../domain/models/progress.dart';
import '../../domain/models/vocab.dart';

/// Pure function: compute the next schedule from the current one and a grade.
Srs nextSrs(Srs s, int q, DateTime now) {
  if (q < 0 || q > 3) {
    throw RangeError.range(q, 0, 3, 'q');
  }
  if (q == 0) {
    return Srs(
      ease: max(1.3, s.ease - 0.2),
      reps: 0,
      due: now.add(const Duration(minutes: 10)),
    );
  }
  final reps = s.reps + 1;
  final ease = max(1.3, s.ease + const [0.0, -0.15, 0.0, 0.15][q]);
  final base = max(s.interval, 1);
  final days = switch (q) {
    1 => max(1, (base * 1.2).round()),
    2 => reps == 1 ? 1 : (reps == 2 ? 3 : (s.interval * ease).round()),
    _ => reps == 1 ? 4 : (base * ease * 1.3).round(),
  };
  return Srs(
    ease: ease,
    interval: days,
    reps: reps,
    due: now.add(Duration(days: days)),
  );
}

/// Due reviews first (oldest due first), then up to [newLimit] unseen cards
/// (user's own words first, then by ascending HSK level).
List<Vocab> buildQueue(
  List<Vocab> words,
  Map<String, Srs> m,
  DateTime now, {
  int newLimit = 10,
}) {
  final uniqueWords = <String, Vocab>{};
  for (final word in words) {
    uniqueWords.putIfAbsent(word.id, () => word);
  }
  final cards = uniqueWords.values;
  final due =
      cards.where((v) => m[v.id] != null && !m[v.id]!.due.isAfter(now)).toList()
        ..sort((a, b) => m[a.id]!.due.compareTo(m[b.id]!.due));
  final fresh =
      (cards.where((v) => !m.containsKey(v.id)).toList()..sort(
            (a, b) =>
                (a.custom ? 0 : a.level).compareTo(b.custom ? 0 : b.level),
          ))
          .take(newLimit);
  return [...due, ...fresh];
}

String fmtDuration(Duration d) => d.inDays >= 1
    ? '${d.inDays} ngày'
    : d.inMinutes >= 60
    ? '${d.inHours} giờ'
    : '${max(1, d.inMinutes)} phút';
