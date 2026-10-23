// --- SPACED REPETITION (simplified SM-2) ---

/// Per-card schedule. Grades: 0 = Again, 1 = Hard, 2 = Good, 3 = Easy.
class Srs {
  final double ease;
  final int interval; // days
  final int reps;
  final DateTime due;

  const Srs({
    this.ease = 2.5,
    this.interval = 0,
    this.reps = 0,
    required this.due,
  });

  factory Srs.fresh() => Srs(due: DateTime.now());

  factory Srs.fromJson(Map<String, dynamic> j) {
    final ease = j['e'];
    final interval = j['i'];
    final reps = j['r'];
    final due = j['d'];
    if (ease is! num ||
        !ease.isFinite ||
        ease < 1.3 ||
        interval is! int ||
        interval < 0 ||
        reps is! int ||
        reps < 0 ||
        due is! int ||
        due.abs() > 8640000000000000) {
      throw const FormatException('Invalid spaced-repetition schedule.');
    }
    return Srs(
      ease: ease.toDouble(),
      interval: interval,
      reps: reps,
      due: DateTime.fromMillisecondsSinceEpoch(due),
    );
  }

  Map<String, dynamic> toJson() => {
    'e': ease,
    'i': interval,
    'r': reps,
    'd': due.millisecondsSinceEpoch,
  };
}
