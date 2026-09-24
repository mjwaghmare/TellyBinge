import '../../../core/network/tmdb_client.dart';

enum ExploreMediaType {
  tv,
  movie;

  /// The `media_type` value TMDB uses, which the grid and details routing key on.
  String get tmdbType => this == tv ? 'tv' : 'movie';
}

/// The rows on the Explore feed, in display order.
enum ExploreSection {
  topWeek,
  forYou,
  trending,
  newlyAdded,
  comingSoon;

  String get title => switch (this) {
    topWeek => 'Top 5 This Week',
    forYou => 'For You',
    trending => 'Trending Now',
    newlyAdded => 'Newly Added',
    comingSoon => 'Coming Soon',
  };

  /// Top 5 and Trending Now are the same TMDB list split in two, so they share
  /// one fetch.
  ExploreSection get source => this == topWeek ? trending : this;
}

/// Fetches one page of an Explore section.
///
/// Both the feed rows and the See All grid page through here, so a row and its
/// grid always come from the same endpoint in the same order.
///
/// [forceRefresh] skips the cached copy but leaves it in place, so a failed
/// refresh still falls back to it. A failure with no cached fallback throws
/// rather than returning an empty page, so callers can tell it from the end
/// of the list.
///
/// TMDB's list endpoints (`/trending`, `/top_rated`, `/on_the_air`,
/// `/now_playing`) take no language filter, so when one is active the section
/// falls back to `/discover` with the closest equivalent sort and date bounds.
Future<List<dynamic>> fetchExploreSectionPage(
  TmdbClient client, {
  required ExploreMediaType type,
  required ExploreSection section,
  required int page,
  String? language,
  bool forceRefresh = false,
}) {
  final isTv = type == ExploreMediaType.tv;

  switch (section.source) {
    case ExploreSection.trending:
    case ExploreSection.topWeek:
      if (language == null) {
        return isTv
            ? client.getTrendingTvShows(
                page: page,
                forceRefresh: forceRefresh,
                throwOnError: true,
              )
            : client.getTrendingMovies(
                page: page,
                forceRefresh: forceRefresh,
                throwOnError: true,
              );
      }
      return isTv
          ? client.discoverTvShowsWithFilters(
              page: page,
              sortBy: 'popularity.desc',
              language: language,
              forceRefresh: forceRefresh,
              throwOnError: true,
            )
          : client.discoverMoviesWithFilters(
              page: page,
              sortBy: 'popularity.desc',
              language: language,
              forceRefresh: forceRefresh,
              throwOnError: true,
            );

    // Placeholder source until onboarding collects genres; see ExploreFeedCubit.
    case ExploreSection.forYou:
      if (language == null) {
        return isTv
            ? client.getTopRatedTvShows(
                page: page,
                forceRefresh: forceRefresh,
                throwOnError: true,
              )
            : client.getTopRatedMovies(
                page: page,
                forceRefresh: forceRefresh,
                throwOnError: true,
              );
      }
      return isTv
          ? client.discoverTvShowsWithFilters(
              page: page,
              sortBy: 'vote_average.desc',
              language: language,
              minVoteCount: _topRatedVoteFloor(language),
              forceRefresh: forceRefresh,
              throwOnError: true,
            )
          : client.discoverMoviesWithFilters(
              page: page,
              sortBy: 'vote_average.desc',
              language: language,
              minVoteCount: _topRatedVoteFloor(language),
              forceRefresh: forceRefresh,
              throwOnError: true,
            );

    case ExploreSection.newlyAdded:
      if (language == null) {
        // getUpcomingTvShows is backed by /tv/on_the_air.
        return isTv
            ? client.getUpcomingTvShows(
                page: page,
                forceRefresh: forceRefresh,
                throwOnError: true,
              )
            : client.getNowPlayingMovies(
                page: page,
                forceRefresh: forceRefresh,
                throwOnError: true,
              );
      }
      final today = DateTime.now();
      // Mirrors TMDB's own windows: on_the_air is an episode airing in the next
      // 7 days, now_playing is roughly the last six weeks of releases.
      return isTv
          ? client.discoverTvShowsWithFilters(
              page: page,
              sortBy: 'popularity.desc',
              language: language,
              airDateGte: _date(today),
              airDateLte: _date(today.add(const Duration(days: 7))),
              // Brand-new titles rarely have votes yet; the default floor of 1
              // would drop most of them.
              minVoteCount: 0,
              forceRefresh: forceRefresh,
              throwOnError: true,
            )
          : client.discoverMoviesWithFilters(
              page: page,
              sortBy: 'popularity.desc',
              language: language,
              primaryReleaseDateGte: _date(
                today.subtract(const Duration(days: 42)),
              ),
              primaryReleaseDateLte: _date(today),
              minVoteCount: 0,
              forceRefresh: forceRefresh,
              throwOnError: true,
            );

    case ExploreSection.comingSoon:
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      if (isTv) {
        return client.discoverTvShowsWithFilters(
          page: page,
          sortBy: 'popularity.desc',
          language: language,
          firstAirDateGte: _date(tomorrow),
          minVoteCount: 0,
          forceRefresh: forceRefresh,
          throwOnError: true,
        );
      }
      return client.discoverMoviesWithFilters(
        page: page,
        sortBy: 'popularity.desc',
        language: language,
        primaryReleaseDateGte: _date(tomorrow),
        minVoteCount: 0,
        forceRefresh: forceRefresh,
        throwOnError: true,
      );
    }
}

/// Vote floor for the rating-sorted For You fallback. The client's default
/// drops to 0 for regional Indian languages, which lets "10.0 from one vote" titles top the row.
int? _topRatedVoteFloor(String? language) => switch (language) {
  'mr' || 'ta' || 'te' || 'ml' => 15,
  _ => null,
};

String _date(DateTime d) => d.toIso8601String().split('T').first;
