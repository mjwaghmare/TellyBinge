import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/search/data/explore_genres.dart';
import 'package:popverse/features/search/data/explore_sources.dart';

import 'fake_explore_tmdb_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeExploreTmdbClient client;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    client = FakeExploreTmdbClient();
  });

  Future<ExploreCall> fetch(
    ExploreMediaType type,
    ExploreSection section, {
    String? language,
    GenreOption? genre,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    client.calls.clear();
    await fetchExploreSectionPage(
      client,
      type: type,
      section: section,
      page: page,
      language: language,
      genre: genre,
      forceRefresh: forceRefresh,
    );
    expect(client.calls, hasLength(1));
    return client.calls.single;
  }

  group('without a language', () {
    test('each section uses its TMDB list endpoint', () async {
      const tv = ExploreMediaType.tv;
      const movie = ExploreMediaType.movie;
      expect((await fetch(tv, ExploreSection.topWeek)).method, 'trendingTv');
      expect((await fetch(tv, ExploreSection.trending)).method, 'trendingTv');
      expect((await fetch(tv, ExploreSection.forYou)).method, 'topRatedTv');
      expect((await fetch(tv, ExploreSection.newlyAdded)).method, 'onTheAirTv');
      expect(
        (await fetch(movie, ExploreSection.trending)).method,
        'trendingMovie',
      );
      expect(
        (await fetch(movie, ExploreSection.forYou)).method,
        'topRatedMovie',
      );
      expect(
        (await fetch(movie, ExploreSection.newlyAdded)).method,
        'nowPlayingMovie',
      );
      final movieUpcoming = await fetch(movie, ExploreSection.comingSoon);
      expect(movieUpcoming.method, 'discoverMovie');
      expect(movieUpcoming.releaseDateGte, isNotNull);
      expect(movieUpcoming.minVoteCount, 0);
      final tvUpcoming = await fetch(tv, ExploreSection.comingSoon);
      expect(tvUpcoming.method, 'discoverTv');
      expect(tvUpcoming.firstAirDateGte, isNotNull);
      expect(tvUpcoming.minVoteCount, 0);
    });

    test('passes page and forceRefresh through', () async {
      final call = await fetch(
        ExploreMediaType.tv,
        ExploreSection.trending,
        page: 3,
        forceRefresh: true,
      );
      expect(call.page, 3);
      expect(call.forceRefresh, isTrue);
    });
  });

  group('with a language', () {
    test('trending falls back to discover by popularity', () async {
      final call = await fetch(
        ExploreMediaType.tv,
        ExploreSection.trending,
        language: 'hi',
      );
      expect(call.method, 'discoverTv');
      expect(call.sortBy, 'popularity.desc');
      expect(call.language, 'hi');
    });

    test('newly added drops the vote floor and bounds the dates', () async {
      final tv = await fetch(
        ExploreMediaType.tv,
        ExploreSection.newlyAdded,
        language: 'hi',
      );
      expect(tv.method, 'discoverTv');
      expect(tv.minVoteCount, 0);
      expect(tv.airDateGte, isNotNull);
      expect(tv.airDateLte, isNotNull);
      expect(tv.airDateGte!.compareTo(tv.airDateLte!), lessThan(0));

      final movie = await fetch(
        ExploreMediaType.movie,
        ExploreSection.newlyAdded,
        language: 'hi',
      );
      expect(movie.method, 'discoverMovie');
      expect(movie.minVoteCount, 0);
      expect(
        movie.releaseDateGte!.compareTo(movie.releaseDateLte!),
        lessThan(0),
      );
    });

    test('coming soon filters future releases with popularity sort', () async {
      final tv = await fetch(
        ExploreMediaType.tv,
        ExploreSection.comingSoon,
        language: 'hi',
      );
      expect(tv.method, 'discoverTv');
      expect(tv.sortBy, 'popularity.desc');
      expect(tv.language, 'hi');
      expect(tv.firstAirDateGte, isNotNull);
      expect(tv.minVoteCount, 0);

      final movie = await fetch(
        ExploreMediaType.movie,
        ExploreSection.comingSoon,
        language: 'hi',
      );
      expect(movie.method, 'discoverMovie');
      expect(movie.sortBy, 'popularity.desc');
      expect(movie.language, 'hi');
      expect(movie.releaseDateGte, isNotNull);
      expect(movie.minVoteCount, 0);
    });

    test('for you sorts by rating with a Marathi vote floor', () async {
      final marathi = await fetch(
        ExploreMediaType.movie,
        ExploreSection.forYou,
        language: 'mr',
      );
      expect(marathi.sortBy, 'vote_average.desc');
      expect(marathi.minVoteCount, 15);

      final hindi = await fetch(
        ExploreMediaType.movie,
        ExploreSection.forYou,
        language: 'hi',
      );
      // Left to the client's default (100 for rating sorts).
      expect(hindi.minVoteCount, isNull);
    });
  });

  group('with a genre', () {
    const action = GenreOption(
      label: 'Action',
      emoji: '💥',
      movieGenreId: 28,
      tvGenreId: 10759,
    );

    test('trending and top week fall back to discover with genreIds', () async {
      final tv = await fetch(
        ExploreMediaType.tv,
        ExploreSection.trending,
        genre: action,
      );
      expect(tv.method, 'discoverTv');
      expect(tv.sortBy, 'popularity.desc');
      expect(tv.genreIds, [10759]);

      final movie = await fetch(
        ExploreMediaType.movie,
        ExploreSection.topWeek,
        genre: action,
      );
      expect(movie.method, 'discoverMovie');
      expect(movie.sortBy, 'popularity.desc');
      expect(movie.genreIds, [28]);
    });

    test('coming soon filters future releases with genreIds', () async {
      final movie = await fetch(
        ExploreMediaType.movie,
        ExploreSection.comingSoon,
        genre: action,
      );
      expect(movie.method, 'discoverMovie');
      expect(movie.sortBy, 'popularity.desc');
      expect(movie.genreIds, [28]);
      expect(movie.releaseDateGte, isNotNull);
    });

    test('anime genre applies required Japanese language and genre 16', () async {
      const anime = GenreOption(
        label: 'Anime',
        emoji: '🌸',
        movieGenreId: 16,
        tvGenreId: 16,
        requiredLanguage: 'ja',
      );
      final call = await fetch(
        ExploreMediaType.tv,
        ExploreSection.trending,
        genre: anime,
      );
      expect(call.method, 'discoverTv');
      expect(call.genreIds, [16]);
      expect(call.language, 'ja');
    });

    test('all genre falls back to default list endpoints', () async {
      final call = await fetch(
        ExploreMediaType.tv,
        ExploreSection.trending,
        genre: const GenreOption(label: 'All'),
      );
      expect(call.method, 'trendingTv');
      expect(call.genreIds, isNull);
    });

    test('topWeek drops weekly claim when genre is active', () {
      expect(ExploreSection.topWeek.titleWithGenre(null), 'Top 5 This Week');
      expect(
        ExploreSection.topWeek.titleWithGenre(const GenreOption(label: 'All')),
        'Top 5 This Week',
      );
      expect(
        ExploreSection.topWeek.titleWithGenre(action),
        '💥 Action • Top 5',
      );
      expect(
        ExploreSection.trending.titleWithGenre(null),
        'Trending Now',
      );
      expect(
        ExploreSection.trending.titleWithGenre(const GenreOption(label: 'All')),
        'Trending Now',
      );
      expect(
        ExploreSection.trending.titleWithGenre(action),
        '💥 Action • Popular Now',
      );
      expect(
        ExploreSection.topWeek.titleWithGenre(action, languageName: 'Korean'),
        '💥 Action in Korean • Top 5',
      );
      expect(
        ExploreSection.topWeek.titleWithGenre(null, languageName: 'Korean'),
        'Top 5 in Korean',
      );
      expect(
        ExploreSection.trending.titleWithGenre(null, languageName: 'Korean'),
        'Popular Now in Korean',
      );
      expect(
        ExploreSection.trending.titleWithGenre(action, languageName: 'Korean'),
        '💥 Action in Korean • Popular Now',
      );
    });
  });

  group('ExploreLanguageOption & kExploreLanguages', () {
    test('contains expected language codes, names, and flags', () {
      expect(kExploreLanguages, isNotEmpty);
      expect(kExploreLanguages.map((l) => l.code).toList(), [
        'hi',
        'en',
        'mr',
        'ta',
        'te',
        'ml',
        'ko',
        'ja',
        'es',
        'fr',
      ]);

      for (final lang in kExploreLanguages) {
        expect(lang.code, isNotEmpty);
        expect(lang.label, isNotEmpty);
        expect(lang.nativeName, isNotEmpty);
        expect(lang.flag, isNotEmpty);
        expect(exploreLanguageNames[lang.code], lang.label);
      }
    });

    test('supports Hindi and Marathi native display', () {
      final hi = kExploreLanguages.firstWhere((l) => l.code == 'hi');
      expect(hi.label, 'Hindi');
      expect(hi.nativeName, 'हिन्दी');
      expect(hi.flag, '🇮🇳');

      final mr = kExploreLanguages.firstWhere((l) => l.code == 'mr');
      expect(mr.label, 'Marathi');
      expect(mr.nativeName, 'मराठी');
      expect(mr.flag, '🇮🇳');
    });
  });
}

