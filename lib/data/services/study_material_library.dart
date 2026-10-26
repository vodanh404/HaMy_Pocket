import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/study_material.dart';

class StudyMaterialLibrary extends ChangeNotifier {
  StudyMaterialLibrary._();

  static final StudyMaterialLibrary instance = StudyMaterialLibrary._();
  static const _assetDirectories = ['assets/audio/', 'assets/documents/'];
  static const _storageFileName = 'study_materials.json';
  static final _supportedExtensions = {'.pdf', '.mp3', '.jpg', '.jpeg', '.png'};
  static const _supportedExamExtensions = {'.pdf', '.mp3'};

  final Map<String, StudyMaterial> _materials = {};
  bool _loaded = false;

  List<StudyMaterial> get materials => List.unmodifiable(_materials.values);

  Future<void> load() async {
    if (_loaded) return;

    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final assetPath in assetManifest.listAssets()) {
      if (!_assetDirectories.any(assetPath.startsWith)) continue;
      final extension = _extension(assetPath);
      if (extension != '.mp3' && extension != '.pdf') continue;

      final source = assetPath.substring('assets/'.length);
      final fileName = assetPath.split('/').last;
      final material = _classifyImportedFile(
        fileName,
        assetPath,
        extension,
        id: 'asset:$source',
        source: source,
      );
      _materials[material.id] = material;
    }

    final savedFile = await _savedFile();
    if (await savedFile.exists()) {
      dynamic saved;
      try {
        saved = jsonDecode(await savedFile.readAsString());
      } on FormatException catch (error) {
        debugPrint('Ignoring malformed imported material list: $error');
        saved = const <dynamic>[];
      }
      if (saved is! List<dynamic>) {
        debugPrint('Ignoring imported materials: expected a list.');
      } else {
        for (final item in saved) {
          if (item is! Map<String, dynamic>) {
            debugPrint(
              'Ignoring invalid imported material: expected an object.',
            );
            continue;
          }
          final StudyMaterial material;
          try {
            material = StudyMaterial.fromJson(item);
          } on TypeError catch (error) {
            debugPrint('Ignoring malformed imported material: $error');
            continue;
          } on FormatException catch (error) {
            debugPrint('Ignoring malformed imported material: $error');
            continue;
          }
          final localPath = material.localPath;
          if (localPath == null || !await File(localPath).exists()) continue;
          _materials[material.id] = material;
        }
      }
    }

    _loaded = true;
  }

  List<StudyMaterial> materialsOfType(String type) =>
      materials.where((material) => material.type == type).toList()
        ..sort(_compareMaterials);

  StudyMaterial? exerciseFor(StudyMaterial audio) =>
      matchingExercise(audio, _materials.values);

  static StudyMaterial? matchingExercise(
    StudyMaterial audio,
    Iterable<StudyMaterial> materials,
  ) {
    if (audio.type != 'audio') return null;
    final audioStem = _fileStem(audio.fileName);
    final lessonCode = _lessonCode(audio.fileName);

    final matches =
        materials
            .where(
              (material) =>
                  material.type == 'pdf' &&
                  material.isAvailable &&
                  (_fileStem(material.fileName) == audioStem ||
                      (lessonCode != null &&
                          _lessonCode(material.fileName) == lessonCode)),
            )
            .toList()
          ..sort((left, right) {
            final leftExact = _fileStem(left.fileName) == audioStem ? 0 : 1;
            final rightExact = _fileStem(right.fileName) == audioStem ? 0 : 1;
            final exactOrder = leftExact.compareTo(rightExact);
            return exactOrder != 0
                ? exactOrder
                : _compareMaterials(left, right);
          });
    return matches.isEmpty ? null : matches.first;
  }

  Future<int> importFiles(List<PlatformFile> files) async {
    return _importPaths(
      files.map((file) => (name: file.name, path: file.path)).toList(),
    );
  }

  Future<int> _importPaths(List<({String name, String? path})> files) async {
    await load();
    final directory = await getApplicationSupportDirectory();
    final storageDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}study_materials',
    );
    await storageDirectory.create(recursive: true);

    var imported = 0;
    for (final file in files) {
      final extension = _extension(file.name);
      if (!_supportedExtensions.contains(extension)) continue;
      final sourcePath = file.path;
      if (sourcePath == null) {
        throw StateError('Không thể đọc tệp "${file.name}" trên thiết bị này.');
      }

      final original = File(sourcePath);
      if (!await original.exists()) {
        throw FileSystemException('Không tìm thấy tệp đã chọn.', sourcePath);
      }

      final existing = _findByFileName(file.name);
      final material =
          existing ?? _classifyImportedFile(file.name, sourcePath, extension);
      final safeName = file.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final destination = File(
        '${storageDirectory.path}${Platform.pathSeparator}'
        '${material.id}_$safeName',
      );
      await original.copy(destination.path);
      _materials[material.id] = material.copyWith(localPath: destination.path);
      imported++;
    }

    await _saveImportedMaterials(storageDirectory.parent);
    notifyListeners();
    return imported;
  }

  Future<int> importDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw FileSystemException(
        'Không tìm thấy thư mục đã chọn.',
        directoryPath,
      );
    }

    final files = <({String name, String? path})>[];
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File ||
          !_supportedExamExtensions.contains(_extension(entity.path))) {
        continue;
      }
      files.add((
        name: entity.path.split(Platform.pathSeparator).last,
        path: entity.path,
      ));
    }
    return _importPaths(files);
  }

  Future<void> clearImported() async {
    await load();
    final directory = await getApplicationSupportDirectory();
    final importedDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}study_materials',
    );
    if (await importedDirectory.exists()) {
      await importedDirectory.delete(recursive: true);
    }
    final savedFile = await _savedFile();
    if (await savedFile.exists()) await savedFile.delete();
    _materials.clear();
    _loaded = false;
    await load();
    notifyListeners();
  }

  StudyMaterial? _findByFileName(String fileName) {
    final normalized = fileName.toLowerCase();
    for (final material in _materials.values) {
      if (material.fileName.toLowerCase() == normalized) return material;
    }
    return null;
  }

  StudyMaterial _classifyImportedFile(
    String fileName,
    String sourcePath,
    String extension, {
    String? id,
    String? source,
  }) {
    final joinedPath = '$sourcePath $fileName';
    final hskMatch = RegExp(
      r'HSK\s*([1-6])',
      caseSensitive: false,
    ).firstMatch(joinedPath);
    final testMatch = RegExp(
      r'^H([1-6])\d{4}',
      caseSensitive: false,
    ).firstMatch(fileName);
    final levelText = hskMatch?.group(1) ?? testMatch?.group(1);
    final level = levelText == null ? null : int.parse(levelText);
    final lowerPath = joinedPath.toLowerCase();
    final category = extension == '.mp3'
        ? 'listening'
        : lowerPath.contains('ngữ pháp') ||
              lowerPath.contains('ngu phap') ||
              lowerPath.contains('语法')
        ? 'theory'
        : lowerPath.contains('đề thi') ||
              lowerPath.contains('đề thử') ||
              RegExp(r'^h[1-6]\d{4}', caseSensitive: false).hasMatch(fileName)
        ? 'exam'
        : 'course';
    final type = extension == '.mp3'
        ? 'audio'
        : extension == '.pdf'
        ? 'pdf'
        : 'image';
    final fileTitle = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final title =
        extension == '.pdf' &&
            level != null &&
            RegExp(r'^h[1-6]\d{4}', caseSensitive: false).hasMatch(fileName)
        ? 'Đề HSK $level · $fileTitle'
        : extension == '.mp3' && level != null
        ? 'Bài nghe HSK $level · $fileTitle'
        : fileTitle;

    return StudyMaterial(
      id: id ?? 'imported_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      fileName: fileName,
      type: type,
      category: category,
      level: level,
      source: source,
    );
  }

  Future<File> _savedFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_storageFileName');
  }

  Future<void> _saveImportedMaterials(Directory directory) async {
    final savedFile = File(
      '${directory.path}${Platform.pathSeparator}$_storageFileName',
    );
    final imported = _materials.values
        .where((material) => material.isImported)
        .map((material) => material.toJson())
        .toList();
    await savedFile.writeAsString(jsonEncode(imported), flush: true);
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot).toLowerCase();
  }

  static String _fileStem(String fileName) =>
      fileName.replaceFirst(RegExp(r'\.[^.]+$'), '').toUpperCase();

  static String? _lessonCode(String fileName) => RegExp(
    r'H[1-6]\d{4,}',
    caseSensitive: false,
  ).firstMatch(fileName)?.group(0)?.toUpperCase();

  static int _compareMaterials(StudyMaterial left, StudyMaterial right) {
    final levelOrder = (left.level ?? 99).compareTo(right.level ?? 99);
    if (levelOrder != 0) return levelOrder;
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }
}
