import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/app/widgets/floating_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  Size viewport = const Size(1280, 800),
  VoidCallback? onBackgroundPressed,
}) async {
  _setViewport(tester, viewport);
  addTearDown(FloatingWindowManager.closeAll);

  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            hostContext = context;
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: onBackgroundPressed,
                  child: const Text('Background Action'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  return hostContext;
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'FloatingWindowManager.show opens non-blocking window leaving background interactive',
    (tester) async {
      var bgClicks = 0;
      final ctx = await _pumpHost(
        tester,
        onBackgroundPressed: () => bgClicks++,
      );

      FloatingWindowManager.show(
        ctx,
        id: 'non_blocking',
        title: 'Assistant IA',
        defaultWidth: 500,
        defaultHeight: 400,
        content: const Center(child: Text('Contenu Flottant')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assistant IA'), findsOneWidget);
      expect(find.text('Contenu Flottant'), findsOneWidget);

      await tester.tap(find.text('Background Action'));
      await tester.pump();
      expect(bgClicks, 1);
    },
  );

  testWidgets(
    'dragging title bar moves floating window and clamps within viewport',
    (tester) async {
      final ctx = await _pumpHost(tester);

      FloatingWindowManager.show(
        ctx,
        id: 'draggable_win',
        title: 'Draggable Window',
        defaultWidth: 500,
        defaultHeight: 400,
        content: const SizedBox.shrink(),
      );
      await tester.pumpAndSettle();

      final initialPos = tester.getTopLeft(find.byType(FloatingWindowWidget));

      await tester.drag(find.text('Draggable Window'), const Offset(120, 80));
      await tester.pumpAndSettle();

      final movedPos = tester.getTopLeft(find.byType(FloatingWindowWidget));
      expect(movedPos.dx, closeTo(initialPos.dx + 120, 1.0));
      expect(movedPos.dy, closeTo(initialPos.dy + 80, 1.0));

      // Drag far top-left -> clamped to >= (0, 0)
      await tester.drag(
        find.text('Draggable Window'),
        const Offset(-3000, -3000),
      );
      await tester.pumpAndSettle();
      final topLeftClamped = tester.getTopLeft(find.byType(FloatingWindowWidget));
      expect(topLeftClamped.dx, 0.0);
      expect(topLeftClamped.dy, 0.0);

      // Drag far bottom-right -> clamped so title bar handle remains reachable
      await tester.drag(
        find.text('Draggable Window'),
        const Offset(3000, 3000),
      );
      await tester.pumpAndSettle();
      final bottomRightClamped =
          tester.getTopLeft(find.byType(FloatingWindowWidget));
      expect(bottomRightClamped.dx, lessThanOrEqualTo(1280.0 - 100.0));
      expect(bottomRightClamped.dy, lessThanOrEqualTo(800.0 - 48.0));
    },
  );

  testWidgets(
    'minimizing collapses to compact bar while preserving child TextField state across button and double-tap restore',
    (tester) async {
      final ctx = await _pumpHost(tester);

      FloatingWindowManager.show(
        ctx,
        id: 'stateful_win',
        title: 'Stateful Window',
        defaultWidth: 520,
        defaultHeight: 420,
        content: const Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(labelText: 'Médicament'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Amoxicilline 1g');
      await tester.pump();

      // Minimize via button
      await tester.tap(find.byIcon(Icons.minimize));
      await tester.pumpAndSettle();

      final minimizedSize = tester.getSize(find.byType(FloatingWindowWidget));
      expect(minimizedSize, const Size(300, 48));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextField, skipOffstage: false), findsOneWidget);

      // Restore via button
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(FloatingWindowWidget)), const Size(520, 420));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Amoxicilline 1g',
      );

      // Minimize again, then restore via double-tap on title bar
      await tester.tap(find.byIcon(Icons.minimize));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FloatingWindowWidget)), const Size(300, 48));

      await _doubleTap(tester, find.text('Stateful Window'));
      expect(tester.getSize(find.byType(FloatingWindowWidget)), const Size(520, 420));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Amoxicilline 1g',
      );
    },
  );

  testWidgets(
    'maximizing fills viewport and restores previous bounds via button and double-tap',
    (tester) async {
      final ctx = await _pumpHost(tester);

      FloatingWindowManager.show(
        ctx,
        id: 'max_win',
        title: 'Maximize Test',
        defaultWidth: 600,
        defaultHeight: 450,
        content: const SizedBox.shrink(),
      );
      await tester.pumpAndSettle();

      final normalRect = tester.getRect(find.byType(FloatingWindowWidget));
      expect(normalRect.size, const Size(600, 450));

      // Maximize via button
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(FloatingWindowWidget)),
        const Rect.fromLTWH(0, 0, 1280, 800),
      );

      // Restore via button
      await tester.tap(find.byIcon(Icons.fullscreen_exit));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FloatingWindowWidget)), normalRect);

      // Maximize and restore via double-tap
      await _doubleTap(tester, find.text('Maximize Test'));
      expect(
        tester.getRect(find.byType(FloatingWindowWidget)),
        const Rect.fromLTWH(0, 0, 1280, 800),
      );

      await _doubleTap(tester, find.text('Maximize Test'));
      expect(tester.getRect(find.byType(FloatingWindowWidget)), normalRect);
    },
  );

  testWidgets(
    'bottom-right resize handle resizes window and enforces minimum 360x250 bounds',
    (tester) async {
      final ctx = await _pumpHost(tester);

      FloatingWindowManager.show(
        ctx,
        id: 'resize_win',
        title: 'Resizable Window',
        defaultWidth: 500,
        defaultHeight: 400,
        content: const SizedBox.shrink(),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byIcon(Icons.drag_handle_outlined),
        const Offset(100, 60),
      );
      await tester.pumpAndSettle();

      final grownSize = tester.getSize(find.byType(FloatingWindowWidget));
      expect(grownSize.width, closeTo(600, 1.0));
      expect(grownSize.height, closeTo(460, 1.0));

      await tester.drag(
        find.byIcon(Icons.drag_handle_outlined),
        const Offset(-2000, -2000),
      );
      await tester.pumpAndSettle();

      final minClampedSize = tester.getSize(find.byType(FloatingWindowWidget));
      expect(minClampedSize.width, 360.0);
      expect(minClampedSize.height, 250.0);
    },
  );

  testWidgets(
    'multiple concurrent windows bring tapped window to front and reopen existing id un-minimized',
    (tester) async {
      final ctx = await _pumpHost(tester);

      FloatingWindowManager.show(
        ctx,
        id: 'win_a',
        title: 'Window A',
        defaultWidth: 420,
        defaultHeight: 320,
        content: const Center(child: Text('Body A')),
      );
      FloatingWindowManager.show(
        ctx,
        id: 'win_b',
        title: 'Window B',
        defaultWidth: 420,
        defaultHeight: 320,
        content: const Center(child: Text('Body B')),
      );
      await tester.pumpAndSettle();

      expect(FloatingWindowManager.windows.value.length, 2);
      expect(FloatingWindowManager.windows.value.last.id, 'win_b');

      // Drag Window B away so Window A's body is exposed to tap
      await tester.drag(find.text('Window B'), const Offset(350, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Body A'));
      await tester.pumpAndSettle();
      expect(FloatingWindowManager.windows.value.last.id, 'win_a');

      // Minimize Window B, then re-invoke show with same id 'win_b'
      await tester.tap(find.byIcon(Icons.minimize).first);
      await tester.pumpAndSettle();
      expect(
        FloatingWindowManager.windows.value
            .firstWhere((w) => w.id == 'win_b')
            .isMinimized,
        isTrue,
      );

      FloatingWindowManager.show(
        ctx,
        id: 'win_b',
        title: 'Window B',
        content: const SizedBox.shrink(),
      );
      await tester.pumpAndSettle();

      expect(FloatingWindowManager.windows.value.length, 2);
      expect(FloatingWindowManager.windows.value.last.id, 'win_b');
      expect(FloatingWindowManager.windows.value.last.isMinimized, isFalse);
    },
  );

  testWidgets(
    'FloatingWindowManager.showDialog builds once, auto-extracts AlertDialog title, resolves value, and handles close cleanly',
    (tester) async {
      final ctx = await _pumpHost(tester);

      var buildCalls = 0;
      final future1 = FloatingWindowManager.showDialog<String>(
        context: ctx,
        defaultWidth: 460,
        defaultHeight: 300,
        builder: (dialogCtx) {
          buildCalls++;
          return AlertDialog(
            title: const Text('Auto Extracted Title'),
            content: const Text('Dialog Body'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, 'ok_42'),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
      await tester.pumpAndSettle();

      expect(buildCalls, 1);
      expect(find.text('Auto Extracted Title'), findsNWidgets(2));

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(await future1, 'ok_42');
      expect(FloatingWindowManager.windows.value, isEmpty);
      expect(tester.takeException(), isNull);

      // Closing via window close button resolves null with no disposed notifier errors
      final future2 = FloatingWindowManager.showDialog<String>(
        context: ctx,
        title: 'Explicit Title',
        defaultWidth: 460,
        defaultHeight: 300,
        builder: (_) => const AlertDialog(
          content: Text('Close me'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(await future2, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FloatingWindowManager.showDatePicker and showTimePicker open cleanly on desktop without overflow',
    (tester) async {
      final ctx = await _pumpHost(tester);

      final dateFuture = FloatingWindowManager.showDatePicker(
        context: ctx,
        initialDate: DateTime(2026, 11, 20),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      final pickedDate = await dateFuture;
      expect(pickedDate, DateTime(2026, 11, 20));

      final timeFuture = FloatingWindowManager.showTimePicker(
        context: ctx,
        initialTime: const TimeOfDay(hour: 10, minute: 30),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      final pickedTime = await timeFuture;
      expect(pickedTime, const TimeOfDay(hour: 10, minute: 30));
    },
  );

  testWidgets(
    'mobile viewport falls back to full-screen MaterialPageRoute with AppBar and close button',
    (tester) async {
      final ctx = await _pumpHost(tester, viewport: const Size(390, 844));

      FloatingWindowManager.show(
        ctx,
        id: 'mobile_win',
        title: 'Mobile Assistant',
        content: const Center(child: Text('Mobile Body')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingWindowWidget), findsNothing);
      expect(find.text('Mobile Assistant'), findsOneWidget);
      expect(find.text('Mobile Body'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Mobile Body'), findsNothing);

      final dialogFuture = FloatingWindowManager.showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Mobile Dialog'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingWindowWidget), findsNothing);
      expect(find.text('Mobile Dialog'), findsNWidgets(2));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(await dialogFuture, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
