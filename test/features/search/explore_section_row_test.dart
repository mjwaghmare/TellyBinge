import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/search/presentation/widgets/explore_section_row.dart';

import 'fake_explore_tmdb_client.dart';

void main() {
  // Movie items keep TvStatusPill (and its cubit) out of these tests.
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('ExploreSectionRow', () {
    testWidgets('shows at most five titles', (tester) async {
      await pump(
        tester,
        ExploreSectionRow(
          title: 'Trending Now',
          items: titles(1, 20),
          defaultType: 'movie',
          onSeeAll: () {},
        ),
      );
      await tester.dragUntilVisible(
        find.text('Title 5'),
        find.byType(ListView),
        const Offset(-200, 0),
      );
      expect(find.text('Title 6'), findsNothing);
      expect(find.text('See All'), findsOneWidget);
    });

    testWidgets('each row keeps its own horizontal scroll offset', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          children: [
            ExploreSectionRow(
              title: 'A',
              storageId: 'forYou',
              items: titles(1, 5),
              defaultType: 'movie',
            ),
            ExploreSectionRow(
              title: 'B',
              storageId: 'trending',
              items: titles(100, 5),
              defaultType: 'movie',
            ),
          ],
        ),
      );
      final keys = tester
          .widgetList<ListView>(find.byType(ListView))
          .map((l) => l.key)
          .toSet();
      expect(keys, hasLength(2));
      expect(keys, everyElement(isA<PageStorageKey<String>>()));
    });

    testWidgets('offers See All only above five titles', (tester) async {
      await pump(
        tester,
        ExploreSectionRow(
          title: 'Trending Now',
          items: titles(1, exploreRowMaxItems),
          defaultType: 'movie',
          onSeeAll: () {},
        ),
      );
      expect(find.text('See All'), findsNothing);

      var tapped = false;
      await pump(
        tester,
        ExploreSectionRow(
          title: 'Trending Now',
          items: titles(1, exploreRowMaxItems + 1),
          defaultType: 'movie',
          onSeeAll: () => tapped = true,
        ),
      );
      await tester.tap(find.text('See All'));
      expect(tapped, isTrue);
    });

    testWidgets('hides See All while loading', (tester) async {
      await pump(
        tester,
        ExploreSectionRow(
          title: 'For You',
          items: titles(1, 20),
          defaultType: 'movie',
          isLoading: true,
          onSeeAll: () {},
        ),
      );
      expect(find.text('See All'), findsNothing);
    });

    testWidgets('shows a spinner while topping up', (tester) async {
      await pump(
        tester,
        ExploreSectionRow(
          title: 'For You',
          items: titles(1, 3),
          defaultType: 'movie',
          isLoadingMore: true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('long-pressing a poster card opens quick actions sheet', (tester) async {
      await pump(
        tester,
        ExploreSectionRow(
          title: 'Trending Now',
          items: titles(1, 1),
          defaultType: 'movie',
        ),
      );
      await tester.longPress(find.text('Title 1'));
      await tester.pumpAndSettle();

      expect(find.text('Add to Watchlist'), findsOneWidget);
      expect(find.text('Mark as Watched'), findsOneWidget);
      expect(find.text('Share Polaroid'), findsOneWidget);
    });
  });

  group('ExploreTopWeekRow', () {
    testWidgets('ranks titles and labels each rank for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        ExploreTopWeekRow(
          title: 'Top 5 This Week',
          items: titles(1, 5),
          defaultType: 'movie',
        ),
      );

      expect(find.bySemanticsLabel('Rank 1, Title 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Rank 2, Title 2'), findsOneWidget);
      // Poster only: no title line under the poster.
      expect(find.text('Title 1'), findsNothing);
      expect(find.text('See All'), findsNothing);
      semantics.dispose();
    });

    testWidgets('leaves rank numbers out while loading', (tester) async {
      await pump(
        tester,
        ExploreTopWeekRow(
          title: 'Top 5 This Week',
          items: const [],
          defaultType: 'movie',
          isLoading: true,
        ),
      );
      final numbers = find.descendant(
        of: find.byType(ExploreTopWeekRow),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null,
        ),
      );
      expect(numbers, findsNothing);
    });

    testWidgets('renders rank numbers with Clip.none to avoid edge clipping', (
      tester,
    ) async {
      await pump(
        tester,
        ExploreTopWeekRow(
          title: 'Top 5 This Week',
          items: titles(1, 5),
          defaultType: 'movie',
        ),
      );
      final listViewFinder = find.descendant(
        of: find.byType(ExploreTopWeekRow),
        matching: find.byType(ListView),
      );
      expect(listViewFinder, findsOneWidget);
      final listView = tester.widget<ListView>(listViewFinder);
      expect(listView.clipBehavior, Clip.none);
    });
  });

  group('ExploreBackdropSectionRow', () {
    testWidgets('shows at most five backdrop cards and offers See All', (
      tester,
    ) async {
      var tapped = false;
      await pump(
        tester,
        ExploreBackdropSectionRow(
          title: 'Coming Soon',
          items: titles(1, 10),
          defaultType: 'movie',
          onSeeAll: () => tapped = true,
        ),
      );
      await tester.dragUntilVisible(
        find.text('Title 5'),
        find.byType(ListView),
        const Offset(-200, 0),
      );
      expect(find.text('Title 6'), findsNothing);
      expect(find.text('See All'), findsOneWidget);

      await tester.tap(find.text('See All'));
      expect(tapped, isTrue);
    });

    testWidgets('renders release date badge with month and day', (
      tester,
    ) async {
      await pump(
        tester,
        ExploreBackdropSectionRow(
          title: 'Coming Soon',
          items: [
            {
              'id': 101,
              'title': 'Gladiator II',
              'release_date': '2026-11-22',
            },
          ],
          defaultType: 'movie',
        ),
      );
      expect(find.text('Gladiator II'), findsOneWidget);
      expect(find.text('NOV'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
    });

    testWidgets('long-pressing a card opens quick actions sheet', (tester) async {
      await pump(
        tester,
        ExploreBackdropSectionRow(
          title: 'Coming Soon',
          items: titles(1, 1),
          defaultType: 'movie',
        ),
      );
      await tester.longPress(find.text('Title 1'));
      await tester.pumpAndSettle();

      expect(find.text('Add to Watchlist'), findsOneWidget);
      expect(find.text('Mark as Watched'), findsOneWidget);
      expect(find.text('Share Polaroid'), findsOneWidget);
    });
  });
}
