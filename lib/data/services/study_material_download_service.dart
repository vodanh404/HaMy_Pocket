import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class StudyMaterialDownloadService {
  StudyMaterialDownloadService._();

  static final instance = StudyMaterialDownloadService._();
  static const estimatedDownloadBytes = 635 * 1024 * 1024;
  static const _repository = 'vodanh404/data_HaMy_Pocket';
  static const _branch = 'main';
  static const _installedFileName = '.installed-study-materials.json';

  final ValueNotifier<String?> downloadStatus = ValueNotifier<String?>(null);
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);
  Future<void>? _downloadTask;

  Future<Directory> get downloadedDirectory => _downloadDirectory();

  Future<bool> get isInstalled async {
    final root = await _downloadDirectory();
    final marker = File(
      '${root.path}${Platform.pathSeparator}$_installedFileName',
    );
    if (!await marker.exists()) return false;

    final dynamic decoded;
    try {
      decoded = jsonDecode(await marker.readAsString());
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed downloaded study material index: $error');
      return false;
    }
    if (decoded is! List<dynamic> || decoded.isEmpty) return false;
    for (final entry in decoded) {
      if (entry is! String || !_isSafeRepositoryPath(entry)) return false;
      final file = File(_localPath(root, entry));
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return true;
  }

  Future<void> downloadStudyMaterials() {
    final activeDownload = _downloadTask;
    if (activeDownload != null) return activeDownload;
    final task = _download();
    _downloadTask = task;
    return task.whenComplete(() => _downloadTask = null);
  }

  Future<void> _download() async {
    final root = await _downloadDirectory();
    await root.create(recursive: true);
    final marker = File(
      '${root.path}${Platform.pathSeparator}$_installedFileName',
    );
    if (await marker.exists()) await marker.delete();
    final client = http.Client();
    downloadStatus.value = 'Đang lấy danh sách học liệu...';
    downloadProgress.value = 0;

    try {
      final treeRequest = http.Request(
        'GET',
        Uri.https('api.github.com', '/repos/$_repository/git/trees/$_branch', {
          'recursive': '1',
        }),
      )..headers['Accept'] = 'application/vnd.github+json';
      final treeResponse = await client.send(treeRequest);
      if (treeResponse.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Không lấy được danh sách học liệu (HTTP ${treeResponse.statusCode}).',
          uri: treeRequest.url,
        );
      }

      final decodedTree = jsonDecode(await treeResponse.stream.bytesToString());
      if (decodedTree is! Map<String, dynamic> ||
          decodedTree['tree'] is! List<dynamic> ||
          decodedTree['sha'] is! String) {
        throw const FormatException(
          'Danh sách học liệu trên GitHub không hợp lệ.',
        );
      }
      final revision = decodedTree['sha'] as String;
      if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(revision)) {
        throw const FormatException(
          'Phiên bản học liệu trên GitHub không hợp lệ.',
        );
      }
      final files = <String>[
        for (final entry in decodedTree['tree'] as List<dynamic>)
          if (entry is Map<String, dynamic> &&
              entry['type'] == 'blob' &&
              entry['path'] is String &&
              _isStudyMaterialPath(entry['path'] as String))
            entry['path'] as String,
      ]..sort();
      if (files.isEmpty) {
        throw StateError('Kho dữ liệu chưa có tệp audio hoặc PDF.');
      }

      var completedBytes = 0;
      for (final path in files) {
        final destination = File(_localPath(root, path));
        if (await destination.exists() && await destination.length() > 0) {
          completedBytes += await destination.length();
          continue;
        }

        await destination.parent.create(recursive: true);
        final temporary = File('${destination.path}.part');
        if (await temporary.exists()) await temporary.delete();
        final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
        final request = http.Request(
          'GET',
          Uri.https(
            'media.githubusercontent.com',
            '/media/$_repository/$revision/$encodedPath',
          ),
        );
        downloadStatus.value =
            'Đang tải ${files.indexOf(path) + 1}/${files.length}: '
            '${path.split('/').last}';
        final response = await client.send(request);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Không tải được "$path" (HTTP ${response.statusCode}).',
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
                ((completedBytes + received) / estimatedDownloadBytes)
                    .clamp(0.0, 0.99)
                    .toDouble();
          }
          await sink.flush();
          await sink.close();
        } on Object {
          await sink.close();
          rethrow;
        }

        if (received == 0 ||
            (response.contentLength != null &&
                received != response.contentLength)) {
          throw HttpException('Tệp "$path" tải về không đầy đủ.');
        }
        await _validateDownloadedFile(temporary, path);
        if (await destination.exists()) await destination.delete();
        await temporary.rename(destination.path);
        completedBytes += received;
      }

      await marker.writeAsString(jsonEncode(files), flush: true);
      downloadProgress.value = 1;
    } on Object {
      if (await marker.exists()) await marker.delete();
      rethrow;
    } finally {
      client.close();
      downloadStatus.value = null;
    }
  }

  static bool _isStudyMaterialPath(String path) =>
      _isSafeRepositoryPath(path) &&
      path.startsWith('audio/') &&
      const {'.mp3', '.pdf'}.contains(_extension(path));

  static bool _isSafeRepositoryPath(String path) {
    final segments = path.split('/');
    return path.isNotEmpty &&
        !path.startsWith('/') &&
        segments.every(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        );
  }

  static String _localPath(Directory root, String repositoryPath) =>
      '${root.path}${Platform.pathSeparator}'
      '${repositoryPath.split('/').join(Platform.pathSeparator)}';

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot).toLowerCase();
  }

  static Future<Directory> _downloadDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'downloaded_study_materials',
    );
  }

  static Future<void> _validateDownloadedFile(File file, String path) async {
    if (await file.length() <= 132) {
      throw HttpException('Tệp "$path" không phải dữ liệu Git LFS đầy đủ.');
    }

    final handle = await file.open();
    late final List<int> header;
    try {
      header = await handle.read(5);
    } finally {
      await handle.close();
    }
    if (_extension(path) == '.pdf' &&
        String.fromCharCodes(header.take(4)) != '%PDF') {
      throw FormatException('Tệp "$path" không phải PDF hợp lệ.');
    }
    if (_extension(path) == '.mp3' &&
        !(String.fromCharCodes(header.take(3)) == 'ID3' ||
            (header.isNotEmpty && header.first == 0xff))) {
      throw FormatException('Tệp "$path" không phải MP3 hợp lệ.');
    }
  }
}
