import 'package:chifa/app/screens/medical_records/widgets/record_actions_speed_dial.dart';
import 'package:chifa/services/db/models/print_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildSpeedDialHarness({
  Key? dialKey,
  PrintTemplate initialTemplate = PrintTemplate.chifa,
  bool initialIncludeDate = true,
  bool isEditing = false,
  bool isLoading = false,
  ValueChanged<PrintTemplate>? onTemplateChanged,
  VoidCallback? onToggleIncludeDate,
  VoidCallback? onCancel,
  VoidCallback? onBlankOrdonnance,
  VoidCallback? onPreview,
  VoidCallback? onPrint,
  VoidCallback? onSubmit,
  VoidCallback? onBackgroundTap,
}) {
  var template = initialTemplate;
  var includeDate = initialIncludeDate;

  return MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) {
          return Stack(
            children: [
              Positioned(
                top: 24,
                left: 24,
                child: ElevatedButton(
                  onPressed: onBackgroundTap,
                  child: const Text('Behind Button'),
                ),
              ),
              Positioned.fill(
                child: RecordActionsSpeedDial(
                  key: dialKey,
                  selectedTemplate: template,
                  onTemplateChanged: (next) {
                    setState(() => template = next);
                    onTemplateChanged?.call(next);
                  },
                  includeDateInOrdonnance: includeDate,
                  onToggleIncludeDate: () {
                    setState(() => includeDate = !includeDate);
                    onToggleIncludeDate?.call();
                  },
                  onCancel: onCancel ?? () {},
                  onBlankOrdonnance: onBlankOrdonnance ?? () {},
                  onPreview: onPreview ?? () {},
                  onPrint: onPrint ?? () {},
                  onSubmit: onSubmit ?? () {},
                  isEditing: isEditing,
                  isLoading: isLoading,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'collapsed state hides menu items and allows taps on underlying widgets',
    (tester) async {
      var backgroundTapped = false;

      await tester.pumpWidget(
        _buildSpeedDialHarness(
          onBackgroundTap: () => backgroundTapped = true,
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Create Record'), findsNothing);
      expect(find.text('Print'), findsNothing);
      expect(find.text('Preview'), findsNothing);
      expect(find.text('Blank Ordonnance'), findsNothing);
      expect(find.text('CHIFA'), findsNothing);
      expect(find.text('Date ON'), findsNothing);
      expect(find.text('Cancel'), findsNothing);

      await tester.tap(find.text('Behind Button'));
      await tester.pump();
      expect(backgroundTapped, isTrue);
    },
  );

  testWidgets(
    'tapping main FAB expands all 7 items for new and edited records',
    (tester) async {
      await tester.pumpWidget(_buildSpeedDialHarness(isEditing: false));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Date ON'), findsOneWidget);
      expect(find.text('CHIFA'), findsOneWidget);
      expect(find.text('EPH'), findsOneWidget);
      expect(find.text('Blank Ordonnance'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Create Record'), findsOneWidget);

      await tester.pumpWidget(
        _buildSpeedDialHarness(
          dialKey: const ValueKey('edit'),
          isEditing: true,
          initialIncludeDate: false,
        ),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Date OFF'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping EPH and Date ON updates state while keeping speed dial open',
    (tester) async {
      PrintTemplate? changedTemplate;
      var dateToggleCount = 0;

      await tester.pumpWidget(
        _buildSpeedDialHarness(
          onTemplateChanged: (t) => changedTemplate = t,
          onToggleIncludeDate: () => dateToggleCount++,
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EPH'));
      await tester.pumpAndSettle();
      expect(changedTemplate, PrintTemplate.eph);
      // Still open
      expect(find.text('Create Record'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      await tester.tap(find.text('Date ON'));
      await tester.pumpAndSettle();
      expect(dateToggleCount, 1);
      expect(find.text('Date OFF'), findsOneWidget);
      // Still open
      expect(find.text('Create Record'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping each action invokes its callback and closes the menu',
    (tester) async {
      var submitCount = 0;
      var printCount = 0;
      var previewCount = 0;
      var blankCount = 0;
      var cancelCount = 0;

      await tester.pumpWidget(
        _buildSpeedDialHarness(
          onSubmit: () => submitCount++,
          onPrint: () => printCount++,
          onPreview: () => previewCount++,
          onBlankOrdonnance: () => blankCount++,
          onCancel: () => cancelCount++,
        ),
      );

      Future<void> triggerAndVerify(String label, VoidCallback verify) async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        verify();
        expect(find.text('Print'), findsNothing);
        expect(find.text('Create Record'), findsNothing);
      }

      await triggerAndVerify('Create Record', () => expect(submitCount, 1));
      await triggerAndVerify('Print', () => expect(printCount, 1));
      await triggerAndVerify('Preview', () => expect(previewCount, 1));
      await triggerAndVerify('Blank Ordonnance', () => expect(blankCount, 1));
      await triggerAndVerify('Cancel', () => expect(cancelCount, 1));
    },
  );

  testWidgets('tapping backdrop scrim closes the speed dial', (tester) async {
    await tester.pumpWidget(_buildSpeedDialHarness());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Create Record'), findsOneWidget);

    // Top-left area is covered by the translucent scrim, away from the right-aligned items.
    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();

    expect(find.text('Create Record'), findsNothing);
    expect(find.text('Print'), findsNothing);
  });

  testWidgets(
    'renders without overflow on portrait and short landscape phones and avoids Hero collisions in IndexedStack',
    (tester) async {
      Future<void> checkViewport(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(size),
            home: Scaffold(
              body: IndexedStack(
                index: 0,
                children: [
                  RecordActionsSpeedDial(
                    selectedTemplate: PrintTemplate.chifa,
                    onTemplateChanged: (_) {},
                    includeDateInOrdonnance: true,
                    onToggleIncludeDate: () {},
                    onCancel: () {},
                    onBlankOrdonnance: () {},
                    onPreview: () {},
                    onPrint: () {},
                    onSubmit: () {},
                    isEditing: false,
                    isLoading: false,
                  ),
                  RecordActionsSpeedDial(
                    selectedTemplate: PrintTemplate.eph,
                    onTemplateChanged: (_) {},
                    includeDateInOrdonnance: false,
                    onToggleIncludeDate: () {},
                    onCancel: () {},
                    onBlankOrdonnance: () {},
                    onPreview: () {},
                    onPrint: () {},
                    onSubmit: () {},
                    isEditing: true,
                    isLoading: false,
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.tap(find.byType(FloatingActionButton).first);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Create Record'), findsOneWidget);
      }

      await checkViewport(const Size(360, 640));
      await checkViewport(const Size(640, 320));
    },
  );
}
