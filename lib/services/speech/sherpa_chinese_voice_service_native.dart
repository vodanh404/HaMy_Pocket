import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class SherpaChineseVoiceService {
  SherpaChineseVoiceService._();

  static final instance = SherpaChineseVoiceService._();
  static const modelRepository =
      'https://huggingface.co/csukuangfj/vits-zh-aishell3/resolve/main';
  static const _modelName = 'vits-aishell3.int8.onnx';
  static const _lexiconName = 'lexicon.txt';
  static const _tokensName = 'tokens.txt';

  final ValueNotifier<String?> downloadStatus = ValueNotifier<String?>(null);
  final AudioPlayer _player = AudioPlayer();
  Future<sherpa.OfflineTts>? _ttsFuture;

  Future<bool> get isInstalled async {
    if (kIsWeb) return false;
    final directory = await _modelDirectory();
    final files = [
      File(_join(directory.path, _modelName)),
      File(_join(directory.path, _lexiconName)),
      File(_join(directory.path, _tokensName)),
    ];
    for (final file in files) {
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return true;
  }

  Future<void> downloadVoicePack() async {
    if (kIsWeb) {
      throw UnsupportedError('Sherpa ONNX voices are not supported on web.');
    }
    final directory = await _modelDirectory();
    await directory.create(recursive: true);
    final files = [_modelName, _lexiconName, _tokensName];
    final client = http.Client();
    try {
      for (var index = 0; index < files.length; index++) {
        final name = files[index];
        final destination = File(_join(directory.path, name));
        if (await destination.exists() && await destination.length() > 0) {
          continue;
        }
        if (await destination.exists()) await destination.delete();

        downloadStatus.value = 'Đang tải $name (${index + 1}/${files.length})';
        final request = http.Request(
          'GET',
          Uri.parse('$modelRepository/$name'),
        );
        final response = await client.send(request);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Không tải được mô hình giọng đọc (HTTP ${response.statusCode}).',
            uri: request.url,
          );
        }

        final expectedLength = response.contentLength;
        final temporary = File('${destination.path}.part');
        try {
          await response.stream.pipe(temporary.openWrite());
          final downloadedLength = await temporary.length();
          if (downloadedLength == 0 ||
              (expectedLength != null && downloadedLength != expectedLength)) {
            throw const HttpException(
              'Tệp mô hình giọng đọc bị thiếu hoặc không đầy đủ.',
            );
          }
          await temporary.rename(destination.path);
        } on Object {
          if (await temporary.exists()) await temporary.delete();
          rethrow;
        }
      }
    } finally {
      client.close();
      downloadStatus.value = null;
    }
  }

  Future<void> speak(String text, {required int speaker}) async {
    if (text.trim().isEmpty) return;
    if (speaker < 0 || speaker >= 3) {
      throw RangeError.range(speaker, 0, 2, 'speaker');
    }

    final tts = await _getTts();
    final audio = tts.generate(text: text, sid: speaker);
    if (audio.samples.isEmpty) {
      throw StateError('Sherpa ONNX không tạo được âm thanh cho câu này.');
    }
    await _player.stop();
    await _player.play(
      BytesSource(_encodeWave(audio.samples, audio.sampleRate)),
    );
  }

  Future<void> dispose() async {
    final pendingTts = _ttsFuture;
    if (pendingTts != null) {
      final tts = await pendingTts;
      tts.free();
    }
    await _player.dispose();
    downloadStatus.dispose();
  }

  Future<sherpa.OfflineTts> _createTts() async {
    await downloadVoicePack();
    sherpa.initBindings();
    final directory = await _modelDirectory();
    final tts = sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: _join(directory.path, _modelName),
            lexicon: _join(directory.path, _lexiconName),
            tokens: _join(directory.path, _tokensName),
          ),
          numThreads: 2,
        ),
      ),
    );
    if (tts.numSpeakers < 3) {
      tts.free();
      throw StateError(
        'Mô hình hiện tại không có đủ ba giọng đọc để lựa chọn.',
      );
    }
    return tts;
  }

  Future<sherpa.OfflineTts> _getTts() async {
    final pendingTts = _ttsFuture;
    if (pendingTts != null) return pendingTts;

    final future = _createTts();
    _ttsFuture = future;
    try {
      return await future;
    } on Object {
      _ttsFuture = null;
      rethrow;
    }
  }

  Future<Directory> _modelDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(_join(supportDirectory.path, 'sherpa_zh_aishell3'));
  }

  String _join(String directory, String file) =>
      '$directory${Platform.pathSeparator}$file';

  Uint8List _encodeWave(Float32List samples, int sampleRate) {
    final bytesPerSample = 2;
    final dataLength = samples.length * bytesPerSample;
    final data = ByteData(44 + dataLength);
    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
    data.setUint16(32, bytesPerSample, Endian.little);
    data.setUint16(34, bytesPerSample * 8, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, dataLength, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i].clamp(-1.0, 1.0);
      data.setInt16(
        44 + i * bytesPerSample,
        (sample * (sample < 0 ? 32768 : 32767)).round(),
        Endian.little,
      );
    }
    return data.buffer.asUint8List();
  }
}
