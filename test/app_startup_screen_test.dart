import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/app/app_startup_screen.dart';

void main() {
  testWidgets('shows branded loading UI until startup completes', (
    tester,
  ) async {
    final startup = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartupScreen(
          initialize: () => startup.future,
          app: const Text('Ready'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Đang chuẩn bị dữ liệu học...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    startup.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('reports startup errors and can retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppStartupScreen(
          initialize: () async {
            attempts++;
            if (attempts == 1) throw StateError('dictionary unavailable');
          },
          app: const Text('Ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể khởi động ứng dụng'), findsOneWidget);
    expect(find.textContaining('dictionary unavailable'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(attempts, 2);
  });
}
