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
    for (final examCode in ['H20901', 'H31001', 'H41001', 'H51001', 'H61001']) {
      final level = examCode[1];
      final source = File('assets/audio/HSK$level/$examCode.pdf');
      final destination = File(
        '${supportDirectory.path}${Platform.pathSeparator}'
        'downloaded_study_materials${Platform.pathSeparator}audio'
        '${Platform.pathSeparator}HSK$level${Platform.pathSeparator}'
        '$examCode.pdf',
      );
      await destination.parent.create(recursive: true);
      await source.copy(destination.path);
    }
    Pdfrx.cacheDirectoryPath = supportDirectory.path;
    await StudyMaterialLibrary.instance.load();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await supportDirectory.delete(recursive: true);
  });

  test('loads complete bundled answer keys for HSK2 and HSK3 exams', () async {
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
      expect(exam.answers, hasLength(testCase.questions));
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
  });

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
      expect(
        exam!.questionCount,
        testCase.questions,
        reason: testCase.examCode,
      );
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
      final pages = await ListeningExamRepository.instance.sectionPagesFor(
        pdf!,
      );
      expect(pages.reading, greaterThan(pages.listening));
      expect(pages.writing, greaterThan(pages.reading));
    }
  });
}
