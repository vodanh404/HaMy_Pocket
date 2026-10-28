import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

class QwenChatService {
  QwenChatService._();

  static final instance = QwenChatService._();
  static const modelName = 'Qwen2.5-0.5B-Instruct Q4_K_M';
  static const _modelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const _modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/'
      '9217f5db79a29953eb74d5343926648285ec7e67/'
      'qwen2.5-0.5b-instruct-q4_k_m.gguf';

  final ValueNotifier<String?> downloadStatus = ValueNotifier<String?>(null);
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);
  LlamaEngine? _engine;
  ChatSession? _session;
  Future<void>? _downloadTask;
  Future<void>? _loadTask;

  Future<bool> get isModelDownloaded async {
    final file = await _modelFile();
    if (!await file.exists() || await file.length() < 300 * 1024 * 1024) {
      return false;
    }
    final handle = await file.open();
    try {
      final header = await handle.read(4);
      return header.length == 4 && String.fromCharCodes(header) == 'GGUF';
    } finally {
      await handle.close();
    }
  }

  Future<void> downloadModel() {
    final activeDownload = _downloadTask;
    if (activeDownload != null) return activeDownload;

    final task = _downloadModel();
    _downloadTask = task;
    return task.whenComplete(() => _downloadTask = null);
  }

  Future<void> ensureModelReady() async {
    if (!await isModelDownloaded) await downloadModel();
    await loadModel();
  }

  Future<void> loadModel() {
    if (_engine != null) return Future<void>.value();
    final activeLoad = _loadTask;
    if (activeLoad != null) return activeLoad;

    final task = _loadModel();
    _loadTask = task;
    return task.whenComplete(() => _loadTask = null);
  }

  void startConversation({
    required String systemPrompt,
    required String openingMessage,
  }) {
    final engine = _engine;
    if (engine == null) {
      throw StateError('Tải và khởi động mô hình Qwen trước khi chat.');
    }
    final session = ChatSession(engine, systemPrompt: systemPrompt);
    session.addMessage(
      LlamaChatMessage.fromText(
        role: LlamaChatRole.assistant,
        text: openingMessage,
      ),
    );
    _session = session;
  }

  Stream<String> reply(String message) async* {
    final session = _session;
    if (session == null) {
      throw StateError('Chưa bắt đầu cuộc hội thoại theo chủ đề.');
    }
    await for (final chunk in session.create(
      [LlamaTextContent(message)],
      params: const GenerationParams(maxTokens: 160, temp: 0.7),
      enableThinking: false,
    )) {
      if (chunk.text.isNotEmpty) yield chunk.text;
    }
  }

  Future<void> _downloadModel() async {
    final destination = await _modelFile();
    await destination.parent.create(recursive: true);
    if (await destination.exists()) await destination.delete();
    final temporary = File('${destination.path}.part');
    if (await temporary.exists()) await temporary.delete();

    final client = http.Client();
    final request = http.Request('GET', Uri.parse(_modelUrl));
    downloadStatus.value = 'Đang tải $modelName';
    downloadProgress.value = 0;
    try {
      final response = await client.send(request);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Không tải được mô hình Qwen (HTTP ${response.statusCode}).',
          uri: request.url,
        );
      }

      final expectedLength = response.contentLength;
      var receivedLength = 0;
      final sink = temporary.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedLength += chunk.length;
          if (expectedLength != null && expectedLength > 0) {
            downloadProgress.value = (receivedLength / expectedLength)
                .clamp(0.0, 1.0)
                .toDouble();
          }
        }
        await sink.flush();
        await sink.close();
      } on Object {
        await sink.close();
        rethrow;
      }

      if (receivedLength < 300 * 1024 * 1024 ||
          (expectedLength != null && receivedLength != expectedLength)) {
        throw const HttpException(
          'Tệp mô hình Qwen bị thiếu hoặc không đầy đủ. Hãy thử tải lại.',
        );
      }
      final handle = await temporary.open();
      List<int> header;
      try {
        header = await handle.read(4);
      } finally {
        await handle.close();
      }
      if (String.fromCharCodes(header) != 'GGUF') {
        throw const FormatException('Tệp tải về không phải mô hình GGUF.');
      }
      await temporary.rename(destination.path);
    } on Object {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    } finally {
      client.close();
      downloadStatus.value = null;
      downloadProgress.value = null;
    }
  }

  Future<void> _loadModel() async {
    final file = await _modelFile();
    if (!await isModelDownloaded) {
      throw StateError('Chưa tải xong mô hình Qwen.');
    }

    _engine = await LlamaEngine.load(
      LlamaModel(ModelSource.path(file.path)),
      backend: LlamaBackend(),
      params: const ModelParams(contextSize: 2048),
    );
  }

  Future<File> _modelFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(
      '${supportDirectory.path}${Platform.pathSeparator}qwen2_5_0_5b'
      '${Platform.pathSeparator}$_modelFileName',
    );
  }
}
