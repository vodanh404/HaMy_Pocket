import 'dart:convert';

import 'package:flutter/services.dart';

enum ExamSection { listening, reading, writing }

class ListeningExam {
  const ListeningExam({
    required this.examCode,
    required this.audio,
    required this.questionCount,
    required this.listeningQuestionCount,
    required this.readingQuestionCount,
    required this.writingQuestionCount,
    required this.answers,
  });

  static const databaseAsset = 'assets/audio/exam_database.json';

  final String examCode;
  final String audio;
  final int questionCount;
  final int listeningQuestionCount;
  final int readingQuestionCount;
  final int writingQuestionCount;
  final Map<String, String> answers;

  static bool isFreeResponseAnswer(String answer) =>
      !const {'đúng', 'sai'}.contains(answer.trim().toLowerCase()) &&
      !RegExp(r'^[A-F]$', caseSensitive: false).hasMatch(answer.trim());

  static String normalizeFreeResponse(String answer) => answer
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[。！？；，、,.!?;:]+$'), '');

  List<String> get questionNumbers =>
      List.generate(questionCount, (index) => (index + 1).toString());

  List<String> questionNumbersFor(ExamSection section) {
    final firstQuestion = switch (section) {
      ExamSection.listening => 1,
      ExamSection.reading => listeningQuestionCount + 1,
      ExamSection.writing => listeningQuestionCount + readingQuestionCount + 1,
    };
    final questionCount = switch (section) {
      ExamSection.listening => listeningQuestionCount,
      ExamSection.reading => readingQuestionCount,
      ExamSection.writing => writingQuestionCount,
    };
    return List.generate(
      questionCount,
      (index) => (firstQuestion + index).toString(),
    );
  }

  Map<String, String> answersForSection(ExamSection section) {
    final questionNumbers = questionNumbersFor(section).toSet();
    return Map.fromEntries(
      answers.entries.where((entry) => questionNumbers.contains(entry.key)),
    );
  }

  Map<String, String> answersForRange(int firstQuestion, int lastQuestion) =>
      Map.fromEntries(
        answers.entries.where((entry) {
          final questionNumber = int.parse(entry.key);
          return questionNumber >= firstQuestion &&
              questionNumber <= lastQuestion;
        }),
      );

  factory ListeningExam.fromJson(String examCode, Map<String, dynamic> json) {
    final audio = json['audio'];
    final rawQuestionCount = json['question_count'];
    final rawListeningQuestionCount = json['listening_question_count'];
    final rawReadingQuestionCount = json['reading_question_count'];
    final rawWritingQuestionCount = json['writing_question_count'];
    final rawAnswers = json['answers'];
    if (audio is! String || audio.trim().isEmpty) {
      throw const FormatException('Thiếu tên file audio trong dữ liệu đề.');
    }
    if (rawAnswers is! Map<String, dynamic> || rawAnswers.isEmpty) {
      throw const FormatException('Đề phải có ít nhất một đáp án.');
    }

    final answers = <String, String>{};
    for (final entry in rawAnswers.entries) {
      final questionNumber = int.tryParse(entry.key);
      if (questionNumber == null ||
          questionNumber < 1 ||
          entry.value is! String ||
          (entry.value as String).trim().isEmpty) {
        throw FormatException('Đáp án câu "${entry.key}" không hợp lệ.');
      }
      final normalizedQuestionNumber = questionNumber.toString();
      if (answers.containsKey(normalizedQuestionNumber)) {
        throw FormatException('Câu $normalizedQuestionNumber bị lặp.');
      }
      answers[normalizedQuestionNumber] = entry.value as String;
    }

    final highestQuestion = answers.keys
        .map(int.parse)
        .reduce((left, right) => left > right ? left : right);
    if ((rawQuestionCount != null && rawQuestionCount is! int) ||
        (rawListeningQuestionCount != null &&
            rawListeningQuestionCount is! int) ||
        (rawReadingQuestionCount != null && rawReadingQuestionCount is! int) ||
        (rawWritingQuestionCount != null && rawWritingQuestionCount is! int)) {
      throw const FormatException('Số lượng câu hỏi không hợp lệ.');
    }
    final questionCount = rawQuestionCount as int? ?? highestQuestion;
    final listeningQuestionCount =
        rawListeningQuestionCount as int? ?? questionCount;
    final writingQuestionCount = rawWritingQuestionCount as int? ?? 0;
    final readingQuestionCount =
        rawReadingQuestionCount as int? ??
        questionCount - listeningQuestionCount - writingQuestionCount;
    if (
        questionCount < highestQuestion ||
        questionCount < 1 ||
        listeningQuestionCount < 1 ||
        writingQuestionCount < 0 ||
        readingQuestionCount < 0 ||
        listeningQuestionCount + readingQuestionCount + writingQuestionCount !=
            questionCount) {
      throw const FormatException('Số lượng câu hỏi không hợp lệ.');
    }

    return ListeningExam(
      examCode: examCode,
      audio: audio.trim(),
      questionCount: questionCount,
      listeningQuestionCount: listeningQuestionCount,
      readingQuestionCount: readingQuestionCount,
      writingQuestionCount: writingQuestionCount,
      answers: Map.unmodifiable(answers),
    );
  }

  static Future<ListeningExam?> load(String examCode) async {
    final contents = await rootBundle.loadString(databaseAsset);
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Dữ liệu đề nghe phải là một JSON object.');
    }
    final rawExam = decoded[examCode];
    if (rawExam == null) return null;
    if (rawExam is! Map<String, dynamic>) {
      throw FormatException('Dữ liệu đề "$examCode" không hợp lệ.');
    }
    return ListeningExam.fromJson(examCode, rawExam);
  }
}
