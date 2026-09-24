import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/search/data/explore_genres.dart';
import 'package:popverse/features/search/data/explore_sources.dart';
import 'package:popverse/features/search/presentation/widgets/explore_genre_pills_row.dart';

void main() {
  group('GenreOption', () {
    test('All option has isAll true and null genre IDs', () {
      final all = kExploreGenres.first;
      expect(all.label, 'All');
      expect(all.isAll, isTrue);
      expect(all.genreIdFor(ExploreMediaType.movie), isNull);
      expect(all.genreIdFor(ExploreMediaType.tv), isNull);
    });

    test('Action option resolves movie 28 and tv 10759', () {
      final action = kExploreGenres.firstWhere((g) => g.label == 'Action');
      expect(action.isAll, isFalse);
      expect(action.genreIdFor(ExploreMediaType.movie), 28);
      expect(action.genreIdFor(ExploreMediaType.tv), 10759);
      expect(action.displayName, '💥 Action');
    });

    test('Anime option specifies Japanese language requirement and animation genre', () {
      final anime = kExploreGenres.firstWhere((g) => g.label == 'Anime');
      expect(anime.genreIdFor(ExploreMediaType.movie), 16);
      expect(anime.genreIdFor(ExploreMediaType.tv), 16);
      expect(anime.requiredLanguage, 'ja');
      expect(anime.displayName, '🌸 Anime');
    });
  });

  group('ExploreGenrePillsRow', () {
    testWidgets('renders all genre pills and fires onGenreSelected on tap', (
      tester,
    ) async {
      GenreOption selected = kExploreGenres.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ExploreGenrePillsRow(
                genres: kExploreGenres,
                selectedGenre: selected,
                onGenreSelected: (g) => setState(() => selected = g),
              ),
            ),
          ),
        ),
      );

      // Verify All and Action are rendered
      expect(find.text('All'), findsOneWidget);
      expect(find.text('💥 Action'), findsOneWidget);

      // Tap Action chip
      await tester.tap(find.text('💥 Action'));
      await tester.pumpAndSettle();

      expect(selected.label, 'Action');
    });
  });
}
