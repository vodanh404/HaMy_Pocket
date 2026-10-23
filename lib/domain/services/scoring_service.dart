class ExerciseScore {
  final bool correct;
  final int points;

  const ExerciseScore({required this.correct, required this.points});
}

ExerciseScore scoreAnswer({
  required String answer,
  required String expected,
  int points = 10,
}) {
  final correct = answer.trim().toLowerCase() == expected.trim().toLowerCase();
  return ExerciseScore(correct: correct, points: correct ? points : 0);
}
