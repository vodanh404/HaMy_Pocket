import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/data/models/listening_exam.dart';
import 'package:hamy_poket/data/models/study_material.dart';
import 'package:hamy_poket/data/services/listening_exam_repository.dart';
import 'package:hamy_poket/data/services/study_material_library.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'hamy_pocket_exam_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory' ||
              call.method == 'getTemporaryDirectory') {
            return supportDirectory.path;
          }
          throw MissingPluginException(
            'No mock for ${call.method} on ${pathProviderChannel.name}',
          );
        });
    Pdfrx.cacheDirectoryPath = supportDirectory.path;
    await StudyMaterialLibrary.instance.load();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await supportDirectory.delete(recursive: true);
  });

  test(
    'generates and persists answer JSON from detected HSK2 and HSK3 PDFs',
    () async {
      final generatedFile = File(
        '${supportDirectory.path}${Platform.pathSeparator}'
        'generated_exam_database.json',
      );
      await generatedFile.writeAsString(
        jsonEncode({
          'H31001': {
            'pdf_reference': 'assets/audio/HSK3/H31001.pdf',
            'exam': {
              'audio': 'H31001.mp3',
              'listening_question_count': 40,
              'question_count': 70,
              'answers': {'1': 'A', '70': 'C'},
            },
          },
        }),
      );
      for (final testCase in [
        (
          examCode: 'H20901',
          level: 2,
          questions: 60,
          listeningQuestions: 35,
          readingQuestions: 25,
          writingQuestions: 0,
        ),
        (
          examCode: 'H31001',
          level: 3,
          questions: 80,
          listeningQuestions: 40,
          readingQuestions: 30,
          writingQuestions: 10,
        ),
      ]) {
        final audio = StudyMaterial(
          id: 'asset:audio/HSK${testCase.level}/${testCase.examCode}.mp3',
          title: testCase.examCode,
          fileName: '${testCase.examCode}.mp3',
          type: 'audio',
          category: 'listening',
          level: testCase.level,
          source: 'audio/HSK${testCase.level}/${testCase.examCode}.mp3',
        );
        final exam = await ListeningExamRepository.instance.loadForAudio(audio);

        expect(exam, isNotNull, reason: testCase.examCode);
        expect(
          exam!.questionCount,
          testCase.questions,
          reason: testCase.examCode,
        );
        expect(
          exam.listeningQuestionCount,
          testCase.listeningQuestions,
          reason: testCase.examCode,
        );
        expect(
          exam.answers.length,
          greaterThanOrEqualTo(testCase.listeningQuestions),
        );
        expect(
          exam.readingQuestionCount,
          testCase.readingQuestions,
          reason: testCase.examCode,
        );
        expect(
          exam.answersForSection(ExamSection.reading),
          isNotEmpty,
          reason: testCase.examCode,
        );
        expect(
          exam.questionNumbersFor(ExamSection.writing),
          hasLength(testCase.writingQuestions),
          reason: testCase.examCode,
        );
        expect(exam.answers['1'], isNotEmpty);
      }

      expect(generatedFile.existsSync(), isTrue);
      final generated =
          jsonDecode(generatedFile.readAsStringSync()) as Map<String, dynamic>;
      expect(generated.keys, containsAll(['H20901', 'H31001']));

      final cached = generated['H31001']! as Map<String, dynamic>;
      expect(cached['parser_version'], 3);
      final cachedExam = ListeningExam.fromJson(
        'H31001',
        cached['exam']! as Map<String, dynamic>,
      );
      expect(cachedExam.answers['35'], isNotNull);
      expect(cachedExam.answers['36'], isNotNull);
      expect(cachedExam.answers['71'], isNotEmpty);
      expect(cachedExam.answers['80'], isNotEmpty);
      expect(
        ListeningExam.isFreeResponseAnswer(cachedExam.answers['71']!),
        isTrue,
      );
      expect(
        ListeningExam.isFreeResponseAnswer(cachedExam.answers['70']!),
        isFalse,
      );
    },
  );

  test('splits bundled HSK4 through HSK6 exams into three sections', () async {
    for (final testCase in [
      (
        examCode: 'H41001',
        level: 4,
        questions: 100,
        listening: 45,
        reading: 40,
        writing: 15,
      ),
      (
        examCode: 'H51001',
        level: 5,
        questions: 100,
        listening: 45,
        reading: 45,
        writing: 10,
      ),
      (
        examCode: 'H61001',
        level: 6,
        questions: 101,
        listening: 50,
        reading: 50,
        writing: 1,
      ),
    ]) {
      final audio = StudyMaterial(
        id: 'asset:audio/HSK${testCase.level}/${testCase.examCode}.mp3',
        title: testCase.examCode,
        fileName: '${testCase.examCode}.mp3',
        type: 'audio',
        category: 'listening',
        level: testCase.level,
        source: 'audio/HSK${testCase.level}/${testCase.examCode}.mp3',
      );
      final exam = await ListeningExamRepository.instance.loadForAudio(audio);

      expect(exam, isNotNull, reason: testCase.examCode);
      expect(exam!.questionCount, testCase.questions, reason: testCase.examCode);
      expect(
        exam.listeningQuestionCount,
        testCase.listening,
        reason: testCase.examCode,
      );
      expect(
        exam.readingQuestionCount,
        testCase.reading,
        reason: testCase.examCode,
      );
      expect(
        exam.writingQuestionCount,
        testCase.writing,
        reason: testCase.examCode,
      );
      expect(
        exam.answersForSection(ExamSection.listening),
        hasLength(testCase.listening),
        reason: testCase.examCode,
      );
      expect(
        exam.answersForSection(ExamSection.reading),
        hasLength(testCase.reading),
        reason: testCase.examCode,
      );
      expect(
        exam.questionNumbersFor(ExamSection.writing),
        hasLength(testCase.writing),
        reason: testCase.examCode,
      );
      if (testCase.examCode == 'H61001') {
        expect(exam.answers.containsKey('101'), isFalse);
        expect(exam.answers.length, 100);
      }

      final pdf = StudyMaterialLibrary.instance.exerciseFor(audio);
      expect(pdf, isNotNull, reason: testCase.examCode);
      final pages = await ListeningExamRepository.instance.sectionPagesFor(pdf!);
      expect(pages.reading, greaterThan(pages.listening));
      expect(pages.writing, greaterThan(pages.reading));
    }
  });
}
