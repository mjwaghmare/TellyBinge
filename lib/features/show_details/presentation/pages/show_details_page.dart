import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/show_details_cubit.dart';
import '../cubit/show_details_state.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../../core/widgets/watch_trailer_button.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../../core/widgets/action_circle_button.dart';

class ShowDetailsPage extends StatefulWidget {
  final int mediaId;
  final String mediaType;
  final String title;
  final int initialTabIndex;

  const ShowDetailsPage({
    super.key,
    required this.mediaId,
    required this.mediaType,
    required this.title,
    this.initialTabIndex = 0,
  });

  @override
  State<ShowDetailsPage> createState() => _ShowDetailsPageState();
}

class _ShowDetailsPageState extends State<ShowDetailsPage> {
  late final ScrollController _scrollController;
  final ValueNotifier<bool> _isCollapsed = ValueNotifier<bool>(false);
  final Map<int, bool> _expandedSeasons = {};
  final Map<int, ExpansibleController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.hasClients) {
          final isCurrentlyCollapsed = _scrollController.offset > 240;
          if (isCurrentlyCollapsed != _isCollapsed.value) {
            _isCollapsed.value = isCurrentlyCollapsed;
          }
        }
      });
    context.read<ShowDetailsCubit>().loadDetails(
      widget.mediaId,
      widget.mediaType,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isCollapsed.dispose();
    super.dispose();
  }

  String _getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  String _getYear(String? dateStr) {
    if (dateStr == null || dateStr.length < 4) return '';
    return dateStr.substring(0, 4);
  }

  String _getGenresString(List<dynamic>? genres) {
    if (genres == null || genres.isEmpty) return '';
    return genres.map((g) => g['name'] as String? ?? '').join(', ');
  }

  Widget _buildStarRating(double ratingOutOf10) {
    final double ratingOutOf5 = ratingOutOf10 / 2;
    int fullStars = ratingOutOf5.floor();
    bool hasHalfStar = (ratingOutOf5 - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(Icons.star, color: Colors.yellow, size: 16);
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(Icons.star_half, color: Colors.yellow, size: 16);
        } else {
          return Icon(Icons.star_border, color: Colors.grey.shade700, size: 16);
        }
      }),
    );
  }

  void _showMoreActions({
    required BuildContext context,
    required String uid,
    required bool isStopped,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Show Actions'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              if (isStopped) {
                context.read<TvShowWatchlistCubit>().continueWatchingShow(
                  uid: uid,
                  showId: widget.mediaId,
                );
              } else {
                context.read<TvShowWatchlistCubit>().stopWatchingShow(
                  uid: uid,
                  showId: widget.mediaId,
                );
              }
            },
            child: Text(isStopped ? 'Continue watching' : 'Stop watching'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              context.read<TvShowWatchlistCubit>().removeShow(
                uid: uid,
                showId: widget.mediaId,
              );
            },
            child: const Text('Remove from watchlist'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Map<String, dynamic> _dummyShowDetails() {
    return {
      'name': widget.title.isNotEmpty ? widget.title : 'Loading TV Show Title',
      'backdrop_path': null,
      'poster_path': null,
      'overview':
          'This is a placeholder overview for the show details page while the data is loading from the network.',
      'vote_average': 8.5,
      'number_of_seasons': 3,
      'status': 'Returning Series',
      'networks': [
        {'name': 'Network'}
      ],
      'genres': [
        {'name': 'Drama'},
        {'name': 'Action'}
      ],
      'seasons': [
        {'season_number': 1, 'name': 'Season 1', 'episode_count': 10}
      ],
      'credits': {
        'cast': List.generate(
          5,
          (index) => {
            'id': index + 100,
            'name': 'Actor Name',
            'character': 'Character Name',
            'profile_path': null,
          },
        ),
      },
      'similar': {
        'results': List.generate(
          4,
          (index) => {
            'id': index + 1000,
            'name': 'Similar Show',
            'poster_path': null,
            'vote_average': 8.0,
          },
        ),
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShowDetailsCubit, ShowDetailsState>(
      builder: (context, state) {
        final bool isLoading =
            state is ShowDetailsInitial || state is ShowDetailsLoading;
        final String? error =
            state is ShowDetailsError ? state.message : null;

        if (error != null && state is! ShowDetailsSuccess) {
          String userFriendlyError =
              'An unexpected error occurred. Please try again.';
          if (error.contains('404')) {
            userFriendlyError =
                'This TV show could not be found or may have been removed.';
          } else if (error.contains('SocketException') ||
              error.contains('DioException')) {
            userFriendlyError =
                'Please check your internet connection and try again.';
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text(widget.title),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/error_devices.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userFriendlyError,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context
                          .read<ShowDetailsCubit>()
                          .loadDetails(widget.mediaId, widget.mediaType),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'RETRY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final details = isLoading
            ? _dummyShowDetails()
            : (state as ShowDetailsSuccess).details;
        final mediaType = isLoading
            ? widget.mediaType
            : (state as ShowDetailsSuccess).mediaType;
        final seasonsData = isLoading
            ? <int, List<dynamic>>{}
            : (state as ShowDetailsSuccess).seasonsData;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              Skeletonizer(
                enabled: isLoading,
                child: _buildDetailsView(details, mediaType, seasonsData),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                left: 16,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsView(
    Map<String, dynamic> details,
    String mediaType,
    Map<int, List<dynamic>> seasonsData,
  ) {
    final String title = details['name'] ?? details['title'] ?? widget.title;
    final String? backdropPath = details['backdrop_path'];
    final String overview = details['overview'] ?? '';
    final double voteAverage =
        (details['vote_average'] as num?)?.toDouble() ?? 0.0;

    // TV show specific metadata
    final int numberOfSeasons = details['number_of_seasons'] ?? 0;
    final String status = details['status'] ?? '';
    final List<dynamic> networks = details['networks'] ?? [];
    final String networkName = networks.isNotEmpty
        ? networks[0]['name'] ?? ''
        : '';

    // Trailer specific
    final videos = details['videos']?['results'] as List<dynamic>? ?? [];
    final youtubeTrailers = videos
        .where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
        .toList();
    final otherTrailers = videos
        .where((v) => v['type'] == 'Trailer' && v['site'] != 'YouTube')
        .toList();
    final Map<String, dynamic>? trailer = youtubeTrailers.isNotEmpty
        ? youtubeTrailers.first
        : (otherTrailers.isNotEmpty ? otherTrailers.first : null);

    Widget buildSliverAppBar() {
      return SliverAppBar(
        automaticallyImplyLeading: false,
        leading: const SizedBox.shrink(),
        expandedHeight: 300.0,
        pinned: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: ValueListenableBuilder<bool>(
          valueListenable: _isCollapsed,
          builder: (context, isCollapsed, child) {
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
        centerTitle: true,
        actions: [
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final uid = authState is Authenticated
                  ? authState.user.uid
                  : null;
              return BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
                builder: (context, watchState) {
                  bool isTracked = false;
                  bool isStopped = false;
                  if (watchState is TvShowWatchlistSuccess) {
                    for (var s in watchState.shows) {
                      if (s['id'] == widget.mediaId) {
                        isTracked = true;
                        isStopped = s['status'] == 'STOPPED';
                        break;
                      }
                    }
                  }
                  if (isTracked && uid != null) {
                    return IconButton(
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 28,
                        color: Colors.white,
                      ),
                      onPressed: () => _showMoreActions(
                        context: context,
                        uid: uid,
                        isStopped: isStopped,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(
            fit: StackFit.expand,
            children: [
              backdropPath != null && backdropPath.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _getImageUrl(backdropPath, size: 'w780'),
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Container(color: AppColors.surface),
                    )
                  : Container(color: AppColors.surface),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 28.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            mediaType == 'tv'
                                ? '$numberOfSeasons season${numberOfSeasons == 1 ? '' : 's'} • $status • $networkName'
                                : _getYear(details['release_date']),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
                      builder: (context, watchState) {
                        bool isFavorite = false;
                        bool isAdded = false;
                        if (watchState is TvShowWatchlistSuccess) {
                          for (var s in watchState.shows) {
                            if (s['id'] == widget.mediaId) {
                              isAdded = true;
                              isFavorite = s['isFavorite'] as bool? ?? false;
                              break;
                            }
                          }
                        }
                        final authState = context.read<AuthCubit>().state;
                        final uid = authState is Authenticated ? authState.user.uid : null;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (uid != null) ...[
                              ActionCircleButton(
                                isActive: isFavorite,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  if (isAdded) {
                                    context.read<TvShowWatchlistCubit>().toggleFavorite(
                                          uid: uid,
                                          showId: widget.mediaId,
                                          isFavorite: !isFavorite,
                                        );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Add show to watchlist first'),
                                      ),
                                    );
                                  }
                                },
                                activeIcon: Icons.favorite,
                                inactiveIcon: Icons.favorite_border,
                                activeIconColor: Colors.red,
                                inactiveIconColor: Colors.white,
                                activeBgColor: Colors.grey.withValues(alpha: 0.3),
                                inactiveBgColor: Colors.grey.withValues(alpha: 0.3),
                                size: 28.0,
                                iconSize: 16.0,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.yellow,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    height: 16,
                                    width: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(voteAverage * 10).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildAboutSection() {
      final String language = (details['original_language'] as String? ?? '')
          .toUpperCase();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: _buildTrackButton(details))]),
            const Text(
              'Show info',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            AppSpacing.gapH4,
            Text(
              '${_getYear(details['first_air_date'] ?? details['release_date'])} • ${_getGenresString(details['genres'])}',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 13.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (language.isNotEmpty) ...[
              AppSpacing.gapH4,
              Row(
                children: [
                  Icon(
                    Icons.language,
                    color: Theme.of(context).disabledColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Language: $language',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 13.0,
                    ),
                  ),
                ],
              ),
            ],
            AppSpacing.gapH12,
            Row(
              children: [
                _buildStarRating(voteAverage),
                const SizedBox(width: 8),
                Text(
                  '${(voteAverage / 2).toStringAsFixed(1)}/5',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.0,
                  ),
                ),
              ],
            ),
            AppSpacing.gapH12,
            Text(
              overview.isNotEmpty ? overview : 'No overview available.',
              style: const TextStyle(fontSize: 14.0, height: 1.4),
            ),
            AppSpacing.gapH24,
            if (trailer != null) ...[
              WatchTrailerButton(trailer: trailer),
              AppSpacing.gapH24,
            ],

            if (details['credits'] != null &&
                details['credits']['cast'] != null &&
                (details['credits']['cast'] as List).isNotEmpty) ...[
              const Divider(height: 1, thickness: 0.5),
              AppSpacing.gapH24,
              const Text(
                'Cast',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              AppSpacing.gapH16,
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: (details['credits']['cast'] as List)
                      .take(10)
                      .length,
                  separatorBuilder: (context, index) => AppSpacing.gapW12,
                  itemBuilder: (context, index) {
                    final cast = (details['credits']['cast'] as List)
                        .take(10)
                        .toList();
                    final actor = cast[index] as Map<String, dynamic>;
                    final actorName = actor['name'] as String? ?? 'Unknown';
                    final character = actor['character'] as String? ?? '';
                    final profilePath = actor['profile_path'] as String?;
                    return _buildCastCard(
                      personId: (actor['id'] as num?)?.toInt() ?? 0,
                      imageUrl: _getImageUrl(profilePath, size: 'w185'),
                      realName: actorName,
                      characterName: character.toUpperCase(),
                    );
                  },
                ),
              ),
              AppSpacing.gapH24,
            ],

            AppSpacing.gapH48,
          ],
        ),
      );
    }

    Widget buildEpisodesSection() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildSeasonsAccordion(
              details['seasons'] as List<dynamic>? ?? [],
              seasonsData,
              details,
            ),
            AppSpacing.gapH48,
          ],
        ),
      );
    }

    if (mediaType == 'movie') {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          buildSliverAppBar(),
          SliverToBoxAdapter(child: buildAboutSection()),
        ],
      );
    } else {
      return DefaultTabController(
        length: 2,
        initialIndex: widget.initialTabIndex,
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              buildSliverAppBar(),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    tabs: [
                      Tab(text: 'ABOUT'),
                      Tab(text: 'EPISODES'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              CustomScrollView(
                key: const PageStorageKey('about_tab'),
                slivers: [SliverToBoxAdapter(child: buildAboutSection())],
              ),
              CustomScrollView(
                key: const PageStorageKey('episodes_tab'),
                slivers: [SliverToBoxAdapter(child: buildEpisodesSection())],
              ),
            ],
          ),
        ),
      );
    }
  }

  List<String> _getUnwatchedPreviousEpisodes(
    Map<String, dynamic> details,
    int targetSeason,
    int targetEp,
    List<String> currentlyWatched,
  ) {
    List<String> unwatched = [];
    final seasons = details['seasons'] as List<dynamic>? ?? [];

    for (var season in seasons) {
      final sNum = (season['season_number'] as num?)?.toInt() ?? 1;
      if (sNum == 0) continue; // Skip specials
      if (sNum > targetSeason) continue;

      final epCount = season['episode_count'] as int? ?? 0;
      final maxEp = (sNum == targetSeason) ? targetEp - 1 : epCount;

      for (int eNum = 1; eNum <= maxEp; eNum++) {
        final key = '$sNum-$eNum';
        if (!currentlyWatched.contains(key)) {
          unwatched.add(key);
        }
      }
    }
    return unwatched;
  }

  Widget _buildTrackButton(Map<String, dynamic> details) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please log in to track shows and movies'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              child: const Text('Login to Track'),
            ),
          );
        }

        final uid = authState.user.uid;

        if (widget.mediaType == 'movie') {
          return BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
            builder: (context, watchState) {
              bool isTracked = false;
              if (watchState is MovieWatchlistSuccess) {
                isTracked = watchState.movies.any(
                  (m) => m['id'] == widget.mediaId,
                );
              }

              return _trackButtonUI(
                isTracked: isTracked,
                onPressed: () {
                  if (isTracked) {
                    context.read<MovieWatchlistCubit>().removeMovie(
                      uid: uid,
                      movieId: widget.mediaId,
                    );
                  } else {
                    final genresList = details['genres'] as List<dynamic>?;
                    final genresStr =
                        (genresList != null && genresList.isNotEmpty)
                        ? genresList
                              .map((g) => g['name'] as String? ?? '')
                              .join(', ')
                        : '';
                    context.read<MovieWatchlistCubit>().addMovie(
                      uid: uid,
                      movieId: widget.mediaId,
                      title: details['title'] ?? widget.title,
                      posterPath: details['poster_path'],
                      backdropPath: details['backdrop_path'],
                      releaseDate: details['release_date'],
                      runtime: details['runtime'] ?? 0,
                      voteAverage: (details['vote_average'] ?? 0).toDouble(),
                      genres: genresStr,
                    );
                  }
                },
              );
            },
          );
        } else {
          return BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
            builder: (context, watchState) {
              bool isTracked = false;
              if (watchState is TvShowWatchlistSuccess) {
                isTracked = watchState.shows.any(
                  (s) => s['id'] == widget.mediaId,
                );
              }

              return _trackButtonUI(
                isTracked: isTracked,
                onPressed: () {
                  if (isTracked) {
                    context.read<TvShowWatchlistCubit>().removeShow(
                      uid: uid,
                      showId: widget.mediaId,
                    );
                  } else {
                    context.read<TvShowWatchlistCubit>().addShow(
                      uid: uid,
                      showId: widget.mediaId,
                      name: details['name'] ?? widget.title,
                      posterPath: details['poster_path'],
                      backdropPath: details['backdrop_path'],
                      firstAirDate: details['first_air_date'],
                      voteAverage: (details['vote_average'] ?? 0).toDouble(),
                    );
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (context.mounted) {
                        DefaultTabController.maybeOf(context)?.animateTo(1);
                      }
                    });
                  }
                },
              );
            },
          );
        }
      },
    );
  }

  Widget _trackButtonUI({
    required bool isTracked,
    required VoidCallback onPressed,
  }) {
    if (isTracked) return const SizedBox(height: 24.0);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        child: const Text('Add to Watchlist'),
      ),
    );
  }

  Widget _buildSeasonsAccordion(
    List<dynamic> seasons,
    Map<int, List<dynamic>> seasonsData,
    Map<String, dynamic> showDetails,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(seasons.length, (index) {
        final season = seasons[index];
        final int seasonNumber = season['season_number'] as int? ?? 1;
        final String name = 'Season $seasonNumber';
        final int epCount = season['episode_count'] as int? ?? 0;

        // Skip specials season entirely (season_number 0 is always Specials in TMDB)
        if (seasonNumber == 0) return const SizedBox.shrink();

        return BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            return BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
              builder: (context, watchState) {
                int watchedCount = 0;
                bool isTracked = false;
                List<String> watchedEpisodes = [];

                if (watchState is TvShowWatchlistSuccess) {
                  try {
                    final showDoc = watchState.shows.firstWhere(
                      (s) => s['id'] == widget.mediaId,
                    );
                    isTracked = true;
                    if (showDoc['watchedEpisodes'] != null) {
                      watchedEpisodes = List<String>.from(
                        showDoc['watchedEpisodes'],
                      );
                    }
                  } catch (_) {}
                }

                for (int i = 1; i <= epCount; i++) {
                  if (watchedEpisodes.contains('$seasonNumber-$i')) {
                    watchedCount++;
                  }
                }

                List<String> releasedEpisodesKeys = [];
                if (epCount > 0) {
                  final totalSeasons =
                      showDetails['number_of_seasons'] as int? ?? 0;
                  if (seasonNumber < totalSeasons) {
                    for (int i = 1; i <= epCount; i++) {
                      releasedEpisodesKeys.add('$seasonNumber-$i');
                    }
                  } else {
                    final episodesForSeason = seasonsData[seasonNumber];
                    if (episodesForSeason != null &&
                        episodesForSeason.isNotEmpty) {
                      for (var ep in episodesForSeason) {
                        final epNum = ep['episode_number'] as int? ?? 0;
                        if (epNum > 0) {
                          final airDateStr = ep['air_date'] as String?;
                          if (airDateStr != null && airDateStr.isNotEmpty) {
                            final airDate = DateTime.tryParse(airDateStr);
                            if (airDate != null &&
                                airDate.isBefore(DateTime.now())) {
                              releasedEpisodesKeys.add('$seasonNumber-$epNum');
                            }
                          }
                        }
                      }
                    }
                  }
                }

                int watchedReleasedCount = 0;
                for (String key in releasedEpisodesKeys) {
                  if (watchedEpisodes.contains(key)) {
                    watchedReleasedCount++;
                  }
                }

                final bool hasAnyReleased = releasedEpisodesKeys.isNotEmpty;
                final bool allReleasedWatched =
                    hasAnyReleased &&
                    (watchedReleasedCount == releasedEpisodesKeys.length);
                final bool allWatched = epCount > 0 && watchedCount >= epCount;

                final controller = _controllers.putIfAbsent(
                  seasonNumber,
                  () => ExpansibleController(),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: (_expandedSeasons[seasonNumber] ?? false)
                        ? Colors.transparent
                        : const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      ExpansionTile(
                        controller: controller,
                        key: PageStorageKey<String>(
                          'season_${widget.mediaId}_$seasonNumber',
                        ),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        iconColor: Colors
                            .transparent, // Hide default rotating icon completely
                        collapsedIconColor: Colors
                            .transparent, // Hide default rotating icon completely
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              (_expandedSeasons[seasonNumber] ?? false)
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$watchedCount/$epCount',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            if (hasAnyReleased) ...[
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (authState is! Authenticated) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please log in to track episodes',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!isTracked) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Add show to watchlist first',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final uid = authState.user.uid;
                                  final cubit = context
                                      .read<TvShowWatchlistCubit>();

                                  if (allReleasedWatched) {
                                    cubit.unmarkMultipleEpisodesWatched(
                                      uid: uid,
                                      showId: widget.mediaId,
                                      episodeKeys: releasedEpisodesKeys,
                                    );
                                  } else {
                                    cubit.markMultipleEpisodesWatched(
                                      uid: uid,
                                      showId: widget.mediaId,
                                      episodeKeys: releasedEpisodesKeys,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: allReleasedWatched
                                        ? Colors.green
                                        : const Color(0xFFF0F0F0),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 20,
                                    color: allReleasedWatched
                                        ? Colors.white
                                        : Colors.grey[400],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _expandedSeasons[seasonNumber] = expanded;
                          });
                          if (expanded) {
                            // Collapse all other expanded tiles
                            for (var entry in _controllers.entries) {
                              if (entry.key != seasonNumber &&
                                  entry.value.isExpanded) {
                                entry.value.collapse();
                                setState(() {
                                  _expandedSeasons[entry.key] = false;
                                });
                              }
                            }

                            context.read<ShowDetailsCubit>().loadSeasonEpisodes(
                              widget.mediaId,
                              seasonNumber,
                            );
                          }
                        },
                        children: [
                          _buildEpisodesList(
                            seasonNumber,
                            seasonsData[seasonNumber],
                          ),
                        ],
                      ),

                      // Progress bar pinned to absolute bottom
                      if (epCount > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Stack(
                            children: [
                              Container(
                                height: 4,
                                width: double.infinity,
                                color: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ), // Light yellow track
                              ),
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: watchedCount / epCount,
                                ),
                                builder: (context, value, child) {
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: value,
                                    child: Container(
                                      height: 4,
                                      color: allWatched
                                          ? Colors.green
                                          : AppColors.primary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }),
    );
  }

  void _showEpisodeDetailsBottomSheet(
    Map<String, dynamic> ep,
    int seasonNumber,
    String name,
    int epNum,
    String airDate,
    String? stillPath,
    String overview,
    double voteAverage,
    int voteCount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stillPath != null && stillPath.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: _getImageUrl(stillPath, size: 'w780'),
                    fit: BoxFit.cover,
                    height: 220,
                    width: double.infinity,
                    errorWidget: (context, url, error) => const SizedBox(
                      height: 220,
                      child: Icon(
                        Icons.tv,
                        size: 50,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(
                  height: 100,
                  child: Icon(
                    Icons.tv,
                    size: 50,
                    color: AppColors.textTertiary,
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                              ),
                              if (voteCount > 0) ...[
                                AppSpacing.gapH4,
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${voteAverage.toStringAsFixed(1)}/10 ($voteCount)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textTertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        AppSpacing.gapW12,
                        Text(
                          airDate,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH16,
                    if (overview.isNotEmpty)
                      Text(
                        overview,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      )
                    else
                      const Text(
                        'No description available.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
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

  Widget _buildEpisodesList(int seasonNumber, List<dynamic>? episodes) {
    if (episodes == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    if (episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text(
          'No episodes listed for this season.',
          style: TextStyle(color: AppColors.textTertiary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(episodes.length, (index) {
        final ep = episodes[index];
        final int epNum = ep['episode_number'] as int? ?? (index + 1);
        final String name = ep['name'] ?? 'Episode $epNum';
        String airDate = ep['air_date'] ?? 'No Air Date';
        bool isReleased = false;
        int? daysUntilRelease;

        if (airDate != 'No Air Date' && airDate.isNotEmpty) {
          try {
            final date = DateTime.parse(airDate);
            isReleased = date.isBefore(
              DateTime.now().add(const Duration(days: 1)),
            );
            if (!isReleased) {
              daysUntilRelease = date.difference(DateTime.now()).inDays;
            }
            airDate = DateFormat('dd-MMM-yyyy').format(date);
          } catch (e) {
            // fallback to original string
          }
        }
        final String? stillPath = ep['still_path'];
        final String overview = ep['overview'] ?? '';
        final double voteAverage =
            (ep['vote_average'] as num?)?.toDouble() ?? 0.0;
        final int voteCount = ep['vote_count'] as int? ?? 0;
        final String episodeKey = '$seasonNumber-$epNum';

        // Format season/episode as S01 | E02
        final String seasonLabel =
            'S${seasonNumber.toString().padLeft(2, '0')}';
        final String episodeLabel = 'E${epNum.toString().padLeft(2, '0')}';

        return Container(
          margin: const EdgeInsets.only(left: 2.0, right: 2.0, bottom: 10.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8.0),
          ),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () => _showEpisodeDetailsBottomSheet(
              ep,
              seasonNumber,
              name,
              epNum,
              airDate,
              stillPath,
              overview,
              voteAverage,
              voteCount,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Episode Thumbnail – flush left, no extra padding
                Container(
                  width: 90,
                  height: 90,
                  color: AppColors.surfaceLight,
                  child: stillPath != null && stillPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _getImageUrl(stillPath, size: 'w300'),
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.tv,
                              size: 24,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.tv,
                            size: 24,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                // Episode info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$seasonLabel | $episodeLabel',
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Checkmark / days-until-release
                if (isReleased)
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, authState) {
                      return BlocBuilder<
                        TvShowWatchlistCubit,
                        TvShowWatchlistState
                      >(
                        builder: (context, watchState) {
                          bool isTracked = false;
                          bool isWatched = false;
                          List<String> watchedEpisodes = [];

                          if (watchState is TvShowWatchlistSuccess) {
                            try {
                              final showDoc = watchState.shows.firstWhere(
                                (s) => s['id'] == widget.mediaId,
                              );
                              isTracked = true;
                              if (showDoc['watchedEpisodes'] != null) {
                                watchedEpisodes = List<String>.from(
                                  showDoc['watchedEpisodes'],
                                );
                                isWatched = watchedEpisodes.contains(
                                  episodeKey,
                                );
                              }
                            } catch (e) {
                              // Show not found in watchlist
                            }
                          }

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (authState is! Authenticated) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please log in to track episodes',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (!isTracked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Add show to watchlist first',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final uid = authState.user.uid;
                              final cubit = context
                                  .read<TvShowWatchlistCubit>();

                              if (!isWatched) {
                                final showState = context
                                    .read<ShowDetailsCubit>()
                                    .state;
                                if (showState is ShowDetailsSuccess) {
                                  final details = showState.details;
                                  final unwatchedPrev =
                                      _getUnwatchedPreviousEpisodes(
                                        details,
                                        seasonNumber,
                                        epNum,
                                        watchedEpisodes,
                                      );
                                  if (unwatchedPrev.isNotEmpty) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        title: const Text(
                                          'Mark Previous Episodes?',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: Text(
                                          'You have ${unwatchedPrev.length} unwatched previous episodes. Would you like to mark them as watched too?',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              cubit.toggleEpisodeWatched(
                                                uid: uid,
                                                showId: widget.mediaId,
                                                episodeKey: episodeKey,
                                                isWatched: true,
                                                showName: details['name']
                                                    ?.toString(),
                                                showPoster:
                                                    details['poster_path']
                                                        ?.toString(),
                                                episodeTitle:
                                                    ep['name']?.toString() ??
                                                    'Episode ${ep['episode_number']}',
                                              );
                                            },
                                            child: const Text(
                                              'No, just this one',
                                              style: TextStyle(
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              final allToMark = [
                                                ...unwatchedPrev,
                                                episodeKey,
                                              ];
                                              cubit.markMultipleEpisodesWatched(
                                                uid: uid,
                                                showId: widget.mediaId,
                                                episodeKeys: allToMark,
                                              );
                                            },
                                            child: const Text(
                                              'Yes, mark all',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                }
                              }

                              final showState = context
                                  .read<ShowDetailsCubit>()
                                  .state;
                              final details = showState is ShowDetailsSuccess
                                  ? showState.details
                                  : null;

                              cubit.toggleEpisodeWatched(
                                uid: uid,
                                showId: widget.mediaId,
                                episodeKey: episodeKey,
                                isWatched: !isWatched,
                                showName: details?['name']?.toString(),
                                showPoster: details?['poster_path']?.toString(),
                                episodeTitle:
                                    ep['name']?.toString() ??
                                    'Episode ${ep['episode_number']}',
                              );
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isWatched
                                    ? Colors.green
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isWatched
                                      ? Colors.green
                                      : Colors.white38,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 20,
                                color: isWatched
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                else if (daysUntilRelease != null)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${daysUntilRelease > 0 ? daysUntilRelease : 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (daysUntilRelease > 0 ? daysUntilRelease : 1) == 1
                            ? 'DAY'
                            : 'DAYS',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10.0,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCastCard({
    required int personId,
    required String imageUrl,
    required String realName,
    required String characterName,
  }) {
    return GestureDetector(
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white10,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Actor photo
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                width: 120,
                height: 180,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white24, size: 40),
                  ),
                ),
              )
            else
              Container(
                width: 120,
                height: 180,
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white24, size: 40),
                ),
              ),
            // Gradient for text readability
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 70,
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    realName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    characterName,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
