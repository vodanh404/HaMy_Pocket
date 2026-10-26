import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/listening_exam.dart';
import '../models/study_material.dart';
import 'study_material_library.dart';

class ExamSectionPages {
  const ExamSectionPages({
    this.listening = 2,
    this.reading = 7,
    this.writing = 7,
  });

  final int listening;
  final int reading;
  final int writing;

  int pageFor(ExamSection section) => switch (section) {
    ExamSection.listening => listening,
    ExamSection.reading => reading,
    ExamSection.writing => writing,
  };
}

class ListeningExamRepository {
  ListeningExamRepository._();

  static final instance = ListeningExamRepository._();
  static const _generatedDatabaseFileName = 'generated_exam_database.json';
  final Map<String, Future<_ExamPdfContent>> _pdfContentCache = {};

  Future<ListeningExam?> loadForAudio(StudyMaterial audio) async {
    if (audio.type != 'audio') return null;
    final examCode = audio.fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final bundledExam = await ListeningExam.load(examCode);
    if (bundledExam != null &&
        bundledExam.audio.toLowerCase() == audio.fileName.toLowerCase()) {
      return bundledExam;
    }

    final exercise =
        StudyMaterialLibrary.instance.exerciseFor(audio) ??
        await _bundledPdfFor(audio);
    if (exercise == null) return null;
    final pdfReference = exercise.localPath ?? 'assets/${exercise.source}';
    final generatedDatabase = await _loadGeneratedDatabase();
    final cachedExam = generatedDatabase[examCode];
    if (cachedExam is Map<String, dynamic> &&
        cachedExam['parser_version'] == 3 &&
        cachedExam['pdf_reference'] == pdfReference) {
      final rawExam = cachedExam['exam'];
      if (rawExam is Map<String, dynamic>) {
        try {
          return ListeningExam.fromJson(examCode, rawExam);
        } on FormatException catch (error) {
          debugPrint('Ignoring invalid generated exam "$examCode": $error');
        } on TypeError catch (error) {
          debugPrint('Ignoring malformed generated exam "$examCode": $error');
        }
      }
    }

    final pdfContent = await _loadPdfContent(exercise);
    if (pdfContent.answerKeyText == null) return null;
    final generatedExam = _examFromAnswerKey(
      examCode,
      audio.fileName,
      pdfContent,
    );
    if (generatedExam == null) return null;

    generatedDatabase[examCode] = {
      'parser_version': 3,
      'pdf_reference': pdfReference,
      'section_pages': {
        'listening': pdfContent.sectionPages.listening,
        'reading': pdfContent.sectionPages.reading,
        'writing': pdfContent.sectionPages.writing,
      },
      'exam': {
        'audio': generatedExam.audio,
        'question_count': generatedExam.questionCount,
        'listening_question_count': generatedExam.listeningQuestionCount,
        'reading_question_count': generatedExam.readingQuestionCount,
        'writing_question_count': generatedExam.writingQuestionCount,
        'answers': generatedExam.answers,
      },
    };
    await _saveGeneratedDatabase(generatedDatabase);
    return generatedExam;
  }

  static Future<void> clearGeneratedDatabase() async {
    final file = await _generatedDatabaseFile();
    if (await file.exists()) await file.delete();
    instance._pdfContentCache.clear();
  }

  Future<ExamSectionPages> sectionPagesFor(StudyMaterial pdf) async =>
      (await _loadPdfContent(pdf)).sectionPages;

  Future<StudyMaterial?> _bundledPdfFor(StudyMaterial audio) async {
    final source = audio.source;
    if (source == null) return null;
    final pdfSource = source.replaceFirst(
      RegExp(r'\.mp3$', caseSensitive: false),
      '.pdf',
    );
    final assetPath = 'assets/$pdfSource';
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (!assetManifest.listAssets().contains(assetPath)) return null;
    return StudyMaterial(
      id: 'asset:$pdfSource',
      title: audio.title,
      fileName: audio.fileName.replaceFirst(
        RegExp(r'\.mp3$', caseSensitive: false),
        '.pdf',
      ),
      type: 'pdf',
      category: 'exam',
      level: audio.level,
      source: pdfSource,
    );
  }

  Future<_ExamPdfContent> _loadPdfContent(StudyMaterial pdf) {
    final source = pdf.localPath ?? 'assets/${pdf.source}';
    return _pdfContentCache.putIfAbsent(source, () => _readPdfContent(pdf));
  }

  Future<_ExamPdfContent> _readPdfContent(StudyMaterial pdf) async {
    await pdfrxFlutterInitialize();
    final document = pdf.localPath != null
        ? await PdfDocument.openFile(pdf.localPath!)
        : await PdfDocument.openAsset('assets/${pdf.source}');
    try {
      final pages = <String>[];
      int? readingPage;
      int? writingPage;
      int? answerPageIndex;
      for (final page in document.pages) {
        final text = (await page.loadText())?.fullText ?? '';
        pages.add(text);
        if (readingPage == null && _readingHeading.hasMatch(text)) {
          readingPage = page.pageNumber;
        }
        if (writingPage == null && _writingHeading.hasMatch(text)) {
          writingPage = page.pageNumber;
        }
        if (answerPageIndex == null && text.contains('卷答案')) {
          answerPageIndex = page.pageNumber - 1;
        }
      }
      final answerKeyText = answerPageIndex == null
          ? null
          : pages.skip(answerPageIndex).join('\n');
      final writingSourceEnd = answerPageIndex ?? pages.length;
      final writingSource = writingPage == null
          ? ''
          : pages
                .skip(writingPage - 1)
                .take(writingSourceEnd - writingPage + 1)
                .join('\n');
      final writingRanges = _writingQuestionRange
          .allMatches(writingSource)
          .map(
            (match) => (
              first: int.parse(match.group(1)!),
              last: int.parse(match.group(2) ?? match.group(1)!),
            ),
          )
          .toList();
      if (writingRanges.isEmpty) {
        for (final match in _singleWritingQuestion.allMatches(writingSource)) {
          final question = int.parse(match.group(1)!);
          if (question >= 100) {
            writingRanges.add((first: question, last: question));
          }
        }
      }
      return _ExamPdfContent(
        answerKeyText: answerKeyText,
        sectionPages: ExamSectionPages(
          reading: readingPage ?? 7,
          writing: writingPage ?? readingPage ?? 7,
        ),
        writingStart: writingRanges.isEmpty
            ? null
            : writingRanges
                  .map((range) => range.first)
                  .reduce((left, right) => left < right ? left : right),
        writingEnd: writingRanges.isEmpty
            ? null
            : writingRanges
                  .map((range) => range.last)
                  .reduce((left, right) => left > right ? left : right),
      );
    } finally {
      await document.dispose();
    }
  }

  ListeningExam? _examFromAnswerKey(
    String examCode,
    String audioFileName,
    _ExamPdfContent pdfContent,
  ) {
    final answerKeyText = pdfContent.answerKeyText;
    if (answerKeyText == null) return null;
    final answerHeading = answerKeyText.indexOf('卷答案');
    if (answerHeading < 0) return null;
    final answerText = answerKeyText.substring(answerHeading);
    final readingHeading = _readingHeading.firstMatch(answerText);
    if (readingHeading == null) return null;

    final answerPattern = RegExp(
      r'(\d{1,3})\s*[.．、:：]\s*([A-F]{1,6}|√|×|✓|○|X|O)',
      caseSensitive: false,
    );
    final answers = <String, String>{};
    final writingHeading = _writingHeading.firstMatch(answerText);
    final objectiveAnswerText = writingHeading == null
        ? answerText
        : answerText.substring(0, writingHeading.start);
    for (final match in answerPattern.allMatches(objectiveAnswerText)) {
      final questionNumber = int.parse(match.group(1)!);
      final rawAnswer = match.group(2)!.toUpperCase();
      final normalizedQuestionNumber = questionNumber.toString();
      if (answers.containsKey(normalizedQuestionNumber)) return null;
      answers[normalizedQuestionNumber] = switch (rawAnswer) {
        '√' || '✓' || 'O' || '○' => 'Đúng',
        '×' || 'X' => 'Sai',
        _ => rawAnswer,
      };
    }

    if (writingHeading != null && pdfContent.writingStart != null) {
      final writingText = answerText.substring(writingHeading.end);
      final writingAnswerPattern = RegExp(
        r'^\s*(\d{1,3})\s*[.．、:：]\s*(\S.*?)\s*$',
        multiLine: true,
      );
      for (final match in writingAnswerPattern.allMatches(writingText)) {
        final questionNumber = int.parse(match.group(1)!);
        if (questionNumber < pdfContent.writingStart! ||
            questionNumber > (pdfContent.writingEnd ?? questionNumber)) {
          continue;
        }
        final answer = match.group(2)!.trim();
        if (answer.contains('略')) continue;
        answers[questionNumber.toString()] = answer;
      }
    }

    if (answers.isEmpty) return null;

    final readingText = answerText.substring(readingHeading.end);
    final firstReadingQuestion = answerPattern
        .firstMatch(readingText)
        ?.group(1);
    if (firstReadingQuestion == null) return null;
    final listeningQuestionCount = int.parse(firstReadingQuestion) - 1;
    final highestAnswer = answers.keys
        .map(int.parse)
        .reduce((left, right) => left > right ? left : right);
    final writingStart = pdfContent.writingStart;
    final questionCount = pdfContent.writingEnd ?? highestAnswer;
    final readingQuestionCount = writingStart == null
        ? questionCount - listeningQuestionCount
        : writingStart - listeningQuestionCount - 1;
    final writingQuestionCount = writingStart == null
        ? 0
        : questionCount - writingStart + 1;
    if (listeningQuestionCount < 1 ||
        questionCount <= listeningQuestionCount ||
        readingQuestionCount < 1 ||
        writingQuestionCount < 0 ||
        (writingStart != null &&
            (writingStart <= listeningQuestionCount ||
                pdfContent.writingEnd == null))) {
      return null;
    }

    return ListeningExam.fromJson(examCode, {
      'audio': audioFileName,
      'listening_question_count': listeningQuestionCount,
      'reading_question_count': readingQuestionCount,
      'writing_question_count': writingQuestionCount,
      'question_count': questionCount,
      'answers': answers,
    });
  }

  Future<Map<String, dynamic>> _loadGeneratedDatabase() async {
    final file = await _generatedDatabaseFile();
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      debugPrint('Ignoring generated exam database: expected a JSON object.');
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed generated exam database: $error');
    }
    return {};
  }

  Future<void> _saveGeneratedDatabase(Map<String, dynamic> database) async {
    final file = await _generatedDatabaseFile();
    await file.writeAsString(jsonEncode(database), flush: true);
  }

  static Future<File> _generatedDatabaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}$_generatedDatabaseFileName',
    );
  }

  static final _readingHeading = RegExp(r'二\s*[、.．]?\s*阅\s*读');
  static final _writingHeading = RegExp(r'三\s*[、.．]?\s*书\s*写');
  static final _writingQuestionRange = RegExp(
    r'(?:第\s*)?(\d{1,3})\s*[-－~～]\s*(\d{1,3})\s*题',
  );
  static final _singleWritingQuestion = RegExp(
    r'(?:第\s*)?(\d{3})\s*题',
  );
}

class _ExamPdfContent {
  const _ExamPdfContent({
    required this.answerKeyText,
    required this.sectionPages,
    required this.writingStart,
    required this.writingEnd,
  });

  final String? answerKeyText;
  final ExamSectionPages sectionPages;
  final int? writingStart;
  final int? writingEnd;
}
