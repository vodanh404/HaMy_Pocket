import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

const _encoderAsset = 'assets/opus_zh_vi_onnx/encoder_model.onnx';
const _decoderAsset = 'assets/opus_zh_vi_onnx/decoder_model.onnx';
const _decoderStartTokenId = 65000;
const _padTokenId = 65000;
const _eosTokenId = 0;
const _beamSize = 6;

class _Beam {
  const _Beam(this.tokens, this.logProbability);

  final List<int> tokens;
  final double logProbability;

  double get normalizedScore {
    final generatedLength = math.max(1, tokens.length - 1);
    final lengthPenalty = math.pow((5 + generatedLength) / 6, 1);
    return logProbability / lengthPenalty;
  }
}

class _BeamCandidate {
  const _BeamCandidate(this.tokens, this.logProbability);

  final List<int> tokens;
  final double logProbability;
}

class _OpusRuntime {
  OrtSession? encoder;
  OrtSession? decoder;
  Future<void>? _loading;

  Future<void> load() async {
    if (encoder != null && decoder != null) return;
    final currentLoad = _loading;
    if (currentLoad != null) return currentLoad;

    final loading = _loadModels();
    _loading = loading;
    try {
      await loading;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  Future<void> _loadModels() async {
    OrtEnv.instance.init();
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setInterOpNumThreads(1);
    try {
      encoder = await _loadSession(_encoderAsset, options);
      decoder = await _loadSession(_decoderAsset, options);
    } on Object {
      encoder?.release();
      decoder?.release();
      encoder = null;
      decoder = null;
      options.release();
      OrtEnv.instance.release();
      rethrow;
    }
    options.release();
  }

  Future<List<int>> translate(List<int> sourceIds) async {
    await load();
    final encoderSession = encoder!;
    final decoderSession = decoder!;
    final runOptions = OrtRunOptions();
    final encoderInputIds = OrtValueTensor.createTensorWithDataList(
      <List<int>>[sourceIds],
      [1, sourceIds.length],
    );
    final encoderMask = List<int>.filled(sourceIds.length, 1);
    final encoderAttentionMask = OrtValueTensor.createTensorWithDataList(
      <List<int>>[encoderMask],
      [1, encoderMask.length],
    );
    List<OrtValue?>? encoderOutputs;

    try {
      encoderOutputs = await encoderSession.runAsync(runOptions, {
        'input_ids': encoderInputIds,
        'attention_mask': encoderAttentionMask,
      });
      if (encoderOutputs == null ||
          encoderOutputs.isEmpty ||
          encoderOutputs.first is! OrtValueTensor) {
        throw StateError('Model Opus không trả về trạng thái bộ mã hóa.');
      }
      final hiddenStates = encoderOutputs.first as OrtValueTensor;
      final encoderValues = _encoderValues(hiddenStates.value);
      final encoderSequenceLength = encoderValues.length;
      final hiddenSize = (encoderValues.first as List).length;
      final initialHiddenState = Float32List(
        encoderSequenceLength * hiddenSize,
      );
      var hiddenIndex = 0;
      for (final position in encoderValues) {
        for (final value in (position as List).cast<num>()) {
          initialHiddenState[hiddenIndex++] = value.toDouble();
        }
      }

      final maxTokens = math.min(256, sourceIds.length * 3 + 16);
      var beams = <_Beam>[
        const _Beam([_decoderStartTokenId], 0),
      ];
      final completed = <_Beam>[];
      final logitsIndex = decoderSession.outputNames.indexWhere(
        (name) => name.contains('logits'),
      );
      if (logitsIndex < 0) {
        throw StateError('Model Opus không có đầu ra logits.');
      }

      for (var step = 0; step < maxTokens && beams.isNotEmpty; step++) {
        final batchSize = beams.length;
        final decoderIds = OrtValueTensor.createTensorWithDataList(
          beams.map((beam) => beam.tokens).toList(),
          [batchSize, beams.first.tokens.length],
        );
        final repeatedHiddenState = Float32List(
          batchSize * initialHiddenState.length,
        );
        for (var index = 0; index < batchSize; index++) {
          repeatedHiddenState.setRange(
            index * initialHiddenState.length,
            (index + 1) * initialHiddenState.length,
            initialHiddenState,
          );
        }
        final batchHiddenStates = OrtValueTensor.createTensorWithDataList(
          repeatedHiddenState,
          [batchSize, encoderSequenceLength, hiddenSize],
        );
        final batchAttentionMask = OrtValueTensor.createTensorWithDataList(
          <List<int>>[
            for (var index = 0; index < batchSize; index++)
              List<int>.filled(sourceIds.length, 1),
          ],
          [batchSize, sourceIds.length],
        );
        List<OrtValue?>? decoderOutputs;

        try {
          decoderOutputs = await decoderSession.runAsync(runOptions, {
            'input_ids': decoderIds,
            'encoder_hidden_states': batchHiddenStates,
            'encoder_attention_mask': batchAttentionMask,
          });
          if (decoderOutputs == null ||
              decoderOutputs.length <= logitsIndex ||
              decoderOutputs[logitsIndex] is! OrtValueTensor) {
            throw StateError('Model Opus không trả về logits hợp lệ.');
          }
          final logits = (decoderOutputs[logitsIndex] as OrtValueTensor).value;
          final batches = _logitBatches(logits);
          if (batches.length != batchSize) {
            throw StateError('Model Opus trả về số hàng logits không hợp lệ.');
          }

          final candidates = <_BeamCandidate>[];
          for (var index = 0; index < batchSize; index++) {
            candidates.addAll(
              _topCandidates(beams[index], batches[index], _beamSize),
            );
          }
          candidates.sort(
            (left, right) =>
                right.logProbability.compareTo(left.logProbability),
          );

          final nextBeams = <_Beam>[];
          for (final candidate in candidates) {
            if (candidate.tokens.last == _eosTokenId) {
              completed.add(_Beam(candidate.tokens, candidate.logProbability));
              continue;
            }
            nextBeams.add(_Beam(candidate.tokens, candidate.logProbability));
            if (nextBeams.length == _beamSize) break;
          }
          completed.sort(
            (left, right) =>
                right.normalizedScore.compareTo(left.normalizedScore),
          );
          if (completed.length > _beamSize) {
            completed.removeRange(_beamSize, completed.length);
          }
          beams = nextBeams;
        } finally {
          decoderIds.release();
          batchHiddenStates.release();
          batchAttentionMask.release();
          for (final output in decoderOutputs ?? const <OrtValue?>[]) {
            output?.release();
          }
        }
      }

      final finalCandidates = completed
        ..sort(
          (left, right) =>
              right.normalizedScore.compareTo(left.normalizedScore),
        );
      final best = finalCandidates.firstOrNull;
      if (best == null) {
        throw StateError(
          'Model Opus không hoàn tất được bản dịch. Hãy chọn đoạn ngắn hơn và thử lại.',
        );
      }
      final output = best.tokens.skip(1).toList();
      if (output.isNotEmpty && output.last == _eosTokenId) output.removeLast();
      return output;
    } finally {
      encoderInputIds.release();
      encoderAttentionMask.release();
      runOptions.release();
      for (final output in encoderOutputs ?? const <OrtValue?>[]) {
        output?.release();
      }
    }
  }

  List<dynamic> _encoderValues(dynamic values) {
    if (values is! List ||
        values.isEmpty ||
        values.first is! List ||
        (values.first as List).isEmpty) {
      throw const FormatException(
        'Model Opus trả về trạng thái bộ mã hóa sai định dạng.',
      );
    }
    return (values.first as List).cast<dynamic>();
  }

  List<List<num>> _logitBatches(dynamic rawLogits) {
    if (rawLogits is! List || rawLogits.isEmpty) {
      throw const FormatException('Model Opus trả về logits rỗng.');
    }
    return rawLogits.map((batch) {
      if (batch is! List || batch.isEmpty || batch.last is! List) {
        throw const FormatException('Model Opus trả về logits sai định dạng.');
      }
      return (batch.last as List).cast<num>();
    }).toList();
  }

  List<_BeamCandidate> _topCandidates(_Beam beam, List<num> scores, int count) {
    if (scores.isEmpty) {
      throw const FormatException('Model Opus không có điểm dự đoán.');
    }
    var maxScore = double.negativeInfinity;
    for (var index = 0; index < scores.length; index++) {
      final score = scores[index].toDouble();
      if (index != _padTokenId && score > maxScore) {
        maxScore = score;
      }
    }
    if (!maxScore.isFinite) {
      throw const FormatException('Model Opus không có token hợp lệ.');
    }

    var exponentialSum = 0.0;
    for (var index = 0; index < scores.length; index++) {
      if (index != _padTokenId) {
        exponentialSum += math.exp(scores[index].toDouble() - maxScore);
      }
    }
    final logNormalizer = maxScore + math.log(exponentialSum);
    final best = <(int, double)>[];
    for (var index = 0; index < scores.length; index++) {
      if (index == _padTokenId || _repeatsTrigram(beam.tokens, index)) {
        continue;
      }
      final score = scores[index].toDouble();
      if (best.length == count && score <= best.last.$2) continue;
      var insertion = best.indexWhere((candidate) => score > candidate.$2);
      if (insertion < 0) insertion = best.length;
      best.insert(insertion, (index, score));
      if (best.length > count) best.removeLast();
    }

    return [
      for (final (token, score) in best)
        _BeamCandidate([
          ...beam.tokens,
          token,
        ], beam.logProbability + score - logNormalizer),
    ];
  }

  bool _repeatsTrigram(List<int> tokens, int candidate) {
    if (tokens.length < 2) return false;
    final prefix = tokens.sublist(tokens.length - 2);
    for (var index = 0; index < tokens.length - 2; index++) {
      if (tokens[index] == prefix[0] &&
          tokens[index + 1] == prefix[1] &&
          tokens[index + 2] == candidate) {
        return true;
      }
    }
    return false;
  }
}

final _runtime = _OpusRuntime();

Future<List<int>> runOpusOnnx(List<int> sourceIds) =>
    _runtime.translate(sourceIds);

Future<OrtSession> _loadSession(
  String assetPath,
  OrtSessionOptions options,
) async {
  if (Platform.isWindows) {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return OrtSession.fromBuffer(bytes, options);
  }

  return OrtSession.fromFile(await _modelFile(assetPath), options);
}

Future<File> _modelFile(String assetPath) async {
  final directory = await getApplicationSupportDirectory();
  final modelDirectory = Directory(
    '${directory.path}${Platform.pathSeparator}opus_zh_vi_onnx',
  );
  await modelDirectory.create(recursive: true);
  final fileName = assetPath.split('/').last;
  final destination = File(
    '${modelDirectory.path}${Platform.pathSeparator}$fileName',
  );
  if (await destination.exists() && await destination.length() > 0) {
    return destination;
  }

  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final temporary = File('${destination.path}.tmp');
  await temporary.writeAsBytes(bytes, flush: true);
  if (await destination.exists()) await destination.delete();
  return temporary.rename(destination.path);
}
