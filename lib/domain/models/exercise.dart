enum ExerciseType { listening, speaking, reading, writing }

class Exercise {
  final String id;
  final ExerciseType type;
  final String prompt;
  final String answer;

  const Exercise({
    required this.id,
    required this.type,
    required this.prompt,
    required this.answer,
  });
}
