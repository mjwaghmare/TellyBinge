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
}
