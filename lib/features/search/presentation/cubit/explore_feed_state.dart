import 'package:equatable/equatable.dart';

import '../../data/explore_sources.dart';

/// One fetched section. [items] is the raw, unfiltered TMDB list; watchlist
/// exclusion happens in the page, which owns the watchlist cubits.
class ExploreRow extends Equatable {
  final List<dynamic> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;

  const ExploreRow({
    this.items = const [],
    this.page = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
  });

  static const loading = ExploreRow(isLoading: true);

  ExploreRow copyWith({
    List<dynamic>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
  }) {
    return ExploreRow(
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [items, page, isLoading, isLoadingMore];
}

/// The feed for one media type. Rows are keyed by [ExploreSection.source], so
/// Top 5 and Trending Now share the `trending` row.
class ExploreFeed extends Equatable {
  final Map<ExploreSection, ExploreRow> rows;
  final String? language;

  const ExploreFeed({this.rows = const {}, this.language});

  ExploreRow rowFor(ExploreSection section) =>
      rows[section.source] ?? ExploreRow.loading;

  ExploreFeed withRow(ExploreSection section, ExploreRow row) =>
      ExploreFeed(rows: {...rows, section.source: row}, language: language);

  @override
  List<Object?> get props => [rows, language];
}

class ExploreFeedState extends Equatable {
  final Map<ExploreMediaType, ExploreFeed> feeds;

  const ExploreFeedState({this.feeds = const {}});

  ExploreFeed feedFor(ExploreMediaType type) =>
      feeds[type] ?? const ExploreFeed();

  ExploreFeedState withFeed(ExploreMediaType type, ExploreFeed feed) =>
      ExploreFeedState(feeds: {...feeds, type: feed});

  @override
  List<Object?> get props => [feeds];
}
