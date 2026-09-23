import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../data/explore_sources.dart';
import '../cubit/explore_feed_cubit.dart';
import '../cubit/explore_feed_state.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../widgets/explore_poster_grid.dart';
import '../widgets/explore_section_row.dart';
import '../widgets/watchlisted_ids_builder.dart';
import 'explore_see_all_page.dart';

class SearchPage extends StatefulWidget {
  final ValueNotifier<int>? subTabNotifier;
  final ValueNotifier<int>? mainTabNotifier;
  const SearchPage({super.key, this.subTabNotifier, this.mainTabNotifier});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  /// A row with fewer than this left after watchlist filtering fetches one
  /// more page: enough to fill its 5 slots and still know whether See All has
  /// anything more to show.
  static const int _minRowItems = 6;

  final TextEditingController _showsSearchController = TextEditingController();
  final TextEditingController _moviesSearchController = TextEditingController();
  final ScrollController _showsFeedScrollController = ScrollController();
  final ScrollController _moviesFeedScrollController = ScrollController();
  final ScrollController _showsSearchScrollController = ScrollController();
  final ScrollController _moviesSearchScrollController = ScrollController();
  late TabController _tabController;

  /// One search per tab, so a query in one never disturbs the other.
  late final SearchCubit _showsSearch;
  late final SearchCubit _moviesSearch;

  int _previousTabIndex = 0;

  /// Languages offered by the language filter, by TMDB code.
  static const Map<String, String> _languageNames = {
    'hi': 'Hindi',
    'mr': 'Marathi',
  };

  static ExploreMediaType _typeOf(bool isTv) =>
      isTv ? ExploreMediaType.tv : ExploreMediaType.movie;

  TextEditingController _searchControllerFor(bool isTv) =>
      isTv ? _showsSearchController : _moviesSearchController;

  SearchCubit _searchCubitFor(bool isTv) => isTv ? _showsSearch : _moviesSearch;

  bool _isSearching(bool isTv) =>
      _searchControllerFor(isTv).text.trim().length >=
      SearchCubit.minQueryLength;

  String _queryFor(bool isTv) => _searchControllerFor(isTv).text.trim();

  void _handleSubTabChange() {
    if (widget.subTabNotifier != null &&
        _tabController.index != widget.subTabNotifier!.value) {
      _tabController.animateTo(widget.subTabNotifier!.value);
    }
  }

  /// Leaving the Explore tab resets search and the language filter.
  void _resetAllFiltersAndSearch() {
    FocusManager.instance.primaryFocus?.unfocus();

    for (final controller in [
      _showsFeedScrollController,
      _moviesFeedScrollController,
      _showsSearchScrollController,
      _moviesSearchScrollController,
    ]) {
      if (controller.hasClients) controller.jumpTo(0);
    }

    final feedCubit = context.read<ExploreFeedCubit>();
    for (final isTv in const [true, false]) {
      if (_searchControllerFor(isTv).text.isNotEmpty) {
        _searchControllerFor(isTv).clear();
        _searchCubitFor(isTv).clear();
      }
      final type = _typeOf(isTv);
      if (feedCubit.state.feedFor(type).language != null) {
        feedCubit.setLanguage(type, null);
        _searchCubitFor(isTv).setLanguage(null);
      }
    }
  }

  void _handleMainTabChange() {
    if (widget.mainTabNotifier == null) return;
    if (widget.mainTabNotifier!.value == 2) {
      // Coming back to Explore: reload the visible feed if it has gone stale.
      context.read<ExploreFeedCubit>().ensureLoaded(
        _typeOf(_tabController.index == 0),
      );
    } else {
      _resetAllFiltersAndSearch();
    }
  }

  @override
  void initState() {
    super.initState();
    final tmdbClient = context.read<TmdbClient>();
    _showsSearch = SearchCubit(tmdbClient: tmdbClient, isTv: true);
    _moviesSearch = SearchCubit(tmdbClient: tmdbClient, isTv: false);
    if (widget.mainTabNotifier != null) {
      widget.mainTabNotifier!.addListener(_handleMainTabChange);
    }
    _tabController = TabController(length: 2, vsync: this);
    if (widget.subTabNotifier != null) {
      _tabController.index = widget.subTabNotifier!.value;
      widget.subTabNotifier!.addListener(_handleSubTabChange);
    }
    _previousTabIndex = _tabController.index;

    _tabController.addListener(() {
      if (_tabController.index != _previousTabIndex) {
        _previousTabIndex = _tabController.index;

        // 1. Unfocus keyboard when switching subtabs
        FocusManager.instance.primaryFocus?.unfocus();

        // 2. Load (or refresh, if stale) the feed for the tab now showing
        context.read<ExploreFeedCubit>().ensureLoaded(
          _typeOf(_tabController.index == 0),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ExploreFeedCubit>().ensureLoaded(
        _typeOf(_tabController.index == 0),
      );
    });

    _showsSearchScrollController.addListener(() => _onSearchScroll(true));
    _moviesSearchScrollController.addListener(() => _onSearchScroll(false));
  }

  void _onSearchScroll(bool isTv) {
    final controller = isTv
        ? _showsSearchScrollController
        : _moviesSearchScrollController;
    if (!controller.hasClients) return;

    final currentState = _searchCubitFor(isTv).state;
    if (currentState is! SearchResultsSuccess ||
        currentState.isLoadingMore ||
        currentState.hasReachedMax) {
      return;
    }

    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 400) {
      _searchCubitFor(isTv).loadMore();
    }
  }

  @override
  void dispose() {
    widget.subTabNotifier?.removeListener(_handleSubTabChange);
    widget.mainTabNotifier?.removeListener(_handleMainTabChange);
    _showsSearchController.dispose();
    _moviesSearchController.dispose();
    _showsFeedScrollController.dispose();
    _moviesFeedScrollController.dispose();
    _showsSearchScrollController.dispose();
    _moviesSearchScrollController.dispose();
    _tabController.dispose();
    _showsSearch.close();
    _moviesSearch.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight:
            0, // Hide main toolbar for clean view, matching dashboard
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SHOWS'),
            Tab(text: 'MOVIES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _KeepAliveTab(
            key: const PageStorageKey('explore_shows_tab'),
            child: _buildTab(isTv: true),
          ),
          _KeepAliveTab(
            key: const PageStorageKey('explore_movies_tab'),
            child: _buildTab(isTv: false),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({required bool isTv}) {
    return Column(
      children: [
        _buildSearchBar(_searchControllerFor(isTv), isTv: isTv),
        Expanded(
          child: RefreshIndicator.adaptive(
            color: AppColors.primary,
            backgroundColor: Theme.of(context).cardColor,
            onRefresh: () async {
              if (_isSearching(isTv)) {
                await _searchCubitFor(isTv).executeSearch(_queryFor(isTv));
              } else {
                await context.read<ExploreFeedCubit>().refresh(_typeOf(isTv));
              }
            },
            child: BlocBuilder<SearchCubit, SearchState>(
              bloc: _searchCubitFor(isTv),
              builder: (context, searchState) => _isSearching(isTv)
                  ? _buildSearchResults(searchState, isTv: isTv)
                  : _buildFeed(isTv: isTv),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    TextEditingController controller, {
    required bool isTv,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: _searchCubitFor(isTv).onSearchTextChanged,
              decoration: InputDecoration(
                hintText: isTv ? 'Search shows...' : 'Search movies...',
                prefixIcon: Icon(
                  Icons.search,
                  color: context.adaptiveColor(
                    light: AppColors.lightTextTertiary,
                    dark: AppColors.textTertiary,
                  ),
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (value.text.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.clear,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppColors.lightTextTertiary
                                  : AppColors.textTertiary,
                            ),
                            onPressed: () {
                              controller.clear();
                              _searchCubitFor(isTv).clear();
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          BlocSelector<ExploreFeedCubit, ExploreFeedState, String?>(
            selector: (state) => state.feedFor(_typeOf(isTv)).language,
            builder: (context, language) => IconButton(
              onPressed: () => _showLanguageBottomSheet(isTv, language),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: AppSpacing.allXXS,
                    child: Text('🇮🇳', style: AppTextStyles.lg),
                  ),
                  if (language != null)
                    Positioned(
                      top: 6,
                      right: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageBottomSheet(bool isTv, String? language) {
    AppHaptics.lightImpact();
    final currentLanguage = language ?? 'all';

    AppActionSheetAction buildOption(
      String label,
      String subtitle,
      String value,
    ) {
      final isSelected = value == currentLanguage;
      return AppActionSheetAction(
        label: label,
        subtitle: subtitle,
        icon: Icons.translate_rounded,
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: context.primary, size: 22)
            : const SizedBox.shrink(),
        onTap: () {
          if (isSelected) return;
          AppHaptics.lightImpact();
          _applyLanguage(isTv, value == 'all' ? null : value);
        },
      );
    }

    AppActionSheet.show(
      context,
      title: 'Language',
      subtitle: isTv
          ? 'Filter TV shows by language'
          : 'Filter movies by language',
      actions: [
        buildOption('All', 'Every available language', 'all'),
        buildOption(_languageNames['hi']!, 'हिन्दी', 'hi'),
        buildOption(_languageNames['mr']!, 'मराठी', 'mr'),
      ],
    );
  }

  void _applyLanguage(bool isTv, String? language) {
    final feedScroll = isTv
        ? _showsFeedScrollController
        : _moviesFeedScrollController;
    if (feedScroll.hasClients) feedScroll.jumpTo(0);

    _searchCubitFor(isTv).setLanguage(language);
    context.read<ExploreFeedCubit>().setLanguage(_typeOf(isTv), language);

    if (_isSearching(isTv)) {
      _searchCubitFor(isTv).executeSearch(_queryFor(isTv));
    }
  }

  // ---------------------------------------------------------------------------
  // Feed
  // ---------------------------------------------------------------------------

  Widget _buildFeed({required bool isTv}) {
    final type = _typeOf(isTv);
    return BlocBuilder<ExploreFeedCubit, ExploreFeedState>(
      buildWhen: (previous, current) =>
          previous.feedFor(type) != current.feedFor(type),
      builder: (context, feedState) => WatchlistedIdsBuilder(
        type: type,
        builder: (context, watchlisted) =>
            _buildFeedList(type, feedState.feedFor(type), watchlisted),
      ),
    );
  }

  Widget _buildFeedList(
    ExploreMediaType type,
    ExploreFeed feed,
    Set<int> watchlisted,
  ) {
    final defaultType = type.tmdbType;
    final trendingRow = feed.rowFor(ExploreSection.trending);

    // Top 5 is the head of the trending list, deliberately left unfiltered so
    // it always reads as the actual top five.
    final topWeek = trendingRow.items.take(5).toList(growable: false);
    final topWeekIds = <int>{
      for (final item in topWeek) ?exploreIdOf(item['id']),
    };

    Set<int> excludedFor(ExploreSection section) =>
        section == ExploreSection.trending
        ? {...watchlisted, ...topWeekIds}
        : watchlisted;

    final rows = <Widget>[];
    var anyLoading = trendingRow.isLoading;

    if (trendingRow.isLoading || topWeek.isNotEmpty) {
      rows.add(
        ExploreTopWeekRow(
          key: const ValueKey(ExploreSection.topWeek),
          // TMDB trending can't be filtered by language, so with one active
          // this row is ranked by overall popularity, not this week's trend.
          title: switch (_languageNames[feed.language]) {
            final name? => 'Top 5 in $name',
            null => ExploreSection.topWeek.title,
          },
          items: topWeek,
          defaultType: defaultType,
          isLoading: trendingRow.isLoading,
        ),
      );
    }

    for (final section in const [
      ExploreSection.forYou,
      ExploreSection.trending,
      ExploreSection.newlyAdded,
    ]) {
      final row = feed.rowFor(section);
      anyLoading |= row.isLoading;
      if (row.isLoading) {
        rows.add(
          ExploreSectionRow(
            key: ValueKey(section),
            storageId: section.name,
            title: section.title,
            items: const [],
            defaultType: defaultType,
            isLoading: true,
          ),
        );
        continue;
      }

      final excluded = excludedFor(section);
      final items = [
        for (final item in row.items)
          if (exploreIdOf(item['id']) case final id?
              when !excluded.contains(id))
            item,
      ];

      if (row.items.isNotEmpty && items.length < _minRowItems) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<ExploreFeedCubit>().fillRow(type, section);
        });
      }
      if (items.isEmpty) continue;

      rows.add(
        ExploreSectionRow(
          key: ValueKey(section),
          storageId: section.name,
          title: section.title,
          items: items,
          isLoadingMore: row.isLoadingMore,
          defaultType: defaultType,
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExploreSeeAllPage(
                type: type,
                section: section,
                language: feed.language,
                excludedIds: section == ExploreSection.trending
                    ? topWeekIds
                    : const {},
              ),
            ),
          ),
        ),
      );
    }

    final feedScroll = type == ExploreMediaType.tv
        ? _showsFeedScrollController
        : _moviesFeedScrollController;

    if (rows.isEmpty && !anyLoading) {
      return _buildFeedEmpty(type, feedScroll);
    }

    return ListView(
      controller: feedScroll,
      physics: const AlwaysScrollableScrollPhysics(),
      // The feed is only a handful of rows. Keeping them all built stops a
      // row from being torn down when it scrolls out of view and rebuilt
      // (horizontal list, posters, Top 5 numbers) mid-fling as it returns.
      scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppSpacing.bottomTabPadding),
      children: rows,
    );
  }

  /// Every row came back empty — offline, or nothing in this language.
  Widget _buildFeedEmpty(ExploreMediaType type, ScrollController controller) {
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.bottomTabPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nothing to show right now.\nCheck your connection and try again.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.md.copyWith(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppColors.lightTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                  AppSpacing.gapH16,
                  TextButton(
                    onPressed: () =>
                        context.read<ExploreFeedCubit>().retry(type),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text('Retry', style: AppTextStyles.smBold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Search results
  // ---------------------------------------------------------------------------

  Widget _buildSearchResults(SearchState state, {required bool isTv}) {
    final defaultType = isTv ? 'tv' : 'movie';

    if (state is SearchError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading data: ${state.message}',
                textAlign: TextAlign.center,
                style: AppTextStyles.sm.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () =>
                    _searchCubitFor(isTv).executeSearch(_queryFor(isTv)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                ),
                child: Text('RETRY', style: AppTextStyles.smBold),
              ),
            ],
          ),
        ),
      );
    }

    // Loading, or still debouncing the first query.
    if (state is! SearchResultsSuccess) {
      return ExplorePosterGrid.skeleton(defaultType);
    }

    return ExplorePosterGrid(
      items: state.results,
      defaultType: defaultType,
      controller: isTv
          ? _showsSearchScrollController
          : _moviesSearchScrollController,
      isLoadingMore: state.isLoadingMore,
      hasLoadMoreError: state.hasLoadMoreError,
      onRetry: _searchCubitFor(isTv).loadMore,
      hasReachedMax: state.hasReachedMax,
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({super.key, required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
