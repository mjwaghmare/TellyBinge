import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../cubit/movie_watchlist_cubit.dart';
import '../cubit/movie_watchlist_state.dart';

class MoviesPage extends StatefulWidget {
  final VoidCallback? onNavigateToExplore;
  const MoviesPage({super.key, this.onNavigateToExplore});

  @override
  State<MoviesPage> createState() => MoviesPageState();
}

class MoviesPageState extends State<MoviesPage> {
  final ScrollController watchlistScrollController = ScrollController();
  final ScrollController upcomingScrollController = ScrollController();
  final GlobalKey _watchNextKey = GlobalKey();
  bool _isGridView = false;

  @override
  void dispose() {
    watchlistScrollController.dispose();
    upcomingScrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (watchlistScrollController.hasClients) {
      watchlistScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    if (upcomingScrollController.hasClients) {
      upcomingScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  String _formatRuntime(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String? _calculateDaysLeft(String releaseDateStr) {
    if (releaseDateStr.isEmpty) return null;
    try {
      final releaseDate = DateTime.parse(releaseDateStr);
      final difference = releaseDate.difference(DateTime.now()).inDays;
      return difference > 0 ? difference.toString() : null;
    } catch (_) {
      return null;
    }
  }

  String _getUpcomingGroup(String releaseDateStr) {
    if (releaseDateStr.isEmpty) return 'LATER';
    try {
      final releaseDate = DateTime.parse(releaseDateStr);
      final diff = releaseDate.difference(DateTime.now()).inDays;
      if (diff <= 7) return 'THIS WEEK';
      return 'LATER';
    } catch (_) {
      return 'LATER';
    }
  }

  String _formatReleaseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
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
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
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

          for (final movie in state.movies) {
            final releaseDateStr = movie['releaseDate'] as String? ?? '';
            bool released = false;
            if (releaseDateStr.isNotEmpty) {
              try {
                final releaseDate = DateTime.parse(releaseDateStr);
                released = releaseDate.isBefore(now);
              } catch (_) {}
            }

            if (released) {
              watchlist.add(movie);
            } else {
              upcoming.add(movie);
            }
          }

          // Sort watchlist by release date descending (newest released first)
          watchlist.sort((a, b) {
            final aStr = a['releaseDate'] as String? ?? '';
            final bStr = b['releaseDate'] as String? ?? '';
            if (aStr.isEmpty) return 1;
            if (bStr.isEmpty) return -1;
            try {
              final aDate = DateTime.parse(aStr);
              final bDate = DateTime.parse(bStr);
              return bDate.compareTo(aDate);
            } catch (_) {
              return 0;
            }
          });

          // Sort upcoming by release date ascending (soonest to release first)
          upcoming.sort((a, b) {
            final aStr = a['releaseDate'] as String? ?? '';
            final bStr = b['releaseDate'] as String? ?? '';
            if (aStr.isEmpty) return 1;
            if (bStr.isEmpty) return -1;
            try {
              final aDate = DateTime.parse(aStr);
              final bDate = DateTime.parse(bStr);
              return aDate.compareTo(bDate);
            } catch (_) {
              return 0;
            }
          });
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
            body: Stack(
              children: [
                TabBarView(
                  children: [
                    _buildWatchListView(watchlist, isLoading, uid),
                    _buildUpcomingView(upcoming, isLoading, uid),
                  ],
                ),
                Positioned(top: 14, right: 16, child: _buildGridToggle()),
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
        HapticFeedback.lightImpact();
        setState(() {
          _isGridView = !_isGridView;
        });
      },
      child: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.grey[200]
              : AppColors.surfaceLight,
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
      return _buildEmptyState(
        'Your watchlist is empty.\nAdd movies from the Explore tab.',
      );
    }

    final watchedHistory = items.where((i) => i['isWatched'] == true).toList();
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

    return Skeletonizer(
      enabled: isLoading,
      child: CustomScrollView(
        controller: watchlistScrollController,
        physics: isLoading ? const NeverScrollableScrollPhysics() : null,
        center: _watchNextKey,
        slivers: [
          if (displayWatchedHistory.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Opacity(
                opacity: 0.5,
                child: _buildCenteredHeaderRow('WATCHED HISTORY'),
              ),
            ),
            if (_isGridView)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2 / 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Opacity(
                      opacity: 0.5,
                      child: _buildMovieGridCard(
                        displayWatchedHistory[index],
                        uid,
                      ),
                    ),
                    childCount: displayWatchedHistory.length,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Opacity(
                    opacity: 0.5,
                    child: _buildMovieProgressCard(
                      displayWatchedHistory[index],
                      uid,
                    ),
                  ),
                  childCount: displayWatchedHistory.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16.0)),
          ],
          if (displayWatchNext.isNotEmpty) ...[
            SliverMainAxisGroup(
              key: _watchNextKey,
              slivers: [
                _buildStickyHeader('WATCH NEXT'),
                if (_isGridView)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2 / 3,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildMovieGridCard(displayWatchNext[index], uid),
                        childCount: displayWatchNext.length,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildMovieProgressCard(displayWatchNext[index], uid),
                      childCount: displayWatchNext.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32.0)),
              ],
            ),
          ] else ...[
            SliverToBoxAdapter(
              key: _watchNextKey,
              child: const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingView(
    List<Map<String, dynamic>> items,
    bool isLoading,
    String? uid,
  ) {
    if (!isLoading && items.isEmpty) {
      return _buildEmptyState('No upcoming movies added.');
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

    return Skeletonizer(
      enabled: isLoading,
      child: CustomScrollView(
        controller: upcomingScrollController,
        physics: isLoading ? const NeverScrollableScrollPhysics() : null,
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 8.0)),
          ...groups.expand((group) {
            final grouped = displayItems.where((i) {
              final relDate = i['releaseDate'] as String? ?? '';
              return _getUpcomingGroup(relDate) == group;
            }).toList();

            if (grouped.isEmpty) return <Widget>[];

            return [
              SliverMainAxisGroup(
                slivers: [
                  _buildStickyHeader(group),
                  if (_isGridView)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2 / 3,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildMovieGridCard(
                            grouped[index],
                            uid,
                            isUpcoming: true,
                          ),
                          childCount: grouped.length,
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildUpcomingMovieCard(grouped[index], uid),
                        childCount: grouped.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16.0)),
                ],
              ),
            ];
          }),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24.0)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 64,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey[500]
                  : AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    Theme.of(context).textTheme.bodyMedium?.color ??
                    AppColors.textSecondary,
                fontSize: 14.0,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              height: 40,
              child: ElevatedButton(
                onPressed: widget.onNavigateToExplore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'ADD MOVIES',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _MovieStickyHeaderDelegate(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[200]
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(child: _buildSectionHeader(title)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[200]
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMovieProgressCard(Map<String, dynamic> item, String? uid) {
    final title = item['title'] as String? ?? '';
    final posterPath = item['posterPath'] as String?;
    final runtime = item['runtime'] as int?;
    final isWatched = item['isWatched'] as bool? ?? false;
    final movieId = item['id'] as int;
    final releaseDate = item['releaseDate'] as String? ?? '';
    final voteAverage = (item['voteAverage'] as num?)?.toDouble() ?? 0.0;
    final genres = item['genres'] as String? ?? '';

    bool hasFiredSlideHaptic = false;
    bool isMarkingAsWatched = false;
    bool isRemoving = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Dismissible(
          key: ValueKey('movie_swipe_$movieId'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (uid == null) return false;

            void executeAction() async {
              if (direction == DismissDirection.endToStart) {
                if (!isWatched) {
                  setState(() => isMarkingAsWatched = true);
                  await Future.delayed(const Duration(milliseconds: 600));
                  if (context.mounted) {
                    context.read<MovieWatchlistCubit>().toggleWatched(
                      uid: uid,
                      movieId: movieId,
                      isWatched: true,
                    );
                  }
                }
              } else {
                setState(() => isRemoving = true);
                await Future.delayed(const Duration(milliseconds: 600));
                if (context.mounted) {
                  context.read<MovieWatchlistCubit>().removeMovie(
                    uid: uid,
                    movieId: movieId,
                  );
                }
              }
            }

            executeAction();
            return false;
          },
          onUpdate: (details) {
            if (details.progress > 0.05 && !hasFiredSlideHaptic) {
              setState(() => hasFiredSlideHaptic = true);
              HapticFeedback.lightImpact();
            }
            if (details.progress < 0.05 && hasFiredSlideHaptic) {
              setState(() => hasFiredSlideHaptic = false);
            }
          },
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(6.0),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.delete_outline, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text(
                  'REMOVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(6.0),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'WATCHED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 10),
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      MovieDetailsPage(movieId: movieId),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.0, 1.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              clipBehavior: Clip.antiAlias,
              height: 96.0,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: (isMarkingAsWatched || isRemoving)
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(
                          isMarkingAsWatched
                              ? const Color(0xFF6B8E23)
                              : AppColors.error,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: CachedNetworkImage(
                            imageUrl: _getImageUrl(posterPath),
                            width: 100,
                            height: 96.0,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 100,
                              height: 96.0,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.grey[200]
                                  : AppColors.surfaceLight,
                              child: const Skeleton.ignore(
                                child: Icon(
                                  Icons.movie_outlined,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            placeholder: (context, url) => Container(
                              width: 100,
                              height: 96.0,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.grey[200]
                                  : AppColors.surfaceLight,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              8.0,
                              4.0,
                              8.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (voteAverage > 0.0) ...[
                                      Icon(
                                        Icons.star,
                                        color: AppColors.primary,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        voteAverage.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (runtime != null && runtime > 0)
                                        Text(
                                          ' • ',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.6),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                    ],
                                    if (runtime != null && runtime > 0)
                                      Text(
                                        _formatRuntime(runtime),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                  ],
                                ),
                                if (releaseDate.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatReleaseDate(releaseDate),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.6),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                                if (genres.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    genres,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.6),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: GestureDetector(
                            onTap: () async {
                              if (uid != null) {
                                if (!isWatched) {
                                  setState(() => isMarkingAsWatched = true);
                                } else {
                                  setState(() => isRemoving = true);
                                }
                                await Future.delayed(
                                  const Duration(milliseconds: 600),
                                );
                                if (context.mounted) {
                                  context
                                      .read<MovieWatchlistCubit>()
                                      .toggleWatched(
                                        uid: uid,
                                        movieId: movieId,
                                        isWatched: !isWatched,
                                      );
                                }
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isWatched
                                    ? AppColors.success
                                    : (Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.transparent
                                          : Colors.white),
                                border: isWatched
                                    ? null
                                    : Border.all(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Colors.grey[400]!
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.check,
                                  size: 20,
                                  color: isWatched
                                      ? Colors.white
                                      : (Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Colors.grey[500]
                                            : AppColors.textTertiary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
    final movieId = item['id'] as int;
    final hasImage = posterPath != null && posterPath.isNotEmpty;
    final runtime = item['runtime'] as int?;
    final voteAverage = (item['voteAverage'] as num?)?.toDouble() ?? 0.0;
    final genres = item['genres'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MovieDetailsPage(movieId: movieId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
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
                      errorWidget: (context, url, error) =>
                          _buildBlueClapperboardPlaceholder(),
                      placeholder: (context, url) => Container(
                        width: 130,
                        height: 96.0,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey[200]
                            : AppColors.surfaceLight,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : _buildBlueClapperboardPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 4.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (voteAverage > 0.0) ...[
                          Icon(Icons.star, color: AppColors.primary, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            voteAverage.toStringAsFixed(1),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (runtime != null && runtime > 0)
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.6),
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                        if (runtime != null && runtime > 0)
                          Text(
                            _formatRuntime(runtime),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                    if (releaseDate.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatReleaseDate(releaseDate),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        genres,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isTBA) ...[
                    Text(
                      'TBA',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ] else if (daysLeft != null) ...[
                    Text(
                      daysLeft,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daysLeft == '1' ? 'DAY' : 'DAYS',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontSize: 10.0,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.transparent
                            : Colors.white,
                        border: Border.all(
                          color:
                              Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[400]!
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check,
                          size: 20,
                          color:
                              Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[500]
                              : AppColors.textTertiary,
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
    final movieId = item['id'] as int;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MovieDetailsPage(movieId: movieId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(4.0),
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
                    placeholder: (context, url) => Container(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey[200]
                          : AppColors.surfaceLight,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey[200]
                          : AppColors.surfaceLight,
                      child: Icon(
                        Icons.movie_outlined,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey[500]
                            : AppColors.textTertiary,
                      ),
                    ),
                  )
                : Container(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[200]
                        : AppColors.surfaceLight,
                    child: Icon(
                      Icons.movie_creation_outlined,
                      color: AppColors.textTertiary,
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
                        Colors.black.withValues(alpha: 0.95),
                        Colors.black.withValues(alpha: 0.4),
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
                    final today = DateTime(now.year, now.month, now.day);
                    final targetDate = DateTime(
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              shadows: [
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              shadows: [
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              shadows: [
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              shadows: [
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
      color: const Color(0xFF1E88E5).withValues(alpha: 0.85),
      child: Center(
        child: Skeleton.ignore(
          child: Icon(
            Icons.movie_creation_outlined,
            color: Colors.white70,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _MovieStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  bool _wasPinned = false;

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
    final isPinned = shrinkOffset > 0;
    if (isPinned && !_wasPinned) {
      HapticFeedback.lightImpact();
    }
    _wasPinned = isPinned;
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _MovieStickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
