import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/data/models/listening_exam.dart';
import 'package:hamy_poket/data/models/study_material.dart';
import 'package:hamy_poket/domain/services/scoring_service.dart';
import 'package:hamy_poket/shared/study_material_screen.dart';

void main() {
  testWidgets('submits answers and displays the score', (tester) async {
    var readingMode = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TextButton(
                  key: const ValueKey('toggle-reading'),
                  onPressed: () => setState(() => readingMode = !readingMode),
                  child: Text(readingMode ? 'Nghe' : 'Đọc'),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: ListeningAnswerForm(
                      material: const StudyMaterial(
                        id: 'audio',
                        title: 'Bài nghe HSK 1 · H10901',
                        fileName: 'H10901.mp3',
                        type: 'audio',
                        category: 'listening',
                        level: 1,
                      ),
                      readingMode: readingMode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Câu 11'), findsOneWidget);
    expect(find.text('Câu 20'), findsOneWidget);
    expect(find.text('Câu 21'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-reading')));
    await tester.pump();
    expect(find.text('Câu 21'), findsOneWidget);
    expect(find.text('Câu 40'), findsOneWidget);
    expect(find.text('Câu 20'), findsNothing);
    await tester.tap(find.text('Đúng').first);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toggle-reading')));
    await tester.pump();
    await tester.tap(find.text('Đúng').first);
    await tester.pump();
    await tester.ensureVisible(find.text('Nộp bài'));
    await tester.tap(find.text('Nộp bài'));
    await tester.pump();

    expect(find.text('Nghe: 1/20 · Đọc: 1/20'), findsOneWidget);
    expect(find.text('Tổng: 2/40'), findsOneWidget);
    expect(find.text('Đáp án: D'), findsOneWidget);
  });

  test(
    'loads complete listening and reading answer keys for indexed exams',
    () {
      final rawDatabase = jsonDecode(
        File('assets/audio/exam_database.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final examCode in [
        'H10901',
        'H10902',
        'H11003',
        'H11004',
        'H11005',
        'H11006',
        'H11329',
        'H11330',
        'H11331',
        'H11332',
        'H11334',
        'H11335',
      ]) {
        final exam = ListeningExam.fromJson(
          examCode,
          rawDatabase[examCode] as Map<String, dynamic>,
        );
        expect(exam.questionCount, 40, reason: examCode);
        expect(exam.listeningQuestionCount, 20, reason: examCode);
        expect(exam.answers, hasLength(40), reason: examCode);
        expect(exam.answers.containsKey('21'), isTrue, reason: examCode);
        expect(exam.answers.containsKey('40'), isTrue, reason: examCode);
        expect(exam.audio, endsWith('.mp3'), reason: examCode);
      }
    },
  );

  test('bundled database contains every scorable answer for each exam', () {
    final rawDatabase = jsonDecode(
      File('assets/audio/exam_database.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    for (final entry in rawDatabase.entries) {
      final exam = ListeningExam.fromJson(
        entry.key,
        entry.value as Map<String, dynamic>,
      );
      final level = int.parse(entry.key[1]);
      final expectedQuestionCount = switch (level) {
        1 => 40,
        2 => 60,
        3 => 80,
        4 || 5 => 100,
        6 => 101,
        _ => fail('Unsupported exam level: ${entry.key}'),
      };
      final expectedAnswerCount = switch (level) {
        5 => 98,
        6 => 100,
        _ => expectedQuestionCount,
      };

      expect(exam.questionCount, expectedQuestionCount, reason: entry.key);
      expect(exam.answers, hasLength(expectedAnswerCount), reason: entry.key);
      expect(exam.answers.keys.toSet(), {
        for (var question = 1; question <= expectedAnswerCount; question++)
          '$question',
      }, reason: entry.key);
      expect(exam.audio, endsWith('.mp3'), reason: entry.key);
    }
  });

  test('splits question ranges and scores answers from a JSON entry', () {
    final exam = ListeningExam.fromJson('H10901', {
      'audio': 'H10901.mp3',
      'listening_question_count': 2,
      'question_count': 4,
      'answers': {'1': 'Đúng', '2': 'Sai', '3': 'A', '4': 'B'},
    });

    expect(exam.questionCount, 4);
    expect(exam.listeningQuestionCount, 2);
    expect(exam.answersForRange(1, 2), {'1': 'Đúng', '2': 'Sai'});
    expect(exam.answersForRange(3, 4), {'3': 'A', '4': 'B'});
    expect(
      countCorrectAnswers(
        answers: {'1': 'Đúng', '2': 'Sai'},
        expectedAnswers: exam.answersForRange(1, 2),
      ),
      2,
    );
    expect(
      countCorrectAnswers(
        answers: {'3': 'C'},
        expectedAnswers: exam.answersForRange(3, 4),
      ),
      0,
    );
  });

  test('models HSK3 listening, reading, and writing ranges independently', () {
    final exam = ListeningExam.fromJson('H31001', {
      'audio': 'H31001.mp3',
      'question_count': 80,
      'listening_question_count': 40,
      'reading_question_count': 30,
      'writing_question_count': 10,
      'answers': {'1': 'A', '40': 'C', '41': 'B', '70': 'A', '71': '床上有一只猫'},
    });

    expect(exam.questionNumbersFor(ExamSection.listening), hasLength(40));
    expect(exam.questionNumbersFor(ExamSection.reading).first, '41');
    expect(exam.questionNumbersFor(ExamSection.reading).last, '70');
    expect(exam.questionNumbersFor(ExamSection.writing).first, '71');
    expect(exam.questionNumbersFor(ExamSection.writing).last, '80');
    expect(exam.answersForSection(ExamSection.writing), {'71': '床上有一只猫'});
    expect(ListeningExam.isFreeResponseAnswer('BCA'), isTrue);
  });

  test('rejects malformed answer data', () {
    expect(
      () => ListeningExam.fromJson('H10901', {
        'audio': 'H10901.mp3',
        'answers': {'zero': 'A'},
      }),
      throwsFormatException,
    );
    expect(
      () => ListeningExam.fromJson('H10901', {
        'audio': 'H10901.mp3',
        'question_count': 4,
        'answers': {'5': 'A'},
      }),
      throwsFormatException,
    );
  });
}
