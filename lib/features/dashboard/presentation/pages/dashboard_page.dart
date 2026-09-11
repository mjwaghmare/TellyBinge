import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/tv_show_watchlist_cubit.dart';
import '../cubit/tv_show_watchlist_state.dart';
import '../cubit/watchlist_enrichment_cubit.dart';
import '../cubit/watch_history_cubit.dart';
import '../cubit/watch_history_state.dart';
import '../widgets/episode_progress_card.dart';
import '../widgets/watched_episode_card.dart';
import '../widgets/upcoming_episode_card.dart';
import '../models/enriched_show.dart';
import '../../domain/models/watch_history_item.dart';
import '../../../../core/services/widget_service.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToExplore;
  const DashboardPage({super.key, this.onNavigateToExplore});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {

  final ScrollController watchlistScrollController = ScrollController();
  final ScrollController upcomingScrollController = ScrollController();
  bool _isGridView = false;
  late WatchlistEnrichmentCubit _enrichmentCubit;
  late WatchHistoryCubit _watchHistoryCubit;

  @override
  void initState() {
    super.initState();
    _enrichmentCubit = WatchlistEnrichmentCubit(
      tmdbClient: context.read<TmdbClient>(),
    );
    _watchHistoryCubit = WatchHistoryCubit();
  }

  @override
  void dispose() {
    watchlistScrollController.dispose();
    upcomingScrollController.dispose();
    _enrichmentCubit.close();
    _watchHistoryCubit.close();
    super.dispose();
  }

  void scrollToTop() {
    if (watchlistScrollController.hasClients) {
      watchlistScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (upcomingScrollController.hasClients) {
      upcomingScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'WATCH LIST'),
              Tab(text: 'UPCOMING'),
            ],
          ),
        ),
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            if (authState is! Authenticated) {
              return Center(child: Text('Please log in to see your watchlist'));
            }
            final uid = authState.user.uid;
            _watchHistoryCubit.init(uid);
            return BlocConsumer<TvShowWatchlistCubit, TvShowWatchlistState>(
              listener: (context, state) {
                if (state is TvShowWatchlistSuccess) {
                  // Trigger background enrichment — does NOT block the UI.
                  _enrichmentCubit.enrichShows(state.shows, uid);

                  // Keep Home Screen widget in sync with latest data.
                  // Use the shows already in hand — syncWatchlistToWidget(uid)
                  // would re-read the whole collection on every stream emission,
                  // and enrichment writes re-trigger this listener.
                  WidgetService.syncWatchlistDataToWidget(state.shows);
                }
              },
              builder: (context, watchlistState) {
                if (watchlistState is TvShowWatchlistLoading ||
                    watchlistState is TvShowWatchlistInitial) {
                  // Shimmer skeleton while Firestore is loading
                  return _buildShimmerSkeleton();
                } else if (watchlistState is TvShowWatchlistError) {
                  return Center(
                    child: Text(
                      'Error: ${watchlistState.message}',
                      style: AppTextStyles.sm.copyWith(color: AppColors.error),
                    ),
                  );
                } else if (watchlistState is TvShowWatchlistSuccess) {
                  if (watchlistState.shows.isEmpty) {
                    return TabBarView(
                      children: [
                        _buildEmptyState(
                          'Your watchlist is empty.\nAdd shows from the Explore tab.',
                        ),
                        _buildEmptyState('No upcoming episodes scheduled.'),
                      ],
                    );
                  }

                  // Create EnrichedShow objects DIRECTLY from Firebase data.
                  // This is instant — no TMDB call needed.
                  final enrichedShows = watchlistState.shows
                      .map((data) => EnrichedShow.fromShowData(data))
                      .toList();

                  return MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: _enrichmentCubit),
                      BlocProvider.value(value: _watchHistoryCubit),
                    ],
                    child: TabBarView(
                      children: [
                        _buildWatchListView(
                          enrichedShows,
                          watchlistState.shows,
                          uid,
                        ),
                        _buildUpcomingView(enrichedShows),
                      ],
                    ),
                  );
                }
                return Center(child: Text('No data'));
              },
            );
          },
        ),
      ),
    );
  }

  // --- SHIMMER SKELETON (shown while Firestore loads) ---

  Widget _buildShimmerSkeleton() {
    final dummyShows = List.generate(
      4,
      (index) => EnrichedShow(
        rawShowData: {
          'id': -1,
          'name': 'Loading Show Name...',
          'backdropPath': '',
          'posterPath': '',
        },
        episodeCode: 'S01 | E01',
        episodeTitle: 'Loading episode title...',
        isPremiere: false,
        isNew: false,
        isUpToDate: false,
        targetSeason: 0,
        targetEpisode: 0,
        watchlistStatus: 'WATCH_NEXT',
        upcomingEpisodeCode: 'S01 | E01',
        upcomingEpisodeTitle: 'Loading...',
        upcomingIsPremiere: false,
        upcomingIsNew: false,
        hasUpcoming: false,
      ),
    );

    return TabBarView(
      children: [
        // Watchlist shimmer
        Skeletonizer(
          enabled: true,
          child: Stack(
            children: [
              ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.bottomTabPadding,
                ),
                children: [
                  _buildCenteredHeaderRow('WATCH NEXT'),
                  ...dummyShows
                      .take(2)
                      .map(
                        (item) => EpisodeProgressCard(
                          key: ValueKey(
                            'shimmer_wl_${dummyShows.indexOf(item)}',
                          ),
                          enrichedShow: item,
                          isGridView: _isGridView,
                        ),
                      ),
                  AppSpacing.gapH16,
                  _buildCenteredHeaderRow('HAVEN\'T STARTED'),
                  ...dummyShows
                      .skip(2)
                      .map(
                        (item) => EpisodeProgressCard(
                          key: ValueKey(
                            'shimmer_hs_${dummyShows.indexOf(item)}',
                          ),
                          enrichedShow: item,
                          isGridView: _isGridView,
                        ),
                      ),
                ],
              ),
              _buildGridToggle(),
            ],
          ),
        ),
        // Upcoming shimmer
        Skeletonizer(
          enabled: true,
          child: Stack(
            children: [
              ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.bottomTabPadding,
                ),
                children: [
                  _buildCenteredHeaderRow('TOMORROW'),
                  ...dummyShows
                      .take(2)
                      .map(
                        (item) => UpcomingEpisodeCard(
                          key: ValueKey(
                            'shimmer_up_${dummyShows.indexOf(item)}',
                          ),
                          enrichedShow: item,
                        ),
                      ),
                  AppSpacing.gapH16,
                  _buildCenteredHeaderRow('LATER'),
                  ...dummyShows
                      .skip(2)
                      .take(1)
                      .map(
                        (item) => UpcomingEpisodeCard(
                          key: ValueKey(
                            'shimmer_up_l_${dummyShows.indexOf(item)}',
                          ),
                          enrichedShow: item,
                        ),
                      ),
                ],
              ),
              _buildGridToggle(),
            ],
          ),
        ),
      ],
    );
  }

  // --- VIEW BUILDERS ---

  Widget _buildWatchListView(
    List<EnrichedShow> shows,
    List<Map<String, dynamic>> rawShows,
    String uid,
  ) {
    final watchNext = <EnrichedShow>[];
    final haventStarted = <EnrichedShow>[];

    for (var show in shows) {
      if ((show.rawShowData['status'] as String?) == 'STOPPED') continue;
      if (show.watchlistStatus == 'UPCOMING_ONLY') continue;
      if (show.watchlistStatus == 'UP_TO_DATE' ||
          show.watchlistStatus == 'FINISHED') {
        continue;
      }

      if (show.watchlistStatus == 'HAVENT_STARTED') {
        haventStarted.add(show);
      } else {
        watchNext.add(show);
      }
    }

    DateTime? getReleaseDate(EnrichedShow show) {
      final dateStr =
          (show.rawShowData['firstAirDate'] ??
                  show.rawShowData['first_air_date'] ??
                  show.rawShowData['releaseDate'] ??
                  show.rawShowData['release_date'])
              as String?;
      if (dateStr == null || dateStr.isEmpty) return null;
      return DateTime.tryParse(dateStr);
    }

    watchNext.sort((a, b) {
      final aDate = getReleaseDate(a);
      final bDate = getReleaseDate(b);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    haventStarted.sort((a, b) {
      final aDate = getReleaseDate(a);
      final bDate = getReleaseDate(b);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    if (watchNext.isEmpty && haventStarted.isEmpty) {
      // NOTE: We still want to show empty state if history is empty too,
      // but if history has items, we shouldn't show the empty state.
      // We will handle this by returning the builder anyway.
    }

    return Stack(
      children: [
        BlocBuilder<WatchHistoryCubit, WatchHistoryState>(
          builder: (context, historyState) {
            List<WatchHistoryItem> history = [];
            if (historyState is WatchHistoryLoaded) {
              history = List.of(historyState.history);
              // Defensive sort: latest watched first
              history.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
            }

            if (watchNext.isEmpty && haventStarted.isEmpty && history.isEmpty) {
              return _buildEmptyState('No shows in your Watch List yet.');
            }

            return RefreshIndicator.adaptive(
              onRefresh: () =>
                  _enrichmentCubit.enrichShows(rawShows, uid, force: true),
              child: CustomScrollView(
                controller: watchlistScrollController,
                slivers: [
                  if (watchNext.isNotEmpty)
                    SliverMainAxisGroup(
                      slivers: [
                        _buildStickyHeader('WATCH NEXT'),
                        SliverPadding(
                          padding: EdgeInsets.only(
                            bottom: AppSpacing.xl,
                            left: _isGridView ? AppSpacing.sm : 0,
                            right: _isGridView ? AppSpacing.sm : 0,
                          ),
                          sliver: _isGridView
                              ? SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 2 / 3,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final item = watchNext[index];
                                    return _buildShowGridCard(
                                      item,
                                      showProgress: true,
                                    );
                                  }, childCount: watchNext.length),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final item = watchNext[index];
                                    return EpisodeProgressCard(
                                      key: ValueKey(
                                        'show_${item.rawShowData['id']}',
                                      ),
                                      enrichedShow: item,
                                      isGridView: _isGridView,
                                    );
                                  }, childCount: watchNext.length),
                                ),
                        ),
                      ],
                    ),
                  if (haventStarted.isNotEmpty)
                    SliverMainAxisGroup(
                      slivers: [
                        _buildStickyHeader('HAVEN\'T STARTED'),
                        SliverPadding(
                          padding: EdgeInsets.only(
                            bottom: AppSpacing.xxl,
                            left: _isGridView ? AppSpacing.sm : 0,
                            right: _isGridView ? AppSpacing.sm : 0,
                          ),
                          sliver: _isGridView
                              ? SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 2 / 3,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final item = haventStarted[index];
                                    return _buildShowGridCard(
                                      item,
                                      showProgress: false,
                                    );
                                  }, childCount: haventStarted.length),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final item = haventStarted[index];
                                    return EpisodeProgressCard(
                                      key: ValueKey(
                                        'show_${item.rawShowData['id']}',
                                      ),
                                      enrichedShow: item,
                                      isGridView: _isGridView,
                                    );
                                  }, childCount: haventStarted.length),
                                ),
                        ),
                      ],
                    ),
                  if (history.isNotEmpty)
                    SliverMainAxisGroup(
                      slivers: [
                        _buildStickyHeader('WATCHED HISTORY'),
                        SliverPadding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xl,
                            top: AppSpacing.xxs,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = history[index];
                              return WatchedEpisodeCard(
                                key: ValueKey('history_${item.id}'),
                                item: item,
                              );
                            }, childCount: history.length),
                          ),
                        ),
                      ],
                    ),
                  const SliverPadding(
                    padding:
                        EdgeInsets.only(bottom: AppSpacing.bottomTabPadding),
                  ),
                ],
              ),
            );
          },
        ),
        _buildGridToggle(),
      ],
    );
  }

  Widget _buildUpcomingView(List<EnrichedShow> shows) {
    final Map<String, List<EnrichedShow>> groupedShows = {'TOMORROW': []};
    final Map<String, List<EnrichedShow>> weekdayGroups = {};
    final List<EnrichedShow> laterShows = [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];

    for (var show in shows) {
      if ((show.rawShowData['status'] as String?) == 'STOPPED') continue;
      if (!show.hasUpcoming || show.upcomingAirDate == null) {
        // Show doesn't have upcoming info — skip from upcoming tab
        continue;
      }

      final airDate = show.upcomingAirDate!;
      final targetDate = DateTime(airDate.year, airDate.month, airDate.day);
      final daysLeft = targetDate.difference(today).inDays;

      if (daysLeft < 0) {
        continue;
      } else if (daysLeft == 0) {
        continue;
      } else if (daysLeft == 1) {
        groupedShows['TOMORROW']!.add(show);
      } else if (daysLeft < 7) {
        final weekdayName = weekdays[targetDate.weekday - 1];
        weekdayGroups.putIfAbsent(weekdayName, () => []).add(show);
      } else {
        laterShows.add(show);
      }
    }

    // Sort LATER shows by upcoming air date ascending (earliest/soonest first)
    laterShows.sort((a, b) => a.upcomingAirDate!.compareTo(b.upcomingAirDate!));

    final List<Widget> slivers = [];

    void addGroup(String title, List<EnrichedShow> items) {
      if (items.isEmpty) return;

      final List<Widget> groupSlivers = [_buildStickyHeader(title)];

      if (_isGridView) {
        groupSlivers.add(
          SliverPadding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.xl,
              left: AppSpacing.sm,
              right: AppSpacing.sm,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2 / 3,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return _buildShowGridCard(
                  items[index],
                  showProgress: false,
                  isUpcoming: true,
                );
              }, childCount: items.length),
            ),
          ),
        );
      } else {
        groupSlivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return UpcomingEpisodeCard(
                key: ValueKey('upcoming_${items[index].rawShowData['id']}'),
                enrichedShow: items[index],
              );
            }, childCount: items.length),
          ),
        );
        groupSlivers.add(const SliverToBoxAdapter(child: AppSpacing.gapH16));
      }

      slivers.add(SliverMainAxisGroup(slivers: groupSlivers));
    }

    addGroup('TOMORROW', groupedShows['TOMORROW']!);

    for (int i = 2; i < 7; i++) {
      final targetDate = today.add(Duration(days: i));
      final weekdayName = weekdays[targetDate.weekday - 1];
      if (weekdayGroups.containsKey(weekdayName)) {
        addGroup(weekdayName, weekdayGroups[weekdayName]!);
      }
    }

    addGroup('LATER', laterShows);

    if (slivers.isEmpty) {
      return _buildEmptyState('No upcoming episodes scheduled.');
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: upcomingScrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.bottomTabPadding,
              ),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ],
        ),
        _buildGridToggle(),
      ],
    );
  }

  // --- COMPONENT BUILDERS ---

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.bottomTabPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tv_outlined,
              size: 64,
              color: context.adaptiveColor(
                light: AppColors.lightTextTertiary,
                dark: AppColors.textTertiary,
              ),
            ),
            AppSpacing.gapH16,
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.sm.copyWith(
                color:
                    Theme.of(context).textTheme.bodyMedium?.color ??
                    AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            AppSpacing.gapH20,
            SizedBox(
              width: 160,
              height: 40,
              child: ElevatedButton(
                onPressed: widget.onNavigateToExplore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'ADD SHOWS',
                  style: AppTextStyles.xsBold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridToggle() {
    return Positioned(
      top: 14,
      right: 16,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _isGridView = !_isGridView;
          });
        },
        child: Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: context.adaptiveColor(
              light: AppColors.lightSurfaceElevated,
              dark: AppColors.surfaceLight,
            ),
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Icon(
            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            color: Theme.of(context).iconTheme.color ?? AppColors.textSecondary,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildStickyHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: context.adaptiveColor(
                  light: AppColors.lightSurfaceElevated,
                  dark: AppColors.surfaceLight,
                ),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                title,
                style: AppTextStyles.xsBold.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredHeaderRow(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: context.adaptiveColor(
              light: AppColors.lightSurfaceElevated,
              dark: AppColors.surfaceLight,
            ),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            title,
            style: AppTextStyles.xsBold.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowGridCard(
    EnrichedShow show, {
    bool showProgress = false,
    bool isUpcoming = false,
  }) {
    final posterPath = show.rawShowData['posterPath'] as String?;
    final showId = show.rawShowData['id'] as int;
    final title = show.rawShowData['name'] as String? ?? 'Unknown TV Show';

    final watchedCount =
        (show.rawShowData['watchedEpisodes'] as List?)?.length ?? 0;
    final totalEpisodes = show.totalEpisodes;
    double progress = 0.0;
    if (totalEpisodes > 0) {
      progress = (watchedCount / totalEpisodes).clamp(0.0, 1.0);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => BlocProvider<ShowDetailsCubit>(
              create: (context) =>
                  ShowDetailsCubit(tmdbClient: context.read<TmdbClient>()),
              child: ShowDetailsPage(
                mediaId: showId,
                mediaType: 'tv',
                title: title,
                initialTabIndex: isUpcoming ? 0 : 1,
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: AppSpacing.allXXS,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          color: Theme.of(context).cardColor,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            posterPath != null && posterPath.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: AppConstants.tmdbImageUrl(posterPath, size: 'w500'),
                    fit: BoxFit.cover,
                    memCacheWidth: 360,
                    placeholder: (context, url) => Container(
                      color: context.adaptiveColor(
                        light: AppColors.lightSurfaceElevated,
                        dark: AppColors.surfaceLight,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: context.adaptiveColor(
                        light: AppColors.lightSurfaceElevated,
                        dark: AppColors.surfaceLight,
                      ),
                      child: Icon(
                        Icons.tv_outlined,
                        color: context.adaptiveColor(
                          light: AppColors.lightTextTertiary,
                          dark: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: context.adaptiveColor(
                      light: AppColors.lightSurfaceElevated,
                      dark: AppColors.surfaceLight,
                    ),
                    child: Icon(
                      Icons.tv_outlined,
                      color: context.adaptiveColor(
                        light: AppColors.lightTextTertiary,
                        dark: AppColors.textTertiary,
                      ),
                    ),
                  ),
            if (showProgress && totalEpisodes > 0) ...[
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6.0,
                  backgroundColor: Colors
                      .transparent, // Let image show through or slightly dim
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$watchedCount/$totalEpisodes',
                    style: AppTextStyles.xsBold.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
              ),
            ], // This closes the first if statement
            if (show.upcomingAirDate != null && isUpcoming) ...[
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.darkBackground.withValues(alpha: 0.95),
                        AppColors.darkBackground.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Builder(
                  builder: (context) {
                    final airDate = show.upcomingAirDate!;
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final targetDate = DateTime(
                      airDate.year,
                      airDate.month,
                      airDate.day,
                    );
                    final daysLeft = targetDate.difference(today).inDays;

                    // Upcoming tab: Just show days left
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$daysLeft',
                          style: AppTextStyles.xl.copyWith(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 4.0,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          daysLeft == 1 ? 'DAY' : 'DAYS',
                          style: AppTextStyles.smBold.copyWith(
                            color: AppColors.textOnPrimary,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 4.0,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
