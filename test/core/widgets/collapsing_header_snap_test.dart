import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/widgets/collapsing_header_snap.dart';

const double _expanded = 300;
// Test surface has no status-bar padding, so the header collapses to the bare
// toolbar.
const double _collapseExtent = _expanded - kToolbarHeight;

Widget _customScrollPage(ScrollController controller, {required int items}) {
  return MaterialApp(
    home: Scaffold(
      body: CollapsingHeaderSnap(
        controller: controller,
        expandedHeight: _expanded,
        child: CustomScrollView(
          controller: controller,
          slivers: [
            const SliverAppBar(
              pinned: true,
              expandedHeight: _expanded,
              flexibleSpace: FlexibleSpaceBar(),
            ),
            SliverList.builder(
              itemCount: items,
              itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
            ),
            CollapsingHeaderSnap.fullCollapseFiller(expandedHeight: _expanded),
          ],
        ),
      ),
    ),
  );
}

/// Wraps [child] (the scroll view) so it counts the ScrollEndNotifications
/// reaching the snap. Past a cap it swallows them, so a snap that keeps
/// re-triggering itself fails the test instead of hanging it.
class _ScrollEndCounter {
  static const cap = 200;
  int count = 0;

  Widget wrap(Widget child) => NotificationListener<ScrollEndNotification>(
        onNotification: (_) => ++count > cap,
        child: child,
      );
}

/// Drags by [dy] in small steps, then holds still before lifting, so the
/// release has no fling velocity and the scroll comes to rest exactly there.
Future<void> _slowDragAndRelease(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(const Offset(200, 400));
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(Offset(0, dy / 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
}

void main() {
  testWidgets('snaps back open when released near the top', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(_customScrollPage(controller, items: 40));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -60));
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
  });

  testWidgets('snaps fully collapsed when released past halfway',
      (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(_customScrollPage(controller, items: 40));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(_collapseExtent, 0.01));
  });

  testWidgets('leaves offsets beyond the header alone', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(_customScrollPage(controller, items: 40));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(400, 0.01));
  });

  testWidgets('short content can still collapse fully', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(_customScrollPage(controller, items: 1));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(_collapseExtent, 0.01));
  });

  testWidgets('snaps the outer header of a NestedScrollView', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsingHeaderSnap(
            controller: controller,
            expandedHeight: _expanded,
            child: NestedScrollView(
              controller: controller,
              headerSliverBuilder: (_, _) => const [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: _expanded,
                  flexibleSpace: FlexibleSpaceBar(),
                ),
              ],
              body: ListView.builder(
                itemCount: 40,
                itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(_collapseExtent, 0.01));

    await tester.drag(find.byType(ListView), const Offset(0, 180));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  // Regression: the snap animates the inner list too, which is already at its
  // target and ends instantly; that scroll end used to restart the snap in an
  // endless microtask loop, freezing the app on the show details page.
  testWidgets(
    'NestedScrollView snap does not loop when released at rest mid-header',
    (tester) async {
      final controller = ScrollController();
      final counter = _ScrollEndCounter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsingHeaderSnap(
              controller: controller,
              expandedHeight: _expanded,
              child: counter.wrap(
                NestedScrollView(
                  controller: controller,
                  headerSliverBuilder: (_, _) => const [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: _expanded,
                      flexibleSpace: FlexibleSpaceBar(),
                    ),
                  ],
                  body: ListView.builder(
                    itemCount: 40,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 50, child: Text('$i')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await _slowDragAndRelease(tester, -150);
      await tester.pumpAndSettle();

      expect(counter.count, lessThan(10));
      expect(controller.offset, closeTo(_collapseExtent, 0.01));
    },
    variant: TargetPlatformVariant.mobile(),
  );

  // Without the filler, short content can't reach the collapsed offset; the
  // snap must not keep retrying a target it can never reach.
  testWidgets(
    'does not keep re-snapping when content is too short to collapse',
    (tester) async {
      final controller = ScrollController();
      final counter = _ScrollEndCounter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsingHeaderSnap(
              controller: controller,
              expandedHeight: _expanded,
              child: counter.wrap(
                CustomScrollView(
                  controller: controller,
                  slivers: [
                    const SliverAppBar(
                      pinned: true,
                      expandedHeight: _expanded,
                      flexibleSpace: FlexibleSpaceBar(),
                    ),
                    SliverList.builder(
                      itemCount: 9,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 50, child: Text('$i')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final maxExtent = controller.position.maxScrollExtent;
      expect(maxExtent, lessThan(_collapseExtent - 1));
      expect(maxExtent, greaterThan(_collapseExtent / 2));

      await _slowDragAndRelease(tester, -300);
      await tester.pumpAndSettle();

      expect(counter.count, lessThan(10));
      expect(controller.offset, closeTo(maxExtent, 0.01));
    },
    variant: TargetPlatformVariant.mobile(),
  );
}
