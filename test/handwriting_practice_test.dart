import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/domain/models/vocab.dart';
import 'package:hamy_poket/features/writing/handwriting_practice_screen.dart';
import 'package:hamy_poket/shared/widgets/study_widgets.dart';

void main() {
  final word = Vocab(
    id: 'nihao',
    hanzi: '你好',
    pinyin: 'nǐ hǎo',
    meaning: 'xin chào',
    level: 1,
  );

  testWidgets('opens handwriting practice from a dictionary word', (
    tester,
  ) async {
    _useLargeTestViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(body: wordTile(context, word)),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Luyện viết tay chữ Hán'), findsOneWidget);
    await tester.tap(find.text('Luyện viết tay chữ Hán'));
    await tester.pumpAndSettle();

    expect(find.byType(HandwritingPracticeScreen), findsOneWidget);
    expect(find.text('Chữ 1/2'), findsOneWidget);
    expect(find.byKey(const ValueKey('writing-canvas')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('writing-canvas'))).width,
      260,
    );
  });

  testWidgets('supports sample visibility, drawing, and self-assessment', (
    tester,
  ) async {
    _useLargeTestViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: HandwritingPracticeScreen(word: word)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ẩn chữ mẫu'));
    await tester.pump();
    expect(find.text('Hiện chữ mẫu'), findsOneWidget);

    final canvas = find.byKey(const ValueKey('writing-canvas'));
    await tester.dragFrom(tester.getCenter(canvas), const Offset(40, 0));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Đạt'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Đạt'));
    await tester.pump();
    expect(find.text('Đã ghi nhận tự đánh giá: đạt.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Chữ tiếp theo'));
    await tester.tap(find.byTooltip('Chữ tiếp theo'));
    await tester.pump();
    expect(find.text('Chữ 2/2'), findsOneWidget);
  });

  testWidgets('keeps vertical handwriting gestures out of page scrolling', (
    tester,
  ) async {
    _useLargeTestViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: HandwritingPracticeScreen(word: word)),
    );
    await tester.pumpAndSettle();

    final canvas = find.byKey(const ValueKey('writing-canvas'));
    final initialTop = tester.getTopLeft(canvas).dy;
    await tester.drag(canvas, const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(canvas).dy, initialTop);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Đạt'))
          .onPressed,
      isNotNull,
    );
  });
}

void _useLargeTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
