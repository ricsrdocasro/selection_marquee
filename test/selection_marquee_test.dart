import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selection_marquee/selection_marquee.dart';

void main() {
  group('SelectionController', () {
    late SelectionController controller;

    setUp(() {
      controller = SelectionController();
    });

    test('starts selection correctly', () {
      const startPosition = Offset(10, 10);
      controller.startSelection(startPosition);

      expect(controller.isSelecting, isTrue);
      expect(
        controller.selectionRect,
        Rect.fromPoints(startPosition, startPosition),
      );
      expect(controller.selectedIds, isEmpty);
    });

    test('updates selection correctly', () {
      const startPosition = Offset(10, 10);
      const currentPosition = Offset(50, 50);
      controller.startSelection(startPosition);
      controller.updateSelection(currentPosition, startPosition);

      expect(
        controller.selectionRect,
        Rect.fromPoints(startPosition, currentPosition),
      );
    });

    test('ends selection correctly', () {
      const startPosition = Offset(10, 10);
      controller.startSelection(startPosition);
      controller.endSelection();

      expect(controller.isSelecting, isFalse);
      expect(controller.selectionRect, isNull);
    });

    test('select/deselect/toggle/setSelected/clear/selectAll work', () async {
      const itemA = 'itemA';
      const itemB = 'itemB';

      controller.select(itemA);
      expect(controller.selectedIds.contains(itemA), isTrue);

      controller.deselect(itemA);
      expect(controller.selectedIds.contains(itemA), isFalse);

      controller.toggle(itemB);
      expect(controller.selectedIds.contains(itemB), isTrue);

      controller.toggle(itemB);
      expect(controller.selectedIds.contains(itemB), isFalse);

      controller.setSelected({itemA, itemB});
      expect(controller.selectedIds, containsAll(<String>[itemA, itemB]));

      controller.clear();
      expect(controller.selectedIds, isEmpty);

      controller.selectAll(candidates: [itemA, itemB]);
      expect(controller.selectedIds, containsAll(<String>[itemA, itemB]));
    });

    test(
      'selectedListenable and onSelectionChanged stream emit updates',
      () async {
        final events = <Set<String>>[];
        final sub = controller.onSelectionChanged.listen((s) => events.add(s));

        controller.select('one');
        controller.select('two');

        // allow microtask queue to flush so stream listeners see the events
        await Future.delayed(Duration.zero);

        expect(events.length, greaterThanOrEqualTo(2));
        expect(events.last, contains('two'));

        // ValueNotifier should also reflect latest
        expect(controller.selectedListenable.value, contains('two'));

        await sub.cancel();
      },
    );

    test('register/unregister/ensureItemVisible do not throw', () async {
      final key = GlobalKey();
      controller.registerItem('x', key);
      controller.unregisterItem('x');
      await controller.ensureItemVisible(
        'x',
      ); // should not throw even without context
    });
  });

  testWidgets('SelectionMarquee renders with dotted style', (tester) async {
    final controller = SelectionController();
    final marqueeKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionMarquee(
            controller: controller,
            marqueeKey: marqueeKey,
            config: const SelectionConfig(
              selectionDecoration: SelectionDecoration(
                borderStyle: SelectionBorderStyle.dotted,
              ),
            ),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );

    // Start selection to make the painter active
    controller.startSelection(const Offset(10, 10));
    controller.updateSelection(const Offset(100, 100), const Offset(10, 10));
    await tester.pump();

    // Verify it renders (finds the CustomPaint)
    final customPaint = find.descendant(
      of: find.byKey(marqueeKey),
      matching: find.byType(CustomPaint),
    );
    expect(customPaint, findsOneWidget);

    controller.dispose();
  });
}
