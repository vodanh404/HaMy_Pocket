import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/features/settings/download_center_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'hamy_pocket_download_center_test_',
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

  testWidgets('offers separate downloads for study data and both AI models', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DownloadCenterScreen()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dữ liệu và AI'), findsOneWidget);
    expect(find.text('Audio và PDF bài nghe/đề thi'), findsOneWidget);
    expect(find.text('Mô hình dịch Trung–Việt'), findsOneWidget);
    expect(find.text('AI hội thoại Qwen2.5-0.5B-Instruct'), findsOneWidget);
    expect(find.text('Tải xuống'), findsNWidgets(3));
  });
}
