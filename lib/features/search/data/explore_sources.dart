import '../../../core/network/tmdb_client.dart';
import 'explore_genres.dart';

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

  /// Returns a display title that respects active genre and language filters.
  /// When discovery sorting is used for [topWeek] due to a genre or language
  /// filter, the title drops "This Week" since discovery sort reflects overall
  /// popularity rather than a weekly-constrained selection.
  /// Similarly, [trending] results use "Popular Now" when filtered since discovery
  /// sort reflects overall popularity rather than TMDB's unfiltered trending window.
  String titleWithGenre(GenreOption? genre, {String? languageName}) {
    final hasGenre = genre != null && !genre.isAll;
    final hasLang = languageName != null && languageName.trim().isNotEmpty;
    final hasFilter = hasGenre || hasLang;

    final baseTitle = (this == trending && hasFilter) ? 'Popular Now' : title;

    if (hasGenre && hasLang) {
      if (this == topWeek) return '${genre.displayName} in $languageName • Top 5';
      return '${genre.displayName} in $languageName • $baseTitle';
    }
    if (hasGenre) {
      if (this == topWeek) return '${genre.displayName} • Top 5';
      return '${genre.displayName} • $baseTitle';
    }
    if (hasLang) {
      if (this == topWeek) return 'Top 5 in $languageName';
      return '$baseTitle in $languageName';
    }
    return title;
  }

  /// Top 5 and Trending Now are the same TMDB list split in two, so they share
  /// one fetch.
  ExploreSection get source => this == topWeek ? trending : this;
}

/// A selectable language option for Explore and Surprise Me filters.
class ExploreLanguageOption {
  final String code;
  final String label;
  final String nativeName;
  final String flag;

  const ExploreLanguageOption({
    required this.code,
    required this.label,
    required this.nativeName,
    required this.flag,
  });
}

/// Languages offered by the language filter, sorted for Indian audience preference.
const List<ExploreLanguageOption> kExploreLanguages = [
  ExploreLanguageOption(code: 'hi', label: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
  ExploreLanguageOption(code: 'en', label: 'English', nativeName: 'English', flag: '🇬🇧'),
  ExploreLanguageOption(code: 'mr', label: 'Marathi', nativeName: 'मराठी', flag: '🇮🇳'),
  ExploreLanguageOption(code: 'ta', label: 'Tamil', nativeName: 'தமிழ்', flag: '🇮🇳'),
  ExploreLanguageOption(code: 'te', label: 'Telugu', nativeName: 'తెలుగు', flag: '🇮🇳'),
  ExploreLanguageOption(code: 'ml', label: 'Malayalam', nativeName: 'മലയാളം', flag: '🇮🇳'),
  ExploreLanguageOption(code: 'ko', label: 'Korean', nativeName: '한국어', flag: '🇰🇷'),
  ExploreLanguageOption(code: 'ja', label: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
  ExploreLanguageOption(code: 'es', label: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
  ExploreLanguageOption(code: 'fr', label: 'French', nativeName: 'Français', flag: '🇫🇷'),
];

/// Standard language names for Explore feed filters.
const Map<String, String> exploreLanguageNames = {
  'hi': 'Hindi',
  'en': 'English',
  'mr': 'Marathi',
  'ta': 'Tamil',
  'te': 'Telugu',
  'ml': 'Malayalam',
  'ko': 'Korean',
  'ja': 'Japanese',
  'es': 'Spanish',
  'fr': 'French',
};


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
  GenreOption? genre,
  bool forceRefresh = false,
}) {
  final isTv = type == ExploreMediaType.tv;
  final genreId =
      (genre != null && !genre.isAll) ? genre.genreIdFor(type) : null;
  final genreIds = genreId != null ? [genreId] : null;
  final effectiveLanguage = (genre != null &&
          genre.requiredLanguage != null &&
          genre.requiredLanguage!.isNotEmpty)
      ? genre.requiredLanguage
      : language;
  final hasGenreFilter = genreIds != null && genreIds.isNotEmpty;

  switch (section.source) {
    case ExploreSection.trending:
    case ExploreSection.topWeek:
      // TMDB trending endpoints take no language or genre filters. When either
      // is active, the section falls back to /discover by popularity (which
      // reflects overall popularity rather than a weekly-constrained window).
      if (effectiveLanguage == null && !hasGenreFilter) {
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
              genreIds: genreIds,
              language: effectiveLanguage,
              forceRefresh: forceRefresh,
              throwOnError: true,
            )
          : client.discoverMoviesWithFilters(
              page: page,
              sortBy: 'popularity.desc',
              genreIds: genreIds,
              language: effectiveLanguage,
              forceRefresh: forceRefresh,
              throwOnError: true,
            );

    // Placeholder source until onboarding collects genres; see ExploreFeedCubit.
    case ExploreSection.forYou:
      if (effectiveLanguage == null && !hasGenreFilter) {
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
              genreIds: genreIds,
              language: effectiveLanguage,
              minVoteCount: _topRatedVoteFloor(effectiveLanguage),
              forceRefresh: forceRefresh,
              throwOnError: true,
            )
          : client.discoverMoviesWithFilters(
              page: page,
              sortBy: 'vote_average.desc',
              genreIds: genreIds,
              language: effectiveLanguage,
              minVoteCount: _topRatedVoteFloor(effectiveLanguage),
              forceRefresh: forceRefresh,
              throwOnError: true,
            );

    case ExploreSection.newlyAdded:
      if (effectiveLanguage == null && !hasGenreFilter) {
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
              genreIds: genreIds,
              language: effectiveLanguage,
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
              genreIds: genreIds,
              language: effectiveLanguage,
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
          genreIds: genreIds,
          language: effectiveLanguage,
          firstAirDateGte: _date(tomorrow),
          minVoteCount: 0,
          forceRefresh: forceRefresh,
          throwOnError: true,
        );
      }
      return client.discoverMoviesWithFilters(
        page: page,
        sortBy: 'popularity.desc',
        genreIds: genreIds,
        language: effectiveLanguage,
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
