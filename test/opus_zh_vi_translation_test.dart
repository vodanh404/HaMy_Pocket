import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:hamy_poket/data/services/opus_zh_vi_translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory supportDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'hamy_pocket_opus_test_',
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

  test('SentencePiece assets encode and decode Chinese', () async {
    final data = await rootBundle.load('assets/opus_zh_vi_onnx/source.spm');
    final tokenizer = SentencePieceTokenizer.fromBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final ids = tokenizer.encode('保护环境', addSpecialTokens: false).ids;

    expect(ids, isNotEmpty);
    expect(tokenizer.decode(ids.toList()).trim(), '保护环境');
  });

  test('target SentencePiece model preserves Vietnamese output text', () async {
    final data = await rootBundle.load('assets/opus_zh_vi_onnx/target.spm');
    final tokenizer = SentencePieceTokenizer.fromBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    const expected = 'Tài chính Singapore';
    final ids = tokenizer.encode(expected, addSpecialTokens: false).ids;

    expect(tokenizer.decode(ids.toList()).trim(), expected);
  });

  test('maps tokenizer IDs to the ONNX vocabulary and back', () async {
    final sourceData = await rootBundle.load(
      'assets/opus_zh_vi_onnx/source.spm',
    );
    final targetData = await rootBundle.load(
      'assets/opus_zh_vi_onnx/target.spm',
    );
    final source = SentencePieceTokenizer.fromBytes(
      sourceData.buffer.asUint8List(
        sourceData.offsetInBytes,
        sourceData.lengthInBytes,
      ),
    );
    final target = SentencePieceTokenizer.fromBytes(
      targetData.buffer.asUint8List(
        targetData.offsetInBytes,
        targetData.lengthInBytes,
      ),
    );
    final vocabularyData = await rootBundle.load(
      'assets/opus_zh_vi_onnx/vocab.json',
    );
    final modelVocabulary = (jsonDecode(
      utf8.decode(
        vocabularyData.buffer.asUint8List(
          vocabularyData.offsetInBytes,
          vocabularyData.lengthInBytes,
        ),
      ),
    ) as Map<String, dynamic>).cast<String, int>();

    final sourceIds = source.encode('你好', addSpecialTokens: false).ids;
    final modelSourceIds = OpusZhViTranslationService.mapSourceTokenIds(
      sourceIds,
      source,
      modelVocabulary,
    );
    expect(modelSourceIds, isNot(equals(sourceIds)));

    const expected = 'Tài chính Singapore';
    final targetIds = target
        .encode(expected, addSpecialTokens: false)
        .ids
        .toList();
    final modelTargetIds = [
      for (final id in targetIds) modelVocabulary[target.vocab.idToPiece(id)]!,
    ];
    final decodedTargetIds = OpusZhViTranslationService.mapTargetTokenIds(
      modelTargetIds,
      target,
      modelVocabulary,
    );
    expect(decodedTargetIds, targetIds);
    expect(target.decode(decodedTargetIds).trim(), expected);
  });

  test('does not allow translating Vietnamese with the zh-to-vi model', () {
    expect(OpusZhViTranslationService.containsChinese('保护环境'), isTrue);
    expect(OpusZhViTranslationService.containsChinese('Xin chào'), isFalse);
  });

  test(
    'splits long translations at sentence boundaries within model limits',
    () {
      final text = '${'保护环境。' * 80}尾巴';
      final chunks = OpusZhViTranslationService.splitTextForTranslation(text);

      expect(chunks.join(), text);
      expect(chunks.every((chunk) => chunk.runes.length <= 240), isTrue);
      expect(chunks.first.endsWith('。'), isTrue);
    },
  );

  test('safely splits an overlong sentence without losing Unicode text', () {
    final text = '${'保护环境' * 70}。';
    final chunks = OpusZhViTranslationService.splitTextForTranslation(text);

    expect(chunks.join(), text);
    expect(chunks, hasLength(2));
    expect(chunks.every((chunk) => chunk.runes.length <= 240), isTrue);
  });

  test(
    'rejects blank and unsupported input before loading ONNX models',
    () async {
      final service = OpusZhViTranslationService.instance;

      await expectLater(service.translate('  '), throwsFormatException);
      await expectLater(service.translate('Xin chào'), throwsFormatException);
    },
  );

  test(
    'asks users to download the optional model before translating',
    () async {
      final service = OpusZhViTranslationService.instance;

      expect(await service.isModelDownloaded, isFalse);
      await expectLater(service.translate('你好'), throwsStateError);
    },
  );

  test(
    'translates a complete Chinese sentence',
    () async {
      const sentence = '我今天早上去了北京，因为我想看看天安门。';
      final translation = await OpusZhViTranslationService.instance.translate(
        sentence,
      );

      expect(translation.split(RegExp(r'\s+')).length, greaterThan(5));
      expect(translation, contains('Bắc Kinh'));
      expect(translation, contains('sáng nay'));
    },
    skip: 'Requires downloading the optional ONNX pack.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
