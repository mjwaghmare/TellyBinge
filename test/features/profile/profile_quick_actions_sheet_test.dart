import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/presentation/pages/profile_page.dart';
import 'package:popverse/features/profile/presentation/widgets/profile_quick_actions_sheet.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('ProfileQuickActionsSheet', () {
    testWidgets('shows correct movie quick actions when not watched and not favorite', (
      tester,
    ) async {
      final item = HorizontalItem(
        movieId: 550,
        title: 'Fight Club',
        imageUrl: '',
        voteAverage: 8.4,
        releaseDate: '1999-10-15',
        isMovie: true,
        isWatched: false,
        isFavorite: false,
      );

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showProfileQuickActions(context, item: item),
              child: const Text('Open Actions'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Actions'));
      await tester.pumpAndSettle();

      expect(find.text('Fight Club'), findsOneWidget);
      expect(find.text('1999 • Movie • ★ 8.4'), findsOneWidget);
      expect(find.text('Mark as Watched'), findsOneWidget);
      expect(find.text('Add to Favorites'), findsOneWidget);
      expect(find.text('Remove from Watchlist'), findsOneWidget);
      expect(find.text('Share Polaroid'), findsOneWidget);
    });

    testWidgets('shows correct movie quick actions when watched and favorite', (
      tester,
    ) async {
      final item = HorizontalItem(
        movieId: 550,
        title: 'Fight Club',
        imageUrl: '',
        voteAverage: 8.4,
        releaseDate: '1999-10-15',
        isMovie: true,
        isWatched: true,
        isFavorite: true,
      );

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showProfileQuickActions(context, item: item),
              child: const Text('Open Actions'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Actions'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Unwatched'), findsOneWidget);
      expect(find.text('Remove from Favorites'), findsOneWidget);
      expect(find.text('Remove from Watchlist'), findsOneWidget);
      expect(find.text('Share Polaroid'), findsOneWidget);
    });

    testWidgets('shows correct TV show quick actions when partially watched', (
      tester,
    ) async {
      final item = HorizontalItem(
        movieId: 1399,
        title: 'Game of Thrones',
        imageUrl: '',
        voteAverage: 8.5,
        releaseDate: '2011-04-17',
        isMovie: false,
        isWatched: true,
        isFavorite: false,
        watchedCount: 10,
        totalEpisodes: 73,
      );

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showProfileQuickActions(context, item: item),
              child: const Text('Open Actions'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Actions'));
      await tester.pumpAndSettle();

      expect(find.text('Game of Thrones'), findsOneWidget);
      expect(find.text('2011 • TV Series • ★ 8.5'), findsOneWidget);
      expect(find.text('Mark All as Watched'), findsOneWidget);
      expect(find.text('Log all released episodes (10/73)'), findsOneWidget);
      expect(find.text('Add to Favorites'), findsOneWidget);
      expect(find.text('Stop Tracking'), findsOneWidget);
      expect(find.text('Share Polaroid'), findsOneWidget);
    });

    testWidgets('shows correct TV show quick actions when all episodes watched', (
      tester,
    ) async {
      final item = HorizontalItem(
        movieId: 1399,
        title: 'Game of Thrones',
        imageUrl: '',
        voteAverage: 8.5,
        releaseDate: '2011-04-17',
        isMovie: false,
        isWatched: true,
        isFavorite: true,
        watchedCount: 73,
        totalEpisodes: 73,
      );

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showProfileQuickActions(context, item: item),
              child: const Text('Open Actions'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Actions'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Unwatched'), findsOneWidget);
      expect(find.text('Reset episode watch history'), findsOneWidget);
      expect(find.text('Remove from Favorites'), findsOneWidget);
      expect(find.text('Stop Tracking'), findsOneWidget);
      expect(find.text('Share Polaroid'), findsOneWidget);
    });
  });
}
