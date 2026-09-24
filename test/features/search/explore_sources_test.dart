import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
