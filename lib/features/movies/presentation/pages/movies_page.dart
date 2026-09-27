import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/animated_check_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../cubit/movie_watchlist_cubit.dart';
import '../cubit/movie_watchlist_state.dart';
import '../../../../core/widgets/app_empty_state.dart';

class MoviesPage extends StatefulWidget {
  final VoidCallback? onNavigateToExplore;
  const MoviesPage({super.key, this.onNavigateToExplore});

  @override
  State<MoviesPage> createState() => MoviesPageState();
}

class MoviesPageState extends State<MoviesPage> {
  final ScrollController watchlistScrollController = ScrollController();
  final ScrollController upcomingScrollController = ScrollController();

  bool _isGridView = true;

  @override
  void dispose() {
    watchlistScrollController.dispose();
    upcomingScrollController.dispose();
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

  String _getImageUrl(String? path, {String size = 'w500'}) {
    return AppConstants.tmdbImageUrl(path ?? '', size: size);
  }

  Map<int, int> _buildIndexMap(List<Map<String, dynamic>> items) {
    final map = <int, int>{};
    for (int i = 0; i < items.length; i++) {
      final id = (items[i]['id'] as num?)?.toInt();
      if (id != null) map[id] = i;
    }
    return map;
  }

  /// Lets a sliver delegate locate an already-built tile after the list order
  /// shifts (marking a movie watched moves it between sections), so the tile is
  /// reused instead of torn down and rebuilt at its new index.
  int? Function(Key) _findChildIndex(String prefix, Map<int, int> indexMap) {
    return (Key key) {
      if (key is ValueKey<String> && key.value.startsWith(prefix)) {
        final id = int.tryParse(key.value.substring(prefix.length));
        if (id != null) return indexMap[id];
      }
      return null;
    };
  }

  static final Map<String, DateTime?> _dateCache = {};
  static final Map<String, String> _formattedDateCache = {};

  static DateTime? _parseDateCached(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    return _dateCache.putIfAbsent(dateStr, () {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    });
  }

  String _formatRuntime(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String? _calculateDaysLeft(String releaseDateStr) {
    final releaseDate = _parseDateCached(releaseDateStr);
    if (releaseDate == null) return null;
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final targetDate = DateTime.utc(
      releaseDate.year,
      releaseDate.month,
      releaseDate.day,
    );
    final difference = targetDate.difference(today).inDays;
    return difference > 0 ? difference.toString() : null;
  }

  String _getUpcomingGroup(String releaseDateStr) {
    final releaseDate = _parseDateCached(releaseDateStr);
    if (releaseDate == null) return 'LATER';
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final targetDate = DateTime.utc(
      releaseDate.year,
      releaseDate.month,
      releaseDate.day,
    );
    final diff = targetDate.difference(today).inDays;
    return diff <= 7 ? 'THIS WEEK' : 'LATER';
  }

  String _formatReleaseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return _formattedDateCache.putIfAbsent(dateStr, () {
      final date = _parseDateCached(dateStr);
      if (date == null) return dateStr;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final String? uid = authState is Authenticated ? authState.user.uid : null;

    return BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
      builder: (context, state) {
        List<Map<String, dynamic>> watchlist = [];
        List<Map<String, dynamic>> upcoming = [];
        bool isLoading =
            state is MovieWatchlistLoading || state is MovieWatchlistInitial;

        if (state is MovieWatchlistSuccess) {
          final now = DateTime.now();

          String getMovieReleaseDate(Map<String, dynamic> movie) {
            return (movie['releaseDate'] ??
                        movie['release_date'] ??
                        movie['firstAirDate'] ??
                        movie['first_air_date'])
                    as String? ??
                '';
          }

          for (final movie in state.movies) {
            final releaseDateStr = getMovieReleaseDate(movie);
            final releaseDate = _parseDateCached(releaseDateStr);
            bool released = false;
            if (releaseDate != null) {
              final today = DateTime.utc(now.year, now.month, now.day);
              final relDay = DateTime.utc(
                releaseDate.year,
                releaseDate.month,
                releaseDate.day,
              );
              released = !relDay.isAfter(today);
            }

            if (released) {
              watchlist.add(movie);
            } else {
              upcoming.add(movie);
            }
          }

          // Sort watchlist by release date descending (newest released first)
          watchlist.sort((a, b) {
            final aDate = _parseDateCached(getMovieReleaseDate(a));
            final bDate = _parseDateCached(getMovieReleaseDate(b));
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          // Sort upcoming by release date ascending (soonest to release first)
          upcoming.sort((a, b) {
            final aDate = _parseDateCached(getMovieReleaseDate(a));
            final bDate = _parseDateCached(getMovieReleaseDate(b));
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
        }

        if (state is MovieWatchlistSuccess && state.movies.isEmpty) {
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                elevation: 0,
                toolbarHeight: 0, // Hide main toolbar for clean tab view
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'WATCH LIST'),
                    Tab(text: 'UPCOMING'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  AppEmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: 'Your Movie Watchlist Is Empty',
                    body:
                        'Discover movies on the Explore tab and add them to your watchlist to track what you want to see.',
                    primaryLabel: 'BROWSE MOVIES',
                    onPrimary: widget.onNavigateToExplore,
                  ),
                  AppEmptyState(
                    icon: Icons.event_outlined,
                    title: 'No Upcoming Movies',
                    body:
                        'You haven\'t added any unreleased movies yet. Browse the Explore tab to add movies you\'re waiting for.',
                    primaryLabel: 'BROWSE MOVIES',
                    onPrimary: widget.onNavigateToExplore,
                  ),
                ],
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              elevation: 0,
              toolbarHeight: 0, // Hide main toolbar for clean tab view
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'WATCH LIST'),
                  Tab(text: 'UPCOMING'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildWatchListView(watchlist, isLoading, uid),
                _buildUpcomingView(upcoming, isLoading, uid),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridToggle() {
    return GestureDetector(
      onTap: () {
        AppHaptics.lightImpact();
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
    );
  }

  Widget _buildWatchListView(
    List<Map<String, dynamic>> items,
    bool isLoading,
    String? uid,
  ) {
    if (!isLoading && items.isEmpty) {
      return AppEmptyState(
        icon: Icons.movie_filter_outlined,
        title: 'Your Movie Watchlist Is Empty',
        body: 'Discover movies on the Explore tab and add them to your watchlist to track what you want to see.',
        primaryLabel: 'BROWSE MOVIES',
        onPrimary: widget.onNavigateToExplore,
      );
    }

    final watchedHistory = items.where((i) => i['isWatched'] == true).toList();

    // Sort watchedHistory by watchedAt descending (newest first)
    watchedHistory.sort((a, b) {
      try {
        DateTime? normalize(Object? raw) {
          if (raw == null) return null;
          if (raw is DateTime) return raw;
          if (raw is String) {
            final trimmed = raw.trim();
            if (trimmed.isEmpty || trimmed == 'null') return null;
            return DateTime.tryParse(trimmed);
          }
          if (raw is num) {
            final intVal = raw.toInt();
            if (intVal < 10000000000) {
              return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
            }
            return DateTime.fromMillisecondsSinceEpoch(intVal);
          }
          try {
            final dynamic dyn = raw;
            if (dyn.toDate is Function) {
              return (dyn.toDate() as DateTime);
            }
          } catch (_) {}
          return null;
        }

        final aDate = normalize(a['watchedAt']);
        final bDate = normalize(b['watchedAt']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      } catch (_) {
        return 0;
      }
    });

    final watchNext = items.where((i) => i['isWatched'] != true).toList();

    // Generate dummy skeleton data if loading
    final displayWatchedHistory = isLoading
        ? <Map<String, dynamic>>[]
        : watchedHistory;
    final displayWatchNext = isLoading
        ? List.generate(
            4,
            (index) => {
              'id': index,
              'title': 'Loading Movie Title',
              'genres': 'Action, Adventure',
              'runtime': 120,
              'posterPath': '',
              'isWatched': false,
            },
          )
        : watchNext;

    final watchedHistoryIndexMap = _buildIndexMap(displayWatchedHistory);
    final watchNextIndexMap = _buildIndexMap(displayWatchNext);

    return Stack(
      children: [
        Skeletonizer(
          enabled: isLoading,
          child: RefreshIndicator.adaptive(
        onRefresh: () async {
          if (uid != null) {
            unawaited(
              context.read<MovieWatchlistCubit>().syncUpcomingMovies(
                uid,
                force: true,
              ),
            );
          }
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          controller: watchlistScrollController,
          physics: isLoading
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (displayWatchNext.isNotEmpty) ...[
              SliverMainAxisGroup(
                slivers: [
                  _buildStickyHeader('WATCH NEXT'),
                  if (_isGridView)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2 / 3,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => RepaintBoundary(
                            key: ValueKey(
                              'next_${displayWatchNext[index]['id']}',
                            ),
                            child: _buildMovieGridCard(
                              displayWatchNext[index],
                              uid,
                            ),
                          ),
                          childCount: displayWatchNext.length,
                          findChildIndexCallback: _findChildIndex(
                            'next_',
                            watchNextIndexMap,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => RepaintBoundary(
                          key: ValueKey(
                            'next_${displayWatchNext[index]['id']}',
                          ),
                          child: _buildMovieProgressCard(
                            displayWatchNext[index],
                            uid,
                          ),
                        ),
                        childCount: displayWatchNext.length,
                        findChildIndexCallback: _findChildIndex(
                          'next_',
                          watchNextIndexMap,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: AppSpacing.gapH32),
                ],
              ),
            ],
            if (displayWatchedHistory.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Opacity(
                  opacity: 0.5,
                  child: _buildCenteredHeaderRow('WATCHED HISTORY'),
                ),
              ),
              if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2 / 3,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => RepaintBoundary(
                        key: ValueKey(
                          'history_${displayWatchedHistory[index]['id']}',
                        ),
                        child: Opacity(
                          opacity: 0.5,
                          child: _buildMovieGridCard(
                            displayWatchedHistory[index],
                            uid,
                          ),
                        ),
                      ),
                      childCount: displayWatchedHistory.length,
                      findChildIndexCallback: _findChildIndex(
                        'history_',
                        watchedHistoryIndexMap,
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => RepaintBoundary(
                      key: ValueKey(
                        'history_${displayWatchedHistory[index]['id']}',
                      ),
                      child: Opacity(
                        opacity: 0.5,
                        child: _buildMovieProgressCard(
                          displayWatchedHistory[index],
                          uid,
                        ),
                      ),
                    ),
                    childCount: displayWatchedHistory.length,
                    findChildIndexCallback: _findChildIndex(
                      'history_',
                      watchedHistoryIndexMap,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: AppSpacing.gapH16),
            ],
            const SliverPadding(
              padding: EdgeInsets.only(bottom: AppSpacing.bottomTabPadding),
            ),
          ],
        ),
      ),
    ),
        Positioned(top: 14, right: 16, child: _buildGridToggle()),
      ],
    );
  }

  Widget _buildUpcomingView(
    List<Map<String, dynamic>> items,
    bool isLoading,
    String? uid,
  ) {
    if (!isLoading && items.isEmpty) {
      return AppEmptyState(
        icon: Icons.event_outlined,
        title: 'No Upcoming Movies',
        body: 'You haven\'t added any unreleased movies yet. Browse the Explore tab to add movies you\'re waiting for.',
        primaryLabel: 'BROWSE MOVIES',
        onPrimary: widget.onNavigateToExplore,
      );
    }

    final groups = ['THIS WEEK', 'LATER'];

    // Skeleton placeholder items
    final displayItems = isLoading
        ? List.generate(
            3,
            (index) => {
              'id': index,
              'title': 'Loading Movie Title',
              'genres': 'Family, Musical',
              'releaseDate': DateTime.now()
                  .add(const Duration(days: 4))
                  .toIso8601String(),
              'posterPath': '',
            },
          )
        : items;

    return Stack(
      children: [
        Skeletonizer(
          enabled: isLoading,
          child: RefreshIndicator.adaptive(
        onRefresh: () async {
          if (uid != null) {
            unawaited(
              context.read<MovieWatchlistCubit>().syncUpcomingMovies(
                uid,
                force: true,
              ),
            );
          }
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
        controller: upcomingScrollController,
        physics: isLoading
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: AppSpacing.xs)),
          ...groups.expand((group) {
            final grouped = displayItems.where((i) {
              final relDate = i['releaseDate'] as String? ?? '';
              return _getUpcomingGroup(relDate) == group;
            }).toList();

            if (grouped.isEmpty) return <Widget>[];

            final groupedIndexMap = _buildIndexMap(grouped);

            return [
              SliverMainAxisGroup(
                slivers: [
                  _buildStickyHeader(group),
                  if (_isGridView)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2 / 3,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => RepaintBoundary(
                            key: ValueKey('upcoming_${grouped[index]['id']}'),
                            child: _buildMovieGridCard(
                              grouped[index],
                              uid,
                              isUpcoming: true,
                            ),
                          ),
                          childCount: grouped.length,
                          findChildIndexCallback: _findChildIndex(
                            'upcoming_',
                            groupedIndexMap,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => RepaintBoundary(
                          key: ValueKey('upcoming_${grouped[index]['id']}'),
                          child: _buildUpcomingMovieCard(grouped[index], uid),
                        ),
                        childCount: grouped.length,
                        findChildIndexCallback: _findChildIndex(
                          'upcoming_',
                          groupedIndexMap,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: AppSpacing.gapH16),
                ],
              ),
            ];
          }),
          const SliverPadding(
            padding: EdgeInsets.only(bottom: AppSpacing.bottomTabPadding),
          ),
        ],
      ),
    ),
  ),
        Positioned(top: 14, right: 16, child: _buildGridToggle()),
      ],
    );
  }



  Widget _buildStickyHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _MovieStickyHeaderDelegate(
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
      child: Center(child: _buildSectionHeader(title)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
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
    );
  }

  Widget _buildMovieProgressCard(Map<String, dynamic> item, String? uid) {
    final title = item['title'] as String? ?? '';
    final posterPath = item['posterPath'] as String?;
    final runtime = (item['runtime'] as num?)?.toInt();
    final isWatched = item['isWatched'] as bool? ?? false;
    final movieId = (item['id'] as num?)?.toInt() ?? 0;
    final releaseDate = item['releaseDate'] as String? ?? '';
    final voteAverage = (item['voteAverage'] as num?)?.toDouble() ?? 0.0;
    final genres = item['genres'] as String? ?? '';

    bool hasFiredSlideHaptic = false;
    bool isMarkingAsWatched = false;
    bool isRemoving = false;

    return StatefulBuilder(
      builder: (context, setState) {
        void executeAction(DismissDirection direction) async {
          if (uid == null) return;
          if (direction == DismissDirection.endToStart) {
            if (!isWatched) {
              unawaited(AppHaptics.heavyImpact());
              setState(() => isMarkingAsWatched = true);
              await Future.delayed(const Duration(milliseconds: 400));
              if (context.mounted) {
                try {
                  await context.read<MovieWatchlistCubit>().toggleWatched(
                    uid: uid,
                    movieId: movieId,
                    isWatched: true,
                  );
                  if (context.mounted) {
                    AppSnackbar.showSuccess(
                      context,
                      'Marked "$title" as watched 🍿',
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    setState(() => isMarkingAsWatched = false);
                    AppSnackbar.showError(
                      context,
                      'Failed to mark "$title" as watched.',
                    );
                  }
                }
              }
            }
          } else {
            setState(() => isRemoving = true);
            await Future.delayed(const Duration(milliseconds: 300));
            if (context.mounted) {
              final movieTitle = title;
              final movieCubit = context.read<MovieWatchlistCubit>();
              final staged = movieCubit.stageRemoveMovie(
                uid: uid,
                movieId: movieId,
              );
              if (staged) {
                AppSnackbar.showWithAction(
                  context,
                  message: 'Removed "$movieTitle" from watchlist',
                  actionLabel: 'UNDO',
                  onAction: () {
                    AppHaptics.lightImpact();
                    movieCubit.cancelPendingMovieRemoval(movieId);
                  },
                );
              }
            }
          }
        }

        return Semantics(
          customSemanticsActions: {
            CustomSemanticsAction(
              label: isWatched ? 'Mark as unwatched' : 'Mark as watched',
            ): () => executeAction(DismissDirection.endToStart),
            const CustomSemanticsAction(label: 'Remove from watchlist'): () =>
                executeAction(DismissDirection.startToEnd),
          },
          child: Dismissible(
            key: ValueKey('movie_swipe_$movieId'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              executeAction(direction);
              return false;
            },
            onUpdate: (details) {
              if (details.progress > 0.05 && !hasFiredSlideHaptic) {
                setState(() => hasFiredSlideHaptic = true);
              }
              if (details.progress < 0.05 && hasFiredSlideHaptic) {
                setState(() => hasFiredSlideHaptic = false);
              }
            },
            background: Container(
              margin: AppSpacing.cardMargin,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(6.0),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: AppSpacing.xl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline, color: AppColors.textOnPrimary, size: 28),
                  AppSpacing.gapW8,
                  Text(
                    'REMOVE',
                    style: AppTextStyles.xsBold.copyWith(
                      color: AppColors.textOnPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            secondaryBackground: Container(
              margin: AppSpacing.cardMargin,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(6.0),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.xl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WATCHED',
                    style: AppTextStyles.xsBold.copyWith(
                      color: AppColors.textOnPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  AppSpacing.gapW8,
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.textOnPrimary,
                    size: 28,
                  ),
                ],
              ),
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailsPage(
                      movieId: movieId,
                      title: title,
                      posterPath: posterPath,
                    ),
                  ),
                );
              },
              child: Container(
                margin: AppSpacing.cardMargin,
                clipBehavior: Clip.antiAlias,
                constraints: const BoxConstraints(minHeight: 96.0),
              decoration: BoxDecoration(
                color: (isMarkingAsWatched || isRemoving)
                    ? context.adaptiveColor(
                        light: AppColors.lightSurfaceElevated,
                        dark: AppColors.surface,
                      )
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: (posterPath != null && posterPath.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: _getImageUrl(posterPath),
                                  width: 100,
                                  height: 96.0,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: 100,
                                        height: 96.0,
                                        color: context.adaptiveColor(
                                          light: AppColors.lightSurfaceElevated,
                                          dark: AppColors.surfaceLight,
                                        ),
                                        child: Skeleton.ignore(
                                          child: Icon(
                                            Icons.movie_outlined,
                                            color: context.adaptiveColor(
                                              light: AppColors.lightTextTertiary,
                                              dark: AppColors.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ),
                                  placeholder: (context, url) => Container(
                                    width: 100,
                                    height: 96.0,
                                    color: context.adaptiveColor(
                                      light: AppColors.lightSurfaceElevated,
                                      dark: AppColors.surfaceLight,
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator.adaptive(
                                              strokeWidth: 2,
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                    AppColors.primary,
                                                  ),
                                            ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 100,
                                  height: 96.0,
                                  color: context.adaptiveColor(
                                    light: AppColors.lightSurfaceElevated,
                                    dark: AppColors.surfaceLight,
                                  ),
                                  child: Skeleton.ignore(
                                    child: Icon(
                                      Icons.movie_outlined,
                                      color: context.adaptiveColor(
                                        light: AppColors.lightTextTertiary,
                                        dark: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.xxs,
                              AppSpacing.xs,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.mdBold.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                AppSpacing.gapH4,
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (voteAverage > 0.0) ...[
                                      Icon(
                                        Icons.star,
                                        color: AppColors.primary,
                                        size: 13,
                                      ),
                                      AppSpacing.gapW4,
                                      Text(
                                        voteAverage.toStringAsFixed(1),
                                        style: AppTextStyles.xsBold.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                      if (runtime != null && runtime > 0)
                                        Text(
                                          ' • ',
                                          style: AppTextStyles.xs.copyWith(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.6),
                                          ),
                                        ),
                                    ],
                                    if (runtime != null && runtime > 0)
                                      Text(
                                        _formatRuntime(runtime),
                                        style: AppTextStyles.xs.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                  ],
                                ),
                                if (releaseDate.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatReleaseDate(releaseDate),
                                    style: AppTextStyles.xs.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                                if (genres.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    genres,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.xs.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: AnimatedCheckButton(
                            isWatched: isWatched,
                            isLoading: isMarkingAsWatched || isRemoving,
                            isMovie: true,
                            size: 36.0,
                            onTap: () async {
                              if (uid != null && !isMarkingAsWatched && !isRemoving) {
                                if (!isWatched) {
                                  setState(() => isMarkingAsWatched = true);
                                  await Future.delayed(
                                    const Duration(milliseconds: 400),
                                  );
                                  if (context.mounted) {
                                    try {
                                      await context
                                          .read<MovieWatchlistCubit>()
                                          .toggleWatched(
                                            uid: uid,
                                            movieId: movieId,
                                            isWatched: true,
                                          );
                                      if (context.mounted) {
                                        AppSnackbar.showSuccess(
                                          context,
                                          'Added "$title" to Watched Movies 🍿',
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        setState(() => isMarkingAsWatched = false);
                                        AppSnackbar.showError(
                                          context,
                                          'Failed to mark "$title" as watched.',
                                        );
                                      }
                                    }
                                  }
                                } else {
                                  setState(() => isRemoving = true);
                                  await Future.delayed(
                                    const Duration(milliseconds: 300),
                                  );
                                  if (context.mounted) {
                                    try {
                                      await context
                                          .read<MovieWatchlistCubit>()
                                          .toggleWatched(
                                            uid: uid,
                                            movieId: movieId,
                                            isWatched: false,
                                          );
                                      if (context.mounted) {
                                        AppSnackbar.showInfo(
                                          context,
                                          'Moved "$title" back to Watch Next',
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        setState(() => isRemoving = false);
                                        AppSnackbar.showError(
                                          context,
                                          'Failed to update "$title".',
                                        );
                                      }
                                    }
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildUpcomingMovieCard(Map<String, dynamic> item, String? uid) {
    final title = item['title'] as String? ?? '';
    final posterPath = item['posterPath'] as String?;
    final releaseDate = item['releaseDate'] as String? ?? '';
    final isTBA = releaseDate.isEmpty || releaseDate.toUpperCase() == 'TBA';
    final daysLeft = _calculateDaysLeft(releaseDate);
    final movieId = (item['id'] as num?)?.toInt() ?? 0;
    final hasImage = posterPath != null && posterPath.isNotEmpty;
    final runtime = (item['runtime'] as num?)?.toInt();
    final voteAverage = (item['voteAverage'] as num?)?.toDouble() ?? 0.0;
    final genres = item['genres'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsPage(
              movieId: movieId,
              title: title,
              posterPath: posterPath,
            ),
          ),
        );
      },
      child: Container(
        margin: AppSpacing.cardMargin,
        clipBehavior: Clip.antiAlias,
        height: 96.0,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: _getImageUrl(posterPath),
                      width: 130,
                      height: 96.0,
                      fit: BoxFit.cover,
                      memCacheWidth: 390,
                      errorWidget: (context, url, error) =>
                          _buildBlueClapperboardPlaceholder(),
                      placeholder: (context, url) => Container(
                        width: 130,
                        height: 96.0,
                        color: Theme.of(context).brightness == Brightness.light
                            ? AppColors.lightSurfaceElevated
                            : AppColors.surfaceLight,
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
                    )
                  : _buildBlueClapperboardPlaceholder(),
            ),
            AppSpacing.gapW12,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.xxs,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mdBold.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    AppSpacing.gapH4,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (voteAverage > 0.0) ...[
                          Icon(Icons.star, color: AppColors.primary, size: 13),
                          AppSpacing.gapW4,
                          Text(
                            voteAverage.toStringAsFixed(1),
                            style: AppTextStyles.xsBold.copyWith(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          if (runtime != null && runtime > 0)
                            Text(
                              ' • ',
                              style: AppTextStyles.xs.copyWith(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                        if (runtime != null && runtime > 0)
                          Text(
                            _formatRuntime(runtime),
                            style: AppTextStyles.xs.copyWith(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                      ],
                    ),
                    if (releaseDate.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatReleaseDate(releaseDate),
                        style: AppTextStyles.xs.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        genres,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.xs.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isTBA) ...[
                    Text(
                      'TBA',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.lg.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ] else if (daysLeft != null) ...[
                    Text(
                      daysLeft,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.xl.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daysLeft == '1' ? 'DAY' : 'DAYS',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.xs.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.adaptiveColor(
                          light: Colors.transparent,
                          dark: AppColors.surface,
                        ),
                        border: Border.all(
                          color: context.adaptiveColor(
                            light: AppColors.lightTextTertiary,
                            dark: Colors.transparent,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check,
                          size: 20,
                          color: context.adaptiveColor(
                            light: AppColors.lightTextTertiary,
                            dark: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieGridCard(
    Map<String, dynamic> item,
    String? uid, {
    bool isUpcoming = false,
  }) {
    final posterPath = item['posterPath'] as String?;
    final movieId = (item['id'] as num?)?.toInt() ?? 0;

    final title = item['title'] as String? ?? 'Movie';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsPage(
              movieId: movieId,
              title: title,
              posterPath: posterPath,
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
                    imageUrl: _getImageUrl(posterPath),
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
                        Icons.movie_outlined,
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
                      Icons.movie_creation_outlined,
                      color: context.adaptiveColor(
                        light: AppColors.lightTextTertiary,
                        dark: AppColors.textTertiary,
                      ),
                    ),
                  ),
            if (item['releaseDate'] != null) ...[
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
                    final releaseDateStr = item['releaseDate'] as String;
                    final relDate = DateTime.tryParse(releaseDateStr);
                    if (relDate == null) return const SizedBox.shrink();

                    final now = DateTime.now();
                    final today = DateTime.utc(now.year, now.month, now.day);
                    final targetDate = DateTime.utc(
                      relDate.year,
                      relDate.month,
                      relDate.day,
                    );
                    final daysLeft = targetDate.difference(today).inDays;

                    final months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec',
                    ];
                    final dayStr = relDate.day.toString().padLeft(2, '0');
                    final monthStr = months[relDate.month - 1];

                    if (!isUpcoming) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayStr,
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
                            monthStr,
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
                    } else {
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
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlueClapperboardPlaceholder() {
    return Container(
      width: 130,
      height: 96.0,
      color: AppColors.accentBlue.withValues(alpha: 0.85),
      child: Center(
        child: Skeleton.ignore(
          child: Icon(
            Icons.movie_creation_outlined,
            color: AppColors.textOnPrimary.withValues(alpha: 0.7),
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _MovieStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _MovieStickyHeaderDelegate({required this.child});

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
  bool shouldRebuild(covariant _MovieStickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
