import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/main.dart' as app;
import 'package:hamy_poket/data/services/study_material_library.dart';
import 'package:hamy_poket/data/models/study_material.dart';
import 'package:hamy_poket/domain/services/scoring_service.dart';
import 'package:hamy_poket/shared/study_material_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'hamy_pocket_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return supportDirectory.path;
          }
          throw MissingPluginException(
            'No mock for ${call.method} on ${pathProviderChannel.name}',
          );
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await supportDirectory.delete(recursive: true);
  });

  test('loads and classifies the complete dictionary', () async {
    await app.loadDictionary();

    expect(app.builtIn, hasLength(11470));
    expect(
      app.builtIn.every(
        (word) => word.pinyin.isNotEmpty && word.meaning.isNotEmpty,
      ),
      isTrue,
    );
    expect(app.builtIn.any((word) => word.level == 1), isTrue);
    expect(app.builtIn.any((word) => word.level == 6), isTrue);
    expect(app.builtIn.any((word) => word.level == 7), isTrue);
    expect(app.levelLabel(7), 'HSK 7–9');
    expect(
      app.filterItems.any((item) => item.$1 == 8 || item.$1 == 9),
      isFalse,
    );

    final love = app.builtIn.firstWhere((word) => word.hanzi == '爱');
    expect(love.traditional, contains('愛'));
    expect(app.matchScore(love, '愛'), greaterThan(0));
    expect(app.matchScore(love, 'ai'), greaterThan(0));
    expect(app.inScope(love, 1), isTrue);
    expect(app.inScope(love, 2), isFalse);
    final upperLevel = app.Vocab(
      id: 'upper-level',
      hanzi: '高',
      pinyin: 'gāo',
      meaning: 'Cao cấp',
      level: 9,
    );
    expect(app.inScope(upperLevel, 7), isTrue);
  });

  test('loads valid persisted entries and repairs malformed or duplicate data', () async {
    final due = DateTime.utc(2026).millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'srs_v1':
          '{"valid":{"e":2.5,"i":1,"r":1,"d":$due},"invalid":{"e":"bad","i":-1,"r":0,"d":$due}}',
      'custom_v1': '[{"id":"same","h":"旧","p":"jiu","m":"Old","l":0},{"id":"same","h":"新","p":"xin","m":"New","l":0},{"id":"","h":"坏","p":"huai","m":"Bad","l":0}]',
      'saved_v1': '[{"id":"same","h":"旧","p":"jiu","m":"Old","l":0},{"id":"saved","h":"词","t":"詞","p":"ci","m":"Word","l":2}]',
    });

    await app.Store.load();

    expect(app.Store.srs.value.keys, ['valid']);
    expect(app.Store.custom.value, hasLength(1));
    expect(app.Store.custom.value.single.meaning, 'New');
    expect(app.Store.personalWords.map((word) => word.id), ['same', 'saved']);
    expect(app.Store.personalWords.last.traditional, '詞');

    await app.Store.load();
    expect(app.Store.srs.value.keys, ['valid']);
    expect(app.Store.custom.value.single.meaning, 'New');
    expect(app.Store.saved.value, hasLength(1));
  });

  test('rejects invalid model data and review grades', () {
    expect(
      () => app.Vocab.fromJson({'id': '', 'h': '词', 'p': 'ci', 'm': 'word'}),
      throwsFormatException,
    );
    expect(
      () => app.Srs.fromJson({'e': 2.5, 'i': -1, 'r': 0, 'd': 0}),
      throwsFormatException,
    );
    expect(
      () => app.nextSrs(app.Srs.fresh(), 4, DateTime.utc(2026)),
      throwsRangeError,
    );
  });

  test('recovers from malformed preference JSON', () async {
    SharedPreferences.setMockInitialValues({
      'srs_v1': '{not-json',
      'custom_v1': 'not-json',
      'saved_v1': 'null',
    });

    await app.Store.load();

    expect(app.Store.srs.value, isEmpty);
    expect(app.Store.custom.value, isEmpty);
    expect(app.Store.saved.value, isEmpty);
    await app.Store.load();
    expect(app.Store.srs.value, isEmpty);
  });

  test('builds a unique review queue and persists graded schedules', () async {
    SharedPreferences.setMockInitialValues({});
    await app.Store.load();
    final now = DateTime.utc(2026);
    final first = app.Vocab(
      id: 'same',
      hanzi: '词',
      pinyin: 'ci',
      meaning: 'Word',
      level: 2,
    );
    final duplicate = app.Vocab(
      id: 'same',
      hanzi: '詞',
      pinyin: 'ci',
      meaning: 'Word',
      level: 2,
    );
    final custom = app.Vocab(
      id: 'custom',
      hanzi: '自定义',
      pinyin: 'zidingyi',
      meaning: 'Custom',
      level: 0,
      custom: true,
    );
    final overdue = app.Srs(
      interval: 1,
      reps: 1,
      due: now.subtract(const Duration(days: 1)),
    );

    final queue = app.buildQueue(
      [first, duplicate, custom],
      {'same': overdue},
      now,
      newLimit: 1,
    );
    expect(queue.map((word) => word.id), ['same', 'custom']);

    final retry = app.nextSrs(overdue, 0, now);
    expect(retry.reps, 0);
    expect(retry.due, now.add(const Duration(minutes: 10)));
    expect(app.nextSrs(app.Srs.fresh(), 2, now).interval, 1);
    expect(app.nextSrs(app.Srs.fresh(), 3, now).interval, 4);

    await app.Store.putSrs('same', retry);
    await app.Store.load();
    expect(app.Store.srs.value['same']?.reps, 0);
    expect(
      app.Store.srs.value['same']?.due.isAtSameMomentAs(retry.due),
      isTrue,
    );
  });

  test(
    'saves and removes built-in words from the personal dictionary',
    () async {
      SharedPreferences.setMockInitialValues({});
      await app.Store.load();
      final word = app.builtIn.first;

      expect(app.Store.isPersonal(word), isFalse);
      expect(app.inScope(word, 0), isFalse);

      await app.Store.togglePersonal(word);
      expect(app.Store.isPersonal(word), isTrue);
      expect(app.inScope(word, 0), isTrue);

      await app.Store.load();
      final savedWord = app.Store.personalWords.single;
      expect(savedWord.id, word.id);
      expect(savedWord.custom, isFalse);
      expect(savedWord.traditional, word.traditional);

      await app.Store.togglePersonal(savedWord);
      expect(app.Store.isPersonal(word), isFalse);
      expect(app.Store.personalWords, isEmpty);
    },
  );

  test('upserts custom words by ID and persists removal', () async {
    SharedPreferences.setMockInitialValues({});
    await app.Store.load();
    final first = app.Vocab(
      id: 'custom-id',
      hanzi: '旧词',
      pinyin: 'jiu ci',
      meaning: 'Old',
      level: 0,
      custom: true,
    );
    final replacement = app.Vocab(
      id: 'custom-id',
      hanzi: '新词',
      pinyin: 'xin ci',
      meaning: 'New',
      level: 0,
      custom: true,
    );

    await app.Store.upsert(first);
    await app.Store.upsert(replacement);
    expect(app.Store.custom.value, hasLength(1));
    expect(app.Store.custom.value.single.hanzi, '新词');

    await app.Store.load();
    expect(app.Store.custom.value.single.meaning, 'New');
    await app.Store.remove('custom-id');
    await app.Store.load();
    expect(app.Store.custom.value, isEmpty);
  });

  test('sync code restores study progress and clears user data', () async {
    SharedPreferences.setMockInitialValues({});
    await app.Store.load();
    final word = app.Vocab(
      id: 'sync-word',
      hanzi: '同步',
      pinyin: 'tongbu',
      meaning: 'Sync',
      level: 0,
      custom: true,
    );
    final schedule = app.Srs(
      interval: 2,
      reps: 1,
      due: DateTime.utc(2026, 10, 23),
    );
    await app.Store.upsert(word);
    await app.Store.putSrs(word.id, schedule);
    await app.Store.setMaterialCompleted('audio:lesson.mp3', true);
    final code = app.Store.createSyncCode();

    await app.Store.clearAll();
    expect(app.Store.custom.value, isEmpty);
    expect(app.Store.completedMaterials.value, isEmpty);

    await app.Store.restoreSyncCode(code);
    expect(app.Store.custom.value.single.id, word.id);
    expect(app.Store.srs.value[word.id]?.interval, 2);
    expect(app.Store.completedMaterials.value, contains('audio:lesson.mp3'));
  });

  test('typing practice accepts simplified or listed traditional forms', () {
    final word = app.Vocab(
      id: '爱',
      hanzi: '爱',
      traditional: '愛 / 爱',
      pinyin: 'ài',
      meaning: 'Yêu',
      level: 1,
    );

    expect(app.matchesTypingAnswer(word, '爱'), isTrue);
    expect(app.matchesTypingAnswer(word, ' 愛 '), isTrue);
    expect(app.matchesTypingAnswer(word, 'ai'), isFalse);
    expect(app.matchesTypingAnswer(word, ''), isFalse);
  });

  test('scores answers without awarding points for incorrect responses', () {
    final correct = scoreAnswer(answer: '你好', expected: '你好');
    expect(correct.correct, isTrue);
    expect(correct.points, 10);

    final incorrect = scoreAnswer(answer: '再见', expected: '你好');
    expect(incorrect.correct, isFalse);
    expect(incorrect.points, 0);
  });

  test(
    'detects listening and exercise files from the asset manifest',
    () async {
      final library = StudyMaterialLibrary.instance;
      await library.load();
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final expectedPaths = assetManifest
          .listAssets()
          .where(
            (path) =>
                (path.startsWith('assets/audio/') &&
                    path.toLowerCase().endsWith('.mp3')) ||
                (path.startsWith('assets/documents/') &&
                    path.toLowerCase().endsWith('.pdf')),
          )
          .toSet();
      final detectedPaths = library.materials
          .where((material) => material.source != null)
          .map((material) => 'assets/${material.source}')
          .toSet();

      expect(detectedPaths, expectedPaths);
      expect(
        library.materialsOfType('audio').length,
        expectedPaths
            .where((path) => path.toLowerCase().endsWith('.mp3'))
            .length,
      );
      expect(
        library.materialsOfType('pdf').length,
        expectedPaths
            .where((path) => path.toLowerCase().endsWith('.pdf'))
            .length,
      );
      expect(
        library.materials.every((material) => material.isAvailable),
        isTrue,
      );
    },
  );

  test('matches an exercise PDF to the listening lesson code', () async {
    const audio = StudyMaterial(
      id: 'audio',
      title: 'Bài nghe HSK 1 · H10901',
      fileName: 'H10901.mp3',
      type: 'audio',
      category: 'listening',
      level: 1,
    );
    const exercise = StudyMaterial(
      id: 'exercise',
      title: 'Đề HSK 1 · H10901',
      fileName: 'H10901.pdf',
      type: 'pdf',
      category: 'exam',
      level: 1,
      source: 'documents/H10901.pdf',
    );

    expect(
      StudyMaterialLibrary.matchingExercise(audio, [exercise]),
      same(exercise),
    );
    const genericAudio = StudyMaterial(
      id: 'generic-audio',
      title: 'Listening practice',
      fileName: 'practice_01.mp3',
      type: 'audio',
      category: 'listening',
      level: null,
    );
    const genericExercise = StudyMaterial(
      id: 'generic-exercise',
      title: 'Practice 01',
      fileName: 'practice_01.pdf',
      type: 'pdf',
      category: 'course',
      level: null,
      source: 'documents/practice_01.pdf',
    );
    expect(
      StudyMaterialLibrary.matchingExercise(genericAudio, [genericExercise]),
      same(genericExercise),
    );
  });

  testWidgets('listening lesson shows audio and PDF side by side', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AudioMaterialPlayer(
          material: StudyMaterial(
            id: 'audio',
            title: 'Audio sample',
            fileName: 'audio_sample.mp3',
            type: 'audio',
            category: 'listening',
            level: 1,
            source: 'audio/audio_sample.mp3',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final audioHeading = find.text('File nghe');
    final pdfHeading = find.text('File PDF');
    expect(audioHeading, findsOneWidget);
    expect(pdfHeading, findsOneWidget);
    expect(
      tester.getCenter(audioHeading).dx,
      lessThan(tester.getCenter(pdfHeading).dx),
    );
    expect(find.text('Đánh dấu hoàn thành'), findsOneWidget);
  });
}
