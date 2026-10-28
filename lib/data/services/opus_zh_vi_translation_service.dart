import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';

import 'opus_model_download_service.dart';
import 'opus_onnx_runtime_stub.dart'
    if (dart.library.ffi) 'opus_onnx_runtime_ffi.dart';

class OpusZhViTranslationService {
  OpusZhViTranslationService._();

  static final instance = OpusZhViTranslationService._();
  static const _sourceTokenizerAsset = 'assets/opus_zh_vi_onnx/source.spm';
  static const _targetTokenizerAsset = 'assets/opus_zh_vi_onnx/target.spm';
  static const _modelVocabularyAsset = 'assets/opus_zh_vi_onnx/vocab.json';
  static const _maxChunkLength = 240;

  Future<void>? _tokenizersLoading;
  SentencePieceTokenizer? _sourceTokenizer;
  SentencePieceTokenizer? _targetTokenizer;
  Map<String, int>? _modelVocabulary;
  Map<int, int>? _modelTargetToTokenizerIds;

  Future<bool> get isModelDownloaded =>
      OpusModelDownloadService.instance.isInstalled;

  Future<String> translate(String text) async {
    final query = text.trim();
    if (query.isEmpty) {
      throw const FormatException('Hãy nhập từ hoặc câu tiếng Trung cần dịch.');
    }
    if (!containsChinese(query)) {
      throw const FormatException(
        'Model Opus zh-vi chỉ hỗ trợ dịch từ tiếng Trung sang tiếng Việt.',
      );
    }
    if (!await isModelDownloaded) {
      throw StateError(
        'Hãy tải mô hình dịch Trung–Việt trong mục Dữ liệu và AI.',
      );
    }

    await _loadTokenizers();
    final sourceTokenizer = _sourceTokenizer!;
    final targetTokenizer = _targetTokenizer!;
    final modelVocabulary = _modelVocabulary!;
    final translations = <String>[];
    for (final chunk in splitTextForTranslation(query)) {
      final tokenizerIds = sourceTokenizer
          .encode(chunk, addSpecialTokens: false)
          .ids
          .toList();
      if (tokenizerIds.isEmpty) {
        throw const FormatException('Không thể mã hóa nội dung tiếng Trung.');
      }
      final eosId = sourceTokenizer.vocab.eosId;
      if (tokenizerIds.last != eosId) tokenizerIds.add(eosId);
      final sourceIds = mapSourceTokenIds(
        tokenizerIds,
        sourceTokenizer,
        modelVocabulary,
      );

      final outputIds = await runOpusOnnx(sourceIds);
      final result = targetTokenizer
          .decode(_targetIdsFromModel(outputIds, targetTokenizer))
          .trim();
      if (result.isEmpty) {
        throw const FormatException('Model Opus không tạo được bản dịch.');
      }
      translations.add(result);
    }
    return translations.join('\n');
  }

  static List<int> mapSourceTokenIds(
    List<int> tokenIds,
    SentencePieceTokenizer tokenizer,
    Map<String, int> modelVocabulary,
  ) {
    final unknownId = modelVocabulary['<unk>'];
    if (unknownId == null) {
      throw const FormatException(
        'Từ điển ONNX không có mã token không xác định.',
      );
    }
    return [
      for (final id in tokenIds)
        modelVocabulary[tokenizer.vocab.idToPiece(id)] ?? unknownId,
    ];
  }

  static List<int> mapTargetTokenIds(
    List<int> modelIds,
    SentencePieceTokenizer tokenizer,
    Map<String, int> modelVocabulary,
  ) {
    final tokenizerIds = <int, int>{};
    for (var id = 0; id < tokenizer.vocab.size; id++) {
      final modelId = modelVocabulary[tokenizer.vocab.idToPiece(id)];
      if (modelId != null) tokenizerIds[modelId] = id;
    }
    return [
      for (final id in modelIds) tokenizerIds[id] ?? tokenizer.vocab.unkId,
    ];
  }

  List<int> _targetIdsFromModel(
    List<int> modelIds,
    SentencePieceTokenizer tokenizer,
  ) {
    final tokenizerIds = _modelTargetToTokenizerIds!;
    return [
      for (final id in modelIds) tokenizerIds[id] ?? tokenizer.vocab.unkId,
    ];
  }

  static bool containsChinese(String text) =>
      RegExp(r'[\u3400-\u9fff]').hasMatch(text);

  static List<String> splitTextForTranslation(String text) {
    final chunks = <String>[];
    var current = StringBuffer();
    var currentLength = 0;

    void flush() {
      if (currentLength == 0) return;
      chunks.add(current.toString());
      current = StringBuffer();
      currentLength = 0;
    }

    for (final sentence in text.split(RegExp(r'(?<=[。！？!?；;\n])'))) {
      final runes = sentence.runes.toList();
      if (runes.isEmpty) continue;
      if (currentLength + runes.length > _maxChunkLength) flush();

      if (runes.length <= _maxChunkLength) {
        current.write(sentence);
        currentLength += runes.length;
        continue;
      }

      for (var offset = 0; offset < runes.length;) {
        final end = (offset + _maxChunkLength).clamp(0, runes.length);
        current.write(String.fromCharCodes(runes.sublist(offset, end)));
        currentLength = end - offset;
        offset = end;
        flush();
      }
    }
    flush();
    return chunks;
  }

  Future<void> _loadTokenizers() async {
    final existingLoad = _tokenizersLoading;
    if (existingLoad != null) return existingLoad;

    final loading = _loadTokenizerAssets();
    _tokenizersLoading = loading;
    try {
      await loading;
    } on Object {
      _tokenizersLoading = null;
      rethrow;
    }
  }

  Future<void> _loadTokenizerAssets() async {
    final sourceData = await rootBundle.load(_sourceTokenizerAsset);
    final targetData = await rootBundle.load(_targetTokenizerAsset);
    final vocabularyData = await rootBundle.load(_modelVocabularyAsset);
    _sourceTokenizer = SentencePieceTokenizer.fromBytes(
      sourceData.buffer.asUint8List(
        sourceData.offsetInBytes,
        sourceData.lengthInBytes,
      ),
    );
    _targetTokenizer = SentencePieceTokenizer.fromBytes(
      targetData.buffer.asUint8List(
        targetData.offsetInBytes,
        targetData.lengthInBytes,
      ),
    );
    final decodedVocabulary = jsonDecode(
      utf8.decode(
        vocabularyData.buffer.asUint8List(
          vocabularyData.offsetInBytes,
          vocabularyData.lengthInBytes,
        ),
      ),
    );
    if (decodedVocabulary is! Map<String, dynamic> ||
        decodedVocabulary.values.any((id) => id is! int)) {
      throw const FormatException('Từ điển token ONNX không hợp lệ.');
    }
    _modelVocabulary = decodedVocabulary.cast<String, int>();
    final targetIds = <int, int>{};
    for (var id = 0; id < _targetTokenizer!.vocab.size; id++) {
      final piece = _targetTokenizer!.vocab.idToPiece(id);
      final modelId = _modelVocabulary![piece];
      if (modelId != null) targetIds[modelId] = id;
    }
    _modelTargetToTokenizerIds = targetIds;
  }
}
