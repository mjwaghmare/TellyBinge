import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/tmdb_client.dart';
import '../../data/explore_genres.dart';
import '../../data/explore_sources.dart';
import 'explore_feed_state.dart';

/// Loads the sectioned Explore feed (Top 5, For You, Trending Now, Newly
/// Added) for shows and movies.
///
/// Each section resolves and emits on its own, so a slow endpoint only keeps
/// its own row in skeleton. A failed or empty section ends up with no items,
/// and the page hides it.
///
/// For You currently shows Top Rated for everyone. Once onboarding collects
/// genres it should come from those instead, and be hidden when none were
/// picked.
class ExploreFeedCubit extends Cubit<ExploreFeedState> {
  ExploreFeedCubit({required this.tmdbClient, DateTime Function()? clock})
    : _now = clock ?? DateTime.now,
      super(const ExploreFeedState());

  final TmdbClient tmdbClient;
  final DateTime Function() _now;

  /// The cubit lives for the whole app session, so without this a long-lived
  /// app would keep showing last week's "This Week".
  static const Duration staleAfter = Duration(hours: 6);

  /// When each feed last started a full load or refresh.
  final Map<ExploreMediaType, DateTime> _loadedAt = {};

  /// The distinct fetches behind the feed (Top 5 is carved out of trending).
  static const List<ExploreSection> _sources = [
    ExploreSection.forYou,
    ExploreSection.trending,
    ExploreSection.newlyAdded,
    ExploreSection.comingSoon,
  ];

  /// Bumped on every reload so results from a superseded load (say, the
  /// language changed mid-flight) are dropped instead of overwriting the new
  /// ones.
  final Map<ExploreMediaType, int> _generation = {};

  static const _unspecifiedGenre = GenreOption(label: '__unspecified_genre__');

  /// Loads the feed for [type] if it hasn't been, or quietly refreshes it
  /// (rows stay on screen) once it is older than [staleAfter].
  /// [personalizedGenre] is derived from the user's watchlist history.
  /// [preferredGenres] is derived from onboarding/settings selections.
  void ensureLoaded(
    ExploreMediaType type, {
    Object? personalizedGenre = _unspecifiedGenre,
    List<GenreOption>? preferredGenres,
  }) {
    final currentFeed = state.feedFor(type);
    final isExplicitlySupplied = !identical(personalizedGenre, _unspecifiedGenre);
    final GenreOption? targetGenre = isExplicitlySupplied
        ? personalizedGenre as GenreOption?
        : currentFeed.personalizedGenre;
    final targetPreferred = preferredGenres ?? currentFeed.preferredGenres;

    final hasGenreChanged =
        isExplicitlySupplied && currentFeed.personalizedGenre != targetGenre;
    final hasPreferredChanged =
        preferredGenres != null && currentFeed.preferredGenres != targetPreferred;

    if (!state.feeds.containsKey(type) || hasGenreChanged || hasPreferredChanged) {
      if (hasGenreChanged || hasPreferredChanged) {
        emit(
          state.withFeed(
            type,
            (targetGenre == null
                    ? currentFeed.copyWith(clearPersonalizedGenre: true)
                    : currentFeed.copyWith(personalizedGenre: targetGenre))
                .copyWith(preferredGenres: targetPreferred),
          ),
        );
      }
      _load(
        type,
        keepItems: false,
        personalizedGenre: targetGenre,
        preferredGenres: targetPreferred,
        explicitPersonalizedGenre: isExplicitlySupplied,
      );
      return;
    }
    final loadedAt = _loadedAt[type];
    if (loadedAt != null && _now().difference(loadedAt) > staleAfter) {
      if (isExplicitlySupplied) {
        refresh(type, personalizedGenre: targetGenre, preferredGenres: targetPreferred);
      } else {
        refresh(type, preferredGenres: targetPreferred);
      }
    }
  }

  void setLanguage(ExploreMediaType type, String? language) {
    if (state.feedFor(type).language == language &&
        state.feeds.containsKey(type)) {
      return;
    }
    final feed = state.feedFor(type);
    emit(
      state.withFeed(
        type,
        ExploreFeed(
          language: language,
          genre: feed.genre,
          personalizedGenre: feed.personalizedGenre,
          preferredGenres: feed.preferredGenres,
        ),
      ),
    );
    _load(
      type,
      keepItems: false,
      personalizedGenre: feed.personalizedGenre,
      preferredGenres: feed.preferredGenres,
    );
  }

  void setGenre(ExploreMediaType type, GenreOption? genre) {
    final effectiveGenre = (genre != null && genre.isAll) ? null : genre;
    if (state.feedFor(type).genre == effectiveGenre &&
        state.feeds.containsKey(type)) {
      return;
    }
    final feed = state.feedFor(type);
    emit(
      state.withFeed(
        type,
        ExploreFeed(
          language: feed.language,
          genre: effectiveGenre,
          personalizedGenre: feed.personalizedGenre,
          preferredGenres: feed.preferredGenres,
        ),
      ),
    );
    _load(
      type,
      keepItems: false,
      personalizedGenre: feed.personalizedGenre,
      preferredGenres: feed.preferredGenres,
    );
  }

  /// Pull-to-refresh: refetches past the cache, leaving the current rows on
  /// screen until their replacements arrive.
  Future<void> refresh(
    ExploreMediaType type, {
    Object? personalizedGenre = _unspecifiedGenre,
    List<GenreOption>? preferredGenres,
  }) {
    final isExplicit = !identical(personalizedGenre, _unspecifiedGenre);
    return _load(
      type,
      keepItems: true,
      personalizedGenre: isExplicit
          ? personalizedGenre as GenreOption?
          : state.feedFor(type).personalizedGenre,
      preferredGenres: preferredGenres ?? state.feedFor(type).preferredGenres,
      explicitPersonalizedGenre: isExplicit,
    );
  }

  /// Reloads from scratch with skeletons, for the empty-feed Retry.
  Future<void> retry(ExploreMediaType type) => _load(
        type,
        keepItems: false,
        personalizedGenre: state.feedFor(type).personalizedGenre,
        preferredGenres: state.feedFor(type).preferredGenres,
      );

  /// Fetches one more page for a row whose visible count dropped too low
  /// after watchlist filtering. Only ever tops up once (page 1 -> 2).
  Future<void> fillRow(ExploreMediaType type, ExploreSection section) async {
    final row = state.feedFor(type).rowFor(section);
    if (row.isLoading || row.isLoadingMore || row.page != 1) return;

    final generation = _generation[type];
    final feed = state.feedFor(type);
    _emitRow(type, section, row.copyWith(isLoadingMore: true));

    List<dynamic> more;
    try {
      more = await fetchExploreSectionPage(
        tmdbClient,
        type: type,
        section: section,
        page: 2,
        language: feed.language,
        genre: feed.genre,
        personalizedGenre: feed.personalizedGenre,
        preferredGenres: feed.preferredGenres,
      );
    } catch (_) {
      more = const [];
    }
    if (isClosed || _generation[type] != generation) return;

    final current = state.feedFor(type).rowFor(section);
    _emitRow(
      type,
      section,
      current.copyWith(
        items: appendUniqueById(current.items, more),
        page: 2,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> _load(
    ExploreMediaType type, {
    required bool keepItems,
    GenreOption? personalizedGenre,
    List<GenreOption>? preferredGenres,
    bool explicitPersonalizedGenre = false,
  }) {
    final generation = (_generation[type] ?? 0) + 1;
    _generation[type] = generation;
    _loadedAt[type] = _now();

    final feed = state.feedFor(type);
    final effectivePersonalized = explicitPersonalizedGenre
        ? personalizedGenre
        : (personalizedGenre ?? feed.personalizedGenre);
    final effectivePreferred = preferredGenres ?? feed.preferredGenres;

    if (!keepItems) {
      emit(
        state.withFeed(
          type,
          ExploreFeed(
            language: feed.language,
            genre: feed.genre,
            personalizedGenre: effectivePersonalized,
            preferredGenres: effectivePreferred,
            rows: {for (final s in _sources) s: ExploreRow.loading},
          ),
        ),
      );
    } else if (feed.personalizedGenre != effectivePersonalized ||
        feed.preferredGenres != effectivePreferred) {
      emit(
        state.withFeed(
          type,
          (effectivePersonalized == null
                  ? feed.copyWith(clearPersonalizedGenre: true)
                  : feed.copyWith(personalizedGenre: effectivePersonalized))
              .copyWith(preferredGenres: effectivePreferred),
        ),
      );
    }

    return Future.wait(
      _sources.map(
        (section) => _loadSection(
          type,
          section,
          generation,
          isRefresh: keepItems,
          personalizedGenre: effectivePersonalized,
          preferredGenres: effectivePreferred,
        ),
      ),
    );
  }

  Future<void> _loadSection(
    ExploreMediaType type,
    ExploreSection section,
    int generation, {
    required bool isRefresh,
    GenreOption? personalizedGenre,
    List<GenreOption>? preferredGenres,
  }) async {
    final feed = state.feedFor(type);
    List<dynamic> items;
    try {
      items = await fetchExploreSectionPage(
        tmdbClient,
        type: type,
        section: section,
        page: 1,
        language: feed.language,
        genre: feed.genre,
        personalizedGenre: personalizedGenre ?? feed.personalizedGenre,
        preferredGenres: preferredGenres ?? feed.preferredGenres,
        forceRefresh: isRefresh,
      );
    } catch (_) {
      items = const [];
    }
    if (isClosed || _generation[type] != generation) return;

    // The client reports a failed request as an empty list. On refresh that
    // almost always means offline, so keep what is already on screen rather
    // than blanking the row.
    final current = state.feedFor(type).rowFor(section);
    if (isRefresh && items.isEmpty && current.items.isNotEmpty) return;

    _emitRow(type, section, ExploreRow(items: items, page: 1));
  }

  void _emitRow(ExploreMediaType type, ExploreSection section, ExploreRow row) {
    emit(state.withFeed(type, state.feedFor(type).withRow(section, row)));
  }
}

int? exploreIdOf(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw == null) return null;
  return int.tryParse(raw.toString());
}

/// Appends [newItems] to [existing], skipping ids already present. Order is
/// left exactly as TMDB returned it.
List<dynamic> appendUniqueById(List<dynamic> existing, List<dynamic> newItems) {
  if (newItems.isEmpty) return existing;
  final seen = <int>{for (final item in existing) ?exploreIdOf(item['id'])};
  final fresh = [
    for (final item in newItems)
      if (exploreIdOf(item['id']) case final id? when seen.add(id)) item,
  ];
  if (fresh.isEmpty) return existing;
  return [...existing, ...fresh];
}
