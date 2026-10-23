export 'domain/models/progress.dart';
export 'domain/models/vocab.dart';
export 'domain/services/learning_engine.dart';
export 'domain/services/srs_scheduler.dart';
export 'data/datasources/dictionary_data_source.dart';
export 'services/storage/storage_service.dart';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/datasources/dictionary_data_source.dart';
import 'data/services/study_material_library.dart';
import 'services/storage/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Store.load(),
    loadDictionary(),
    StudyMaterialLibrary.instance.load(),
  ]);
  runApp(const ChineseLearningApp());
}
