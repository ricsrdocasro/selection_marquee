import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selection_marquee/selection_marquee.dart';

void main() {
  testWidgets('auto-scroll jump mode scrolls when dragging to bottom edge', (
    WidgetTester tester,
  ) async {
    final controller = SelectionController();
    final marqueeKey = GlobalKey();
    final scrollController = ScrollController();
    final marqueeBoxKey = const Key('marqueeBox');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: marqueeBoxKey,
            width: 400,
            height: 400,
            child: SelectionMarquee(
              controller: controller,
              marqueeKey: marqueeKey,
              scrollController: scrollController,
              config: const SelectionConfig(
                edgeAutoScroll: true,
                autoScrollMode: AutoScrollMode.jump,
                autoScrollSpeed: 600.0,
                edgeZoneFraction: 0.2,
                minDragDistance: 1.0,
              ),
              child: ListView.builder(
                controller: scrollController,
                itemExtent: 80,
                itemCount: 50,
                itemBuilder: (context, index) => Container(
                  alignment: Alignment.center,
                  child: Text('Item ${index + 1}'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final box = tester.getSize(find.byKey(marqueeBoxKey));
    final start = tester.getTopLeft(find.byKey(marqueeBoxKey)) +
        Offset(box.width / 2, box.height / 2);

    final gesture = await tester.startGesture(
      start,
      pointer: 1,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    // small move to start drag
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();

    // move into bottom edge zone
    final bottomPoint = tester.getTopLeft(find.byKey(marqueeBoxKey)) +
        Offset(box.width / 2, box.height - 5);
    await gesture.moveTo(bottomPoint);

    // allow some time for the auto-scroll timer to run
    await tester.pump(const Duration(milliseconds: 350));

    expect(scrollController.position.pixels, greaterThan(0));

    await gesture.up();
  });

  testWidgets('auto-scroll animate mode scrolls when dragging to bottom edge', (
    WidgetTester tester,
  ) async {
    final controller = SelectionController();
    final marqueeKey = GlobalKey();
    final scrollController = ScrollController();
    final marqueeBoxKey = const Key('marqueeBox2');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: marqueeBoxKey,
            width: 400,
            height: 400,
            child: SelectionMarquee(
              controller: controller,
              marqueeKey: marqueeKey,
              scrollController: scrollController,
              config: const SelectionConfig(
                edgeAutoScroll: true,
                autoScrollMode: AutoScrollMode.animate,
                autoScrollSpeed: 600.0,
                edgeZoneFraction: 0.2,
                minDragDistance: 1.0,
                autoScrollAnimationDuration: Duration(milliseconds: 80),
              ),
              child: ListView.builder(
                controller: scrollController,
                itemExtent: 80,
                itemCount: 50,
                itemBuilder: (context, index) => Container(
                  alignment: Alignment.center,
                  child: Text('Item ${index + 1}'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final box = tester.getSize(find.byKey(marqueeBoxKey));
    final start = tester.getTopLeft(find.byKey(marqueeBoxKey)) +
        Offset(box.width / 2, box.height / 2);

    final gesture = await tester.startGesture(
      start,
      pointer: 1,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    // small move to start drag
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();

    // move into bottom edge zone
    final bottomPoint = tester.getTopLeft(find.byKey(marqueeBoxKey)) +
        Offset(box.width / 2, box.height - 5);
    await gesture.moveTo(bottomPoint);

    // allow time for animations/auto-scroll to run
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(scrollController.position.pixels, greaterThan(0));

    await gesture.up();
  }, skip: true);
}
