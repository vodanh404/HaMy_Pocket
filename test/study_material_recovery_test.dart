import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/data/services/study_material_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'hamy_pocket_material_test_',
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

  test(
    'ignores a malformed saved catalog instead of failing startup',
    () async {
      final savedFile = File(
        '${supportDirectory.path}${Platform.pathSeparator}study_materials.json',
      );
      await savedFile.writeAsString('{not-json');

      await expectLater(StudyMaterialLibrary.instance.load(), completes);
    },
  );

  test(
    'imports a folder automatically and clear removes only imported files',
    () async {
      final sourceDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}lesson_folder',
      );
      final nestedDirectory = Directory(
        '${sourceDirectory.path}${Platform.pathSeparator}nested',
      );
      await nestedDirectory.create(recursive: true);
      final audioPath =
          '${sourceDirectory.path}${Platform.pathSeparator}H20999.mp3';
      final pdfPath =
          '${nestedDirectory.path}${Platform.pathSeparator}H20999.pdf';
      await File(audioPath).writeAsBytes([1, 2, 3]);
      await File(pdfPath).writeAsBytes([4, 5, 6]);
      await File('${sourceDirectory.path}${Platform.pathSeparator}notes.txt')
          .writeAsString('ignored');

      final library = StudyMaterialLibrary.instance;
      expect(await library.importDirectory(sourceDirectory.path), 2);
      expect(
        library.materials.where((material) => material.isImported),
        hasLength(2),
      );

      await library.clearImported();

      expect(
        library.materials.where((material) => material.isImported),
        isEmpty,
      );
      expect(
        library.materials.any(
          (material) =>
              material.id == 'asset:audio/HSK1/H10901.mp3' &&
              material.isAvailable,
        ),
        isTrue,
      );
    },
  );
}
