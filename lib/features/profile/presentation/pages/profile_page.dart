import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../../../../core/network/tmdb_client.dart';
import '../widgets/shows_filter_bottom_sheet.dart';
import '../widgets/movies_filter_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../cubit/profile_heatmap_cubit.dart';
import '../cubit/profile_heatmap_state.dart';
import 'settings_page.dart';
import '../../../../core/services/widget_service.dart';

class HorizontalItem {
  final int movieId;
  final String title;
  final String imageUrl;
  final double voteAverage;
  final String releaseDate;
  final bool isFavorite;
  final bool isWatched;
  final bool isMovie;
  final bool isStopped;
  final String? addedAt;
  final String? watchedAt;
  final int watchedCount;
  final int totalEpisodes;

  HorizontalItem({
    required this.movieId,
    required this.title,
    required this.imageUrl,
    required this.voteAverage,
    required this.releaseDate,
    this.isFavorite = false,
    this.isWatched = false,
    this.isMovie = true,
    this.isStopped = false,
    this.addedAt,
    this.watchedAt,
    this.watchedCount = 0,
    this.totalEpisodes = 0,
  });
}

class ProfilePage extends StatefulWidget {
  final ValueListenable<int>? tabNotifier;

  const ProfilePage({super.key, this.tabNotifier});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  String _movieSortOption = 'Last Added';
  String _movieProgressOption = 'All';
  String _showSortOption = 'Last added';
  String _showProgressOption = 'All';

  bool _isFilteringMovies = false;
  bool _isFilteringShows = false;

  late TabController _tabController;
  int _previousTabIndex = 0;
  DateTime _heatmapMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late PageController _heatmapPageController;
  int _heatmapPageIndex = 0;
  bool _isHeatmapExpanded = false;
  bool _isLocalLoading = false;
  Timer? _shimmerTimer;

  String? _lastPublishedStatsKey;
  int _lastWatchedMoviesCount = 0;
  int _lastTotalMinutes = 0;
  int _lastWatchedShowsCount = 0;
  int _lastTotalEpisodesCount = 0;
  int _lastTotalShowMinutes = 0;

  String _formatTime(int mins) {
    if (mins == 0) return '0m';
    final d = mins ~/ (24 * 60);
    final h = (mins % (24 * 60)) ~/ 60;
    final m = mins % 60;
    List<String> parts = [];
    if (d > 0) parts.add('${d}d');
    if (h > 0) parts.add('${h}h');
    if (m > 0 || parts.isEmpty) parts.add('${m}m');
    return parts.join(' ');
  }

  ({
    int watchedMoviesCount,
    int totalMovieMinutes,
    int watchedShowsCount,
    int totalEpisodesCount,
    int totalShowMinutes,
  }) _calculateProfileStats(
    MovieWatchlistState watchlistState,
    TvShowWatchlistState showWatchlistState,
  ) {
    int watchedMoviesCount = 0;
    int totalMovieMinutes = 0;
    if (watchlistState is MovieWatchlistSuccess) {
      final watchedMovies = watchlistState.movies
          .where((m) => m['isWatched'] as bool? ?? false);
      watchedMoviesCount = watchedMovies.length;
      totalMovieMinutes = watchedMovies
          .map((m) => (m['runtime'] as num?)?.toInt() ?? 0)
          .fold<int>(0, (sum, element) => sum + element);
    }

    int watchedShowsCount = 0;
    int totalEpisodesCount = 0;
    if (showWatchlistState is TvShowWatchlistSuccess) {
      watchedShowsCount = showWatchlistState.shows.length;
      totalEpisodesCount = showWatchlistState.shows
          .map((s) => (List<dynamic>.from(s['watchedEpisodes'] ?? [])).length)
          .fold<int>(0, (sum, element) => sum + element);
    }

    final totalShowMinutes = totalEpisodesCount * 45;

    return (
      watchedMoviesCount: watchedMoviesCount,
      totalMovieMinutes: totalMovieMinutes,
      watchedShowsCount: watchedShowsCount,
      totalEpisodesCount: totalEpisodesCount,
      totalShowMinutes: totalShowMinutes,
    );
  }

  void _checkAndUpdateWidgetStats(
    String displayName,
    MovieWatchlistState watchlistState,
    TvShowWatchlistState showWatchlistState,
  ) {
    final stats = _calculateProfileStats(watchlistState, showWatchlistState);

    if (watchlistState is MovieWatchlistSuccess) {
      _lastWatchedMoviesCount = stats.watchedMoviesCount;
      _lastTotalMinutes = stats.totalMovieMinutes;
    }

    if (showWatchlistState is TvShowWatchlistSuccess) {
      _lastWatchedShowsCount = stats.watchedShowsCount;
      _lastTotalEpisodesCount = stats.totalEpisodesCount;
      _lastTotalShowMinutes = stats.totalShowMinutes;
    }

    final userName = displayName.isNotEmpty ? displayName : 'User';
    final showsFormattedTime = _formatTime(_lastTotalShowMinutes);
    final moviesFormattedTime = _formatTime(_lastTotalMinutes);

    final newKey =
        '$userName|$_lastWatchedShowsCount|$_lastTotalEpisodesCount|$showsFormattedTime|$_lastWatchedMoviesCount|$moviesFormattedTime';
    if (_lastPublishedStatsKey != newKey) {
      _lastPublishedStatsKey = newKey;
      WidgetService.updateProfileStatsWidget(
        userName: userName,
        showsCount: _lastWatchedShowsCount,
        episodesCount: _lastTotalEpisodesCount,
        showsFormattedTime: showsFormattedTime,
        moviesCount: _lastWatchedMoviesCount,
        moviesFormattedTime: moviesFormattedTime,
      );
    }
  }

  // Local FAB visibility — driven by NotificationListener inside NestedScrollView body
  final ValueNotifier<bool> _isFabVisible = ValueNotifier<bool>(true);
  Timer? _fabTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _previousTabIndex) {
        setState(() {
          _previousTabIndex = _tabController.index;
          _movieSortOption = 'Last Added';
          _movieProgressOption = 'All';
          _showSortOption = 'Last added';
          _showProgressOption = 'All';
        });
      }
    });
    widget.tabNotifier?.addListener(_onAppTabChanged);
    _heatmapPageController = PageController();

    // Fetch heatmap watch history for current month
    final authState = context.read<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;
    if (user != null) {
      context.read<ProfileHeatmapCubit>().loadMonthActivity(user.uid, _heatmapMonth);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final movieState = context.read<MovieWatchlistCubit>().state;
        final showState = context.read<TvShowWatchlistCubit>().state;
        final currentAuthState = context.read<AuthCubit>().state;
        final currentUser =
            currentAuthState is Authenticated ? currentAuthState.user : null;
        final displayName = currentUser?.displayName.isNotEmpty == true
            ? currentUser!.displayName
            : (currentUser?.email.split('@').first ?? '');
        _checkAndUpdateWidgetStats(displayName, movieState, showState);
      }
    });
  }

  void _onAppTabChanged() {
    if (widget.tabNotifier != null && widget.tabNotifier!.value != 3) {
      // 3 is the index of ProfilePage in ShellNavigationPage
      setState(() {
        _movieSortOption = 'Last Added';
        _movieProgressOption = 'All';
        _showSortOption = 'Last added';
        _showProgressOption = 'All';
        _isHeatmapExpanded = false;
        _isLocalLoading = false;
        _shimmerTimer?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _shimmerTimer?.cancel();
    _fabTimer?.cancel();
    _isFabVisible.dispose();
    widget.tabNotifier?.removeListener(_onAppTabChanged);
    _tabController.dispose();
    _heatmapPageController.dispose();
    super.dispose();
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[200] : AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                },
              ),
              Divider(color: Theme.of(context).dividerColor),
              ListTile(
                leading: Icon(Icons.logout, color: AppColors.error),
                title: Text('Sign Out', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<AuthCubit>().signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;
    final displayName = (user?.displayName.isNotEmpty == true) ? user!.displayName : 'User';
    final photoURL = user?.photoUrl;

    String generateUsername(String name) {
      if (name.isEmpty || name == 'User') return 'user_tellybinge';
      // Strip everything except letters and numbers, then lowercase
      String cleanName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

      // If it ends with exactly one digit (like 'mjwaghmare5'), pad it to '05'
      if (RegExp(r'[a-z]\d$').hasMatch(cleanName)) {
        cleanName = '${cleanName.substring(0, cleanName.length - 1)}0${cleanName.substring(cleanName.length - 1)}';
      }

      return cleanName;
    }

    final username = generateUsername(displayName);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          username,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).textTheme.bodyLarge?.color, size: 28),
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<MovieWatchlistCubit, MovieWatchlistState>(
            listener: (context, movieState) {
              final showState = context.read<TvShowWatchlistCubit>().state;
              _checkAndUpdateWidgetStats(displayName, movieState, showState);
            },
          ),
          BlocListener<TvShowWatchlistCubit, TvShowWatchlistState>(
            listener: (context, showState) {
              final movieState = context.read<MovieWatchlistCubit>().state;
              _checkAndUpdateWidgetStats(displayName, movieState, showState);
            },
          ),
        ],
        child: BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
          builder: (context, watchlistState) {
            return BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
              builder: (context, showWatchlistState) {
                List<HorizontalItem> watchedMovies = [];
              List<HorizontalItem> displayedMovies = [];
              List<HorizontalItem> watchedShows = [];
              List<HorizontalItem> displayedShows = [];
              bool isLoadingMovies = watchlistState is MovieWatchlistLoading;
              bool isLoadingShows = showWatchlistState is TvShowWatchlistLoading;

              if (watchlistState is MovieWatchlistSuccess) {
                watchedMovies = watchlistState.movies
                    .where((m) => m['isWatched'] as bool? ?? false)
                    .map(
                      (m) => HorizontalItem(
                        movieId: (m['id'] as num?)?.toInt() ?? 0,
                        title: m['title'] as String? ?? '',
                        imageUrl: _getImageUrl(m['posterPath'] as String?),
                        voteAverage: (m['voteAverage'] as num?)?.toDouble() ?? 0.0,
                        releaseDate: m['releaseDate'] as String? ?? '',
                        isFavorite: m['isFavorite'] as bool? ?? false,
                        isWatched: m['isWatched'] as bool? ?? false,
                        isMovie: true,
                        addedAt: m['addedAt'] as String?,
                        watchedAt: m['watchedAt'] as String?,
                      ),
                    )
                    .toList();

                var filteredMovies = watchlistState.movies;

                if (_movieProgressOption == 'Watched') {
                  filteredMovies = filteredMovies.where((m) => m['isWatched'] as bool? ?? false).toList();
                } else if (_movieProgressOption == 'Not watched') {
                  filteredMovies = filteredMovies.where((m) => !(m['isWatched'] as bool? ?? false)).toList();
                }

                displayedMovies = filteredMovies
                    .map(
                      (m) => HorizontalItem(
                        movieId: (m['id'] as num?)?.toInt() ?? 0,
                        title: m['title'] as String? ?? '',
                        imageUrl: _getImageUrl(m['posterPath'] as String?),
                        voteAverage: (m['voteAverage'] as num?)?.toDouble() ?? 0.0,
                        releaseDate: m['releaseDate'] as String? ?? '',
                        isFavorite: m['isFavorite'] as bool? ?? false,
                        isWatched: m['isWatched'] as bool? ?? false,
                        isMovie: true,
                        addedAt: m['addedAt'] as String?,
                      ),
                    )
                    .toList();
              }

              if (isLoadingMovies) {
                displayedMovies = List.generate(
                  9,
                  (index) => HorizontalItem(
                    movieId: index,
                    title: 'Loading Movie',
                    imageUrl: '',
                    voteAverage: 9.9,
                    releaseDate: '',
                  ),
                );
              }

              if (showWatchlistState is TvShowWatchlistSuccess) {
                watchedShows = showWatchlistState.shows.map((s) => _showToHorizontalItem(s)).toList();

                var filteredShows = showWatchlistState.shows;

                // 1. Progress Filter
                if (_showProgressOption == 'Stopped') {
                  filteredShows = filteredShows.where((s) => s['status'] == 'STOPPED').toList();
                } else {
                  if (_showProgressOption != 'All') {
                    // Exclude stopped shows from specific categories
                    filteredShows = filteredShows.where((s) => s['status'] != 'STOPPED').toList();
                  }

                  if (_showProgressOption == 'Watching') {
                    filteredShows = filteredShows.where((s) => s['category'] == 'WATCH_NEXT').toList();
                  } else if (_showProgressOption == 'Haven\'t started') {
                    filteredShows = filteredShows.where((s) => s['category'] == 'HAVENT_STARTED').toList();
                  } else if (_showProgressOption == 'Up to date') {
                    filteredShows = filteredShows.where((s) => s['category'] == 'UP_TO_DATE').toList();
                  } else if (_showProgressOption == 'Finished') {
                    filteredShows = filteredShows.where((s) => s['category'] == 'FINISHED').toList();
                  }
                }

                displayedShows = filteredShows
                    .map((s) => _showToHorizontalItem(s, watchedAt: s['watchedAt'] as String?))
                    .toList();
              }

              if (isLoadingShows) {
                displayedShows = List.generate(
                  9,
                  (index) => HorizontalItem(
                    movieId: index,
                    title: 'Loading Show',
                    imageUrl: '',
                    voteAverage: 9.9,
                    releaseDate: '',
                  ),
                );
              }

              if (_movieSortOption == 'Alphabetical') {
                displayedMovies.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
              } else if (_movieSortOption == 'Last Added') {
                displayedMovies.sort((a, b) {
                  final dateA = _parseDate(a.addedAt ?? '');
                  final dateB = _parseDate(b.addedAt ?? '');
                  if (dateA == null && dateB == null) return 0;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA);
                });
              } else if (_movieSortOption == 'Last Watched') {
                displayedMovies.sort((a, b) {
                  final dateA = _parseDate(a.watchedAt ?? a.addedAt ?? '');
                  final dateB = _parseDate(b.watchedAt ?? b.addedAt ?? '');
                  if (dateA == null && dateB == null) return 0;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA);
                });
              }

              if (_showSortOption == 'Alphabetical') {
                displayedShows.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
              } else if (_showSortOption == 'Last added') {
                displayedShows.sort((a, b) {
                  final dateA = _parseDate(a.addedAt ?? '');
                  final dateB = _parseDate(b.addedAt ?? '');
                  if (dateA == null && dateB == null) return 0;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA);
                });
              } else if (_showSortOption == 'Last watched') {
                displayedShows.sort((a, b) {
                  final dateA = _parseDate(a.watchedAt ?? a.addedAt ?? '');
                  final dateB = _parseDate(b.watchedAt ?? b.addedAt ?? '');
                  if (dateA == null && dateB == null) return 0;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA);
                });
              }

              final stats = _calculateProfileStats(watchlistState, showWatchlistState);
              final totalMinutes = stats.totalMovieMinutes;
              final totalShowMinutes = stats.totalShowMinutes;

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Header Info
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8.0),
                            child: Row(
                              children: [
                                // Avatar with ring
                                Container(
                                  padding: const EdgeInsets.all(3), // Border width
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                                  child: Container(
                                    padding: const EdgeInsets.all(2), // Gap between ring and image
                                    decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                    child: CircleAvatar(
                                      radius: 36,
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage: (photoURL != null && photoURL.isNotEmpty)
                                          ? CachedNetworkImageProvider(photoURL)
                                          : null,
                                      child: (photoURL == null || photoURL.isEmpty)
                                          ? Text(
                                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                // Stats
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatColumn(
                                        '${watchedShows.length}',
                                        'Shows added',
                                        _formatTime(totalShowMinutes),
                                        () {
                                          _toggleHeatmap(0);
                                        },
                                      ),
                                      _buildStatColumn(
                                        '${watchedMovies.length}',
                                        'Movies watched',
                                        _formatTime(totalMinutes),
                                        () {
                                          _toggleHeatmap(1);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            alignment: Alignment.topCenter,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            child: _isHeatmapExpanded
                                ? _buildHeatmapSection(context, user?.uid ?? '')
                                : const SizedBox(width: double.infinity, height: 0),
                          ),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'SHOWS'),
                            Tab(text: 'MOVIES'),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis != Axis.vertical) {
                      return false;
                    }
                    if (notification is UserScrollNotification) {
                      if (notification.direction == ScrollDirection.reverse) {
                        if (_isFabVisible.value) _isFabVisible.value = false;
                        _fabTimer?.cancel();
                      } else if (notification.direction == ScrollDirection.forward) {
                        if (!_isFabVisible.value) _isFabVisible.value = true;
                        _fabTimer?.cancel();
                      }
                    } else if (notification is ScrollEndNotification) {
                      _fabTimer?.cancel();
                      _fabTimer = Timer(const Duration(milliseconds: 800), () {
                        if (mounted) _isFabVisible.value = true;
                      });
                    }
                    return false;
                  },
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Skeletonizer(
                          enabled: isLoadingShows || _isFilteringShows,
                          child: _buildGrid(displayedShows, 'No shows matched your filter.'),
                        ),
                        floatingActionButton: Builder(
                          builder: (context) {
                            final isShowFilterActive = _showSortOption != 'Last added' || _showProgressOption != 'All';
                            final fabWidget = Container(
                              margin: const EdgeInsets.only(bottom: 100),
                              height: 40,
                              decoration: isShowFilterActive
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.greenAccent.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await showModalBottomSheet<Map<String, String>>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => ShowsFilterBottomSheet(
                                      initialSort: _showSortOption,
                                      initialProgress: _showProgressOption,
                                    ),
                                  );
                                  if (result != null) {
                                    if (!context.mounted) return;
                                    setState(() {
                                      _showSortOption = result['sort'] ?? 'Last added';
                                      _showProgressOption = result['progress'] ?? 'All';
                                      _isFilteringShows = true;
                                    });
                                    final scrollController = PrimaryScrollController.of(context);
                                    if (scrollController.hasClients) {
                                      scrollController.animateTo(
                                        0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                    await Future.delayed(const Duration(milliseconds: 300));
                                    if (mounted) {
                                      setState(() {
                                        _isFilteringShows = false;
                                      });
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  elevation: isShowFilterActive ? 0 : 4,
                                  side: isShowFilterActive ? BorderSide(color: Colors.greenAccent, width: 1.5) : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                                  shape: const StadiumBorder(),
                                ),
                                icon: Icon(Icons.tune, size: 20),
                                label: Text('FILTERS', style: TextStyle(fontSize: 13, letterSpacing: 0.8)),
                              ),
                            );
                            return ValueListenableBuilder<bool>(
                              valueListenable: _isFabVisible,
                              builder: (context, isVisible, _) {
                                return AnimatedSlide(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                  offset: isVisible ? Offset.zero : const Offset(0, 3.0),
                                  child: fabWidget,
                                );
                              },
                            );
                          },
                        ),
                        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
                      ),
                      Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Skeletonizer(
                          enabled: isLoadingMovies || _isFilteringMovies,
                          child: _buildGrid(displayedMovies, 'No movies matched your filter.'),
                        ),
                        floatingActionButton: Builder(
                          builder: (context) {
                            final isMovieFilterActive =
                                _movieSortOption != 'Last Added' || _movieProgressOption != 'All';
                            final fabWidget = Container(
                              margin: const EdgeInsets.only(bottom: 100),
                              height: 40,
                              decoration: isMovieFilterActive
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.greenAccent.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await showModalBottomSheet<Map<String, String>>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => MoviesFilterBottomSheet(
                                      initialSort: _movieSortOption,
                                      initialProgress: _movieProgressOption,
                                    ),
                                  );
                                  if (result != null) {
                                    if (!context.mounted) return;
                                    setState(() {
                                      _movieSortOption = result['sort'] ?? 'Last Added';
                                      _movieProgressOption = result['progress'] ?? 'All';
                                      _isFilteringMovies = true;
                                    });
                                    final scrollController = PrimaryScrollController.of(context);
                                    if (scrollController.hasClients) {
                                      scrollController.animateTo(
                                        0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                    await Future.delayed(const Duration(milliseconds: 300));
                                    if (mounted) {
                                      setState(() {
                                        _isFilteringMovies = false;
                                      });
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  elevation: isMovieFilterActive ? 0 : 4,
                                  side: isMovieFilterActive ? BorderSide(color: Colors.greenAccent, width: 1.5) : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                                  shape: const StadiumBorder(),
                                ),
                                icon: Icon(Icons.tune, size: 20),
                                label: Text('FILTERS', style: TextStyle(fontSize: 13, letterSpacing: 0.8)),
                              ),
                            );
                            return ValueListenableBuilder<bool>(
                              valueListenable: _isFabVisible,
                              builder: (context, isVisible, _) {
                                return AnimatedSlide(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                  offset: isVisible ? Offset.zero : const Offset(0, 3.0),
                                  child: fabWidget,
                                );
                              },
                            );
                          },
                        ),
                        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

  Widget _buildStatColumn(String count, String label, String timeSpent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Visibility(
            visible: timeSpent.isNotEmpty && timeSpent != '0m',
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text(
              timeSpent,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<HorizontalItem> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.bottomTabPadding),
          child: Text(emptyMessage, style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 14)),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(2.0, 2.0, 2.0, 160.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
        childAspectRatio: 2 / 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return CupertinoContextMenu(
          actions: <Widget>[
            CupertinoContextMenuAction(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                final authState = context.read<AuthCubit>().state;
                final uid = authState is Authenticated ? authState.user.uid : null;
                if (uid != null) {
                  if (item.isMovie) {
                    context.read<MovieWatchlistCubit>().toggleFavorite(
                      uid: uid,
                      movieId: item.movieId,
                      isFavorite: !item.isFavorite,
                    );
                  } else {
                    context.read<TvShowWatchlistCubit>().toggleFavorite(
                      uid: uid,
                      showId: item.movieId,
                      isFavorite: !item.isFavorite,
                    );
                  }
                }
              },
              child: Text(item.isFavorite ? 'Remove from Favorites' : 'Mark as Favorite'),
            ),
            CupertinoContextMenuAction(
              isDestructiveAction: true,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                final authState = context.read<AuthCubit>().state;
                final uid = authState is Authenticated ? authState.user.uid : null;
                if (uid != null) {
                  if (item.isMovie) {
                    context.read<MovieWatchlistCubit>().removeMovie(uid: uid, movieId: item.movieId);
                  } else {
                    context.read<TvShowWatchlistCubit>().removeShow(uid: uid, showId: item.movieId);
                  }
                }
              },
              child: const Text('Remove'),
            ),
          ],
          child: GestureDetector(
            onTap: () {
              if (item.movieId <= 0) return;
              if (item.isMovie) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MovieDetailsPage(movieId: item.movieId)),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider<ShowDetailsCubit>(
                      create: (context) => ShowDetailsCubit(tmdbClient: context.read<TmdbClient>()),
                      child: ShowDetailsPage(mediaId: item.movieId, mediaType: 'tv', title: item.title),
                    ),
                  ),
                );
              }
            },
            child: SizedBox(
              width: 150,
              height: 225,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: AppColors.surface),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[200]
                                : AppColors.surface,
                            child: Center(
                              child: Icon(
                                Icons.movie_outlined,
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey[500]
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[200]
                              : AppColors.surface,
                          child: Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey[500]
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                  if (item.isFavorite)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(Icons.favorite, color: Colors.red, size: 16),
                      ),
                    ),
                  // ADD: Watched Eye Icon for Movies and TV Shows with unknown totalEpisodes
                  if (item.isWatched && (item.isMovie || item.totalEpisodes == 0))
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.remove_red_eye, color: Colors.green, size: 16),
                      ),
                    ),
                  // ADD: Progress Indicator for TV Shows
                  if (!item.isMovie && item.totalEpisodes > 0) ...[
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: (item.watchedCount / item.totalEpisodes).clamp(0.0, 1.0),
                        minHeight: 6.0,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.watchedCount.clamp(0, item.totalEpisodes)}/${item.totalEpisodes}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  // ADD: STOPPED badge — top-right pill matching explore tab badge style
                  if (item.isStopped)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'STOPPED',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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

  String _getImageUrl(String? path, {String size = 'w342'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  HorizontalItem _showToHorizontalItem(Map<String, dynamic> s, {String? watchedAt}) {
    return HorizontalItem(
      movieId: (s['id'] as num?)?.toInt() ?? 0,
      title: s['name'] as String? ?? '',
      imageUrl: _getImageUrl(s['posterPath'] as String?),
      voteAverage: (s['voteAverage'] as num?)?.toDouble() ?? 0.0,
      releaseDate: s['firstAirDate'] as String? ?? '',
      isFavorite: s['isFavorite'] as bool? ?? false,
      isWatched: (s['watchedEpisodes'] as List?)?.isNotEmpty ?? false,
      isMovie: false,
      isStopped: (s['status'] as String?) == 'STOPPED',
      addedAt: s['addedAt'] as String?,
      watchedAt: watchedAt,
      watchedCount: (s['watchedEpisodes'] as List?)?.length ?? 0,
      totalEpisodes: (s['totalEpisodes'] as num?)?.toInt() ?? 0,
    );
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty || dateStr.toUpperCase() == 'TBA') return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  Widget _buildHeatmapSection(BuildContext context, String uid) {
    return BlocBuilder<ProfileHeatmapCubit, ProfileHeatmapState>(
      builder: (context, state) {
        DateTime currentMonth = _heatmapMonth;
        Map<DateTime, int> tvCounts = const {};
        Map<DateTime, int> movieCounts = const {};
        bool isLoading = state is ProfileHeatmapLoading;

        if (state is ProfileHeatmapLoaded) {
          currentMonth = state.selectedMonth;
          tvCounts = state.tvCounts;
          movieCounts = state.movieCounts;
        }

        final int daysInMonth = DateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);
        final DateTime firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
        final int offset = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
        final int totalSlots = offset + daysInMonth;

        final List<Color> activeLegendColors = _heatmapPageIndex == 0
            ? [
                Theme.of(context).brightness == Brightness.light ? Color(0xFFEBEDF0) : Color(0xFF161B22),
                Color(0xFF0E4429),
                Color(0xFF006D32),
                Color(0xFF26A641),
                Color(0xFF39D353),
              ]
            : [
                Theme.of(context).brightness == Brightness.light ? Color(0xFFEBEDF0) : Color(0xFF161B22),
                Color(0xFF3E2D00),
                Color(0xFF7C5A00),
                Color(0xFFB98700),
                Color(0xFFFFC107),
              ];

        final showShimmer = isLoading || _isLocalLoading;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WATCH ACTIVITY',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isSignUpMonthOrPast(currentMonth)
                          ? const SizedBox(width: 24)
                          : IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.chevron_left,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                size: 24,
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      final prevMonth = currentMonth.month == 1
                                          ? DateTime(currentMonth.year - 1, 12, 1)
                                          : DateTime(currentMonth.year, currentMonth.month - 1, 1);
                                      setState(() {
                                        _heatmapMonth = prevMonth;
                                      });
                                      context.read<ProfileHeatmapCubit>().loadMonthActivity(uid, prevMonth);
                                    },
                            ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM yyyy').format(currentMonth),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isCurrentMonthOrFuture(currentMonth)
                          ? const SizedBox(width: 24)
                          : IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                size: 24,
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      final nextMonth = currentMonth.month == 12
                                          ? DateTime(currentMonth.year + 1, 1, 1)
                                          : DateTime(currentMonth.year, currentMonth.month + 1, 1);
                                      setState(() {
                                        _heatmapMonth = nextMonth;
                                      });
                                      context.read<ProfileHeatmapCubit>().loadMonthActivity(uid, nextMonth);
                                    },
                            ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 245,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 220,
                      child: PageView(
                        controller: _heatmapPageController,
                        onPageChanged: (index) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _heatmapPageIndex = index;
                            _isLocalLoading = true;
                          });
                          _shimmerTimer?.cancel();
                          _shimmerTimer = Timer(const Duration(milliseconds: 500), () {
                            if (mounted) {
                              setState(() {
                                _isLocalLoading = false;
                              });
                            }
                          });
                        },
                        children: [
                          _buildHeatmapPage(
                            offset: offset,
                            totalSlots: totalSlots,
                            counts: tvCounts,
                            currentMonth: currentMonth,
                            isMovies: false,
                            showShimmer: showShimmer,
                          ),
                          _buildHeatmapPage(
                            offset: offset,
                            totalSlots: totalSlots,
                            counts: movieCounts,
                            currentMonth: currentMonth,
                            isMovies: true,
                            showShimmer: showShimmer,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(2, (index) {
                            final isActive = index == _heatmapPageIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              width: isActive ? 8.0 : 6.0,
                              height: isActive ? 8.0 : 6.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)
                                    : (Theme.of(context).brightness == Brightness.light
                                          ? Colors.black38
                                          : Colors.white30),
                              ),
                            );
                          }),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Less',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.black54
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildLegendSquare(activeLegendColors[0]),
                            const SizedBox(width: 3),
                            _buildLegendSquare(activeLegendColors[1]),
                            const SizedBox(width: 3),
                            _buildLegendSquare(activeLegendColors[2]),
                            const SizedBox(width: 3),
                            _buildLegendSquare(activeLegendColors[3]),
                            const SizedBox(width: 3),
                            _buildLegendSquare(activeLegendColors[4]),
                            const SizedBox(width: 4),
                            Text(
                              'More',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.black54
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeatmapPage({
    required int offset,
    required int totalSlots,
    required Map<DateTime, int> counts,
    required DateTime currentMonth,
    required bool isMovies,
    required bool showShimmer,
  }) {
    final List<Color> colorScale = isMovies
        ? [
            Theme.of(context).brightness == Brightness.light ? Color(0xFFEBEDF0) : Color(0xFF161B22),
            Color(0xFF3E2D00),
            Color(0xFF7C5A00),
            Color(0xFFB98700),
            Color(0xFFFFC107),
          ]
        : [
            Theme.of(context).brightness == Brightness.light ? Color(0xFFEBEDF0) : Color(0xFF161B22),
            Color(0xFF0E4429),
            Color(0xFF006D32),
            Color(0xFF26A641),
            Color(0xFF39D353),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            isMovies ? 'MOVIES WATCHED' : 'EPISODES WATCHED',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white30,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              showShimmer
                  ? _RippleShimmerGrid(totalSlots: totalSlots)
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 1.7,
                      ),
                      itemCount: totalSlots,
                      itemBuilder: (context, index) {
                        if (index < offset || index >= totalSlots) {
                          return Container(decoration: BoxDecoration(color: Colors.transparent));
                        }

                        final int day = index - offset + 1;
                        final DateTime date = DateTime(currentMonth.year, currentMonth.month, day);
                        final int count = counts[date] ?? 0;

                        Color cellColor;
                        if (count == 0) {
                          cellColor = colorScale[0];
                        } else if (count == 1) {
                          cellColor = colorScale[1];
                        } else if (count == 2) {
                          cellColor = colorScale[2];
                        } else if (count == 3) {
                          cellColor = colorScale[3];
                        } else {
                          cellColor = colorScale[4];
                        }

                        final itemText = isMovies ? 'movie' : 'episode';
                        final itemsText = isMovies ? 'movies' : 'episodes';

                        return Tooltip(
                          message:
                              '$count ${count == 1 ? itemText : itemsText} watched on ${DateFormat('MMM d, yyyy').format(date)}',
                          triggerMode: TooltipTriggerMode.tap,
                          child: Listener(
                            onPointerDown: (_) {
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              decoration: BoxDecoration(color: cellColor, borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.only(bottom: 2.0, right: 4.0),
                              alignment: Alignment.bottomRight,
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendSquare(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5)),
    );
  }

  bool _isCurrentMonthOrFuture(DateTime month) {
    final now = DateTime.now();
    final limit = DateTime(now.year, now.month, 1);
    return month.isAtSameMomentAs(limit) || month.isAfter(limit);
  }

  bool _isSignUpMonthOrPast(DateTime month) {
    final user = FirebaseAuth.instance.currentUser;
    final creationTime = user?.metadata.creationTime;
    if (creationTime == null) return true;

    final limit = DateTime(creationTime.year, creationTime.month, 1);
    return month.isAtSameMomentAs(limit) || month.isBefore(limit);
  }

  void _toggleHeatmap(int targetPage) {
    final wasExpanded = _isHeatmapExpanded;
    final isSamePage = _heatmapPageIndex == targetPage;

    setState(() {
      if (wasExpanded && isSamePage) {
        _isHeatmapExpanded = false;
        _isLocalLoading = false;
        _shimmerTimer?.cancel();
      } else {
        _isHeatmapExpanded = true;
        _isLocalLoading = true; // Trigger local shimmer
        if (!wasExpanded) {
          _heatmapPageController = PageController(initialPage: targetPage);
        }
        _heatmapPageIndex = targetPage;
      }
    });

    if (_isHeatmapExpanded) {
      _shimmerTimer?.cancel();
      _shimmerTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            _isLocalLoading = false;
          });
        }
      });
    }

    if (wasExpanded && !isSamePage) {
      _heatmapPageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    HapticFeedback.mediumImpact();
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Background color for TabBar
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}

class _RippleShimmerGrid extends StatefulWidget {
  final int totalSlots;
  const _RippleShimmerGrid({required this.totalSlots});

  @override
  State<_RippleShimmerGrid> createState() => _RippleShimmerGridState();
}

class _RippleShimmerGridState extends State<_RippleShimmerGrid> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.7,
      ),
      itemCount: widget.totalSlots,
      itemBuilder: (context, index) {
        final row = index ~/ 7;
        final col = index % 7;
        final distance = (row + col) / 12.0;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            final phase = (progress - distance) * 2 * pi;
            final wave = (cos(phase) + 1.0) / 2.0;

            final opacity = 0.08 + (0.22 * wave);
            final scale = 1.0 + (0.12 * wave);
            final translateY = -2.5 * wave;

            final transform = Matrix4.translationValues(0.0, translateY, 0.0)
              ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity.clamp(0.08, 0.35)),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: wave > 0.15
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35 * wave),
                            blurRadius: 4.5 * wave,
                            offset: Offset(0, 2.0 * wave),
                          ),
                        ]
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
