import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OpusModelDownloadService {
  OpusModelDownloadService._();

  static final instance = OpusModelDownloadService._();
  static const modelName = 'OPUS-MT Trung–Việt ONNX int8';
  static const _repository = 'R4kSo1997/opus-mt-zh-vi-onnx-int8';
  static const _revision = '95cbd9ca95e7595aeb80163e0ca469e5d475f974';
  static const encoderFileName = 'encoder_model_quantized.onnx';
  static const decoderFileName = 'decoder_model_quantized.onnx';
  static const _estimatedDownloadBytes = 230 * 1024 * 1024;

  final ValueNotifier<String?> downloadStatus = ValueNotifier<String?>(null);
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);
  Future<void>? _downloadTask;

  Future<bool> get isInstalled async =>
      await _isUsable(await encoderFile) && await _isUsable(await decoderFile);

  Future<File> get encoderFile async => _modelFile(encoderFileName);

  Future<File> get decoderFile async => _modelFile(decoderFileName);

  Future<void> downloadModel() {
    final activeDownload = _downloadTask;
    if (activeDownload != null) return activeDownload;
    final task = _download();
    _downloadTask = task;
    return task.whenComplete(() => _downloadTask = null);
  }

  Future<void> _download() async {
    final client = http.Client();
    var completedBytes = 0;
    downloadProgress.value = 0;
    try {
      for (final fileName in const [encoderFileName, decoderFileName]) {
        final destination = await _modelFile(fileName);
        if (await _isUsable(destination)) {
          completedBytes += await destination.length();
          continue;
        }
        await destination.parent.create(recursive: true);
        final temporary = File('${destination.path}.part');
        if (await temporary.exists()) await temporary.delete();

        final request = http.Request(
          'GET',
          Uri.https(
            'huggingface.co',
            '/$_repository/resolve/$_revision/$fileName',
          ),
        );
        downloadStatus.value = 'Đang tải $modelName · $fileName';
        final response = await client.send(request);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Không tải được mô hình dịch (HTTP ${response.statusCode}).',
            uri: request.url,
          );
        }

        var received = 0;
        final sink = temporary.openWrite();
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            downloadProgress.value =
                ((completedBytes + received) / _estimatedDownloadBytes)
                    .clamp(0.0, 0.99)
                    .toDouble();
          }
          await sink.flush();
          await sink.close();
        } on Object {
          await sink.close();
          rethrow;
        }

        if (received < 10 * 1024 * 1024 ||
            (response.contentLength != null &&
                received != response.contentLength)) {
          throw HttpException(
            'Tệp mô hình $fileName bị thiếu hoặc không đầy đủ.',
          );
        }
        if (await destination.exists()) await destination.delete();
        await temporary.rename(destination.path);
        completedBytes += received;
      }

      if (!await isInstalled) {
        throw StateError('Bộ mô hình dịch tải về không hợp lệ.');
      }
      downloadProgress.value = 1;
    } on Object {
      for (final fileName in const [encoderFileName, decoderFileName]) {
        final temporary = File('${(await _modelFile(fileName)).path}.part');
        if (await temporary.exists()) await temporary.delete();
      }
      rethrow;
    } finally {
      client.close();
      downloadStatus.value = null;
    }
  }

  Future<File> _modelFile(String fileName) async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(
      '${supportDirectory.path}${Platform.pathSeparator}opus_zh_vi_onnx'
      '${Platform.pathSeparator}$fileName',
    );
  }

  static Future<bool> _isUsable(File file) async =>
      await file.exists() && await file.length() > 10 * 1024 * 1024;
}
