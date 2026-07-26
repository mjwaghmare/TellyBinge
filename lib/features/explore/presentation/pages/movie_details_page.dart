import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/action_circle_button.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../../core/widgets/watch_trailer_button.dart';
import '../cubit/movie_details_cubit.dart';
import '../cubit/movie_details_state.dart';

class MovieDetailsPage extends StatelessWidget {
  final int movieId;
  final bool fromRecommendation;

  const MovieDetailsPage({
    super.key,
    required this.movieId,
    this.fromRecommendation = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MovieDetailsCubit>(
      create: (context) =>
          MovieDetailsCubit(tmdbClient: context.read<TmdbClient>()),
      child: MovieDetailsView(
        movieId: movieId,
        fromRecommendation: fromRecommendation,
      ),
    );
  }
}

class MovieDetailsView extends StatefulWidget {
  final int movieId;
  final bool fromRecommendation;

  const MovieDetailsView({
    super.key,
    required this.movieId,
    this.fromRecommendation = false,
  });

  @override
  State<MovieDetailsView> createState() => _MovieDetailsViewState();
}

class _MovieDetailsViewState extends State<MovieDetailsView> {
  @override
  void initState() {
    super.initState();
    context.read<MovieDetailsCubit>().loadMovieDetails(widget.movieId);
  }

  Map<String, dynamic> _dummyMovieData() {
    return {
      'title': 'Loading Movie Title Here',
      'backdrop_path': '',
      'release_date': '2026-06-19',
      'genres': [
        {'name': 'Action'},
        {'name': 'Adventure'},
      ],
      'overview':
          'This is a placeholder description text to display a beautiful loading shimmer representation of the details overview section of the page.',
      'vote_average': 8.5,
      'vote_count': 1000,
      'runtime': 120,
    };
  }

  List<dynamic> _dummyCastList() {
    return List.generate(
      4,
      (index) => {
        'name': 'Actor Name',
        'character': 'Character Name',
        'profile_path': null,
      },
    );
  }

  String _getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBA';
    try {
      final date = DateTime.parse(dateStr);
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatGenres(List<dynamic>? genres) {
    if (genres == null || genres.isEmpty) return '';
    return genres.map((g) => g['name'] as String? ?? '').join(', ');
  }

  String _formatRuntime(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  bool _isReleased(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final date = DateTime.parse(dateStr);
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _showMoreActions({
    required BuildContext context,
    required String uid,
    required bool isWatched,
    required bool released,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Movie Actions'),
        actions: <CupertinoActionSheetAction>[
          if (released)
            CupertinoActionSheetAction(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                context.read<MovieWatchlistCubit>().toggleWatched(
                  uid: uid,
                  movieId: widget.movieId,
                  isWatched: !isWatched,
                );
              },
              child: Text(isWatched ? 'Mark as unwatched' : 'Mark as watched'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              context.read<MovieWatchlistCubit>().removeMovie(
                uid: uid,
                movieId: widget.movieId,
              );
            },
            child: const Text('Remove movie'),
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

  @override
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MovieDetailsCubit, MovieDetailsState>(
      builder: (context, state) {
        final bool isLoading =
            state is MovieDetailsInitial || state is MovieDetailsLoading;
        final String? error = state is MovieDetailsError ? state.message : null;

        if (error != null && state is! MovieDetailsSuccess) {
          String userFriendlyError = 'An unexpected error occurred. Please try again.';
          if (error.contains('404')) {
            userFriendlyError = 'This movie could not be found or may have been removed.';
          } else if (error.contains('SocketException') || error.contains('DioException')) {
            userFriendlyError = 'Please check your internet connection and try again.';
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 22,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
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
                      onPressed: () {
                        context.read<MovieDetailsCubit>().loadMovieDetails(
                          widget.movieId,
                        );
                      },
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

        final movieData = state is MovieDetailsSuccess
            ? state.movieDetails
            : null;
        final castData = state is MovieDetailsSuccess
            ? (state.movieCredits['cast'] as List<dynamic>? ?? [])
                  .take(10)
                  .toList()
            : [];
        final collectionParts = state is MovieDetailsSuccess
            ? state.collectionParts
            : [];
        final collectionSectionTitle = state is MovieDetailsSuccess
            ? state.collectionSectionTitle
            : 'Franchise';
        final similarMovies = state is MovieDetailsSuccess
            ? state.similarMovies
            : [];

        final authState = context.read<AuthCubit>().state;
        final String? uid = authState is Authenticated
            ? authState.user.uid
            : null;

        final movie = isLoading ? _dummyMovieData() : movieData!;
        final cast = isLoading ? _dummyCastList() : castData;
        final title = movie['title'] as String? ?? 'Unknown';
        final backdropPath = movie['backdrop_path'] as String?;
        final releaseDate = movie['release_date'] as String?;
        final genres = _formatGenres(movie['genres'] as List<dynamic>?);
        final overview = movie['overview'] as String? ?? '';
        final voteAverage = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
        final voteCount = (movie['vote_count'] as num?)?.toInt() ?? 0;
        final runtimeMinutes = (movie['runtime'] as num?)?.toInt() ?? 0;
        final runtime = _formatRuntime(runtimeMinutes);
        final language = (movie['original_language'] as String? ?? '').toUpperCase();
        final released = _isReleased(releaseDate);

        final videos = isLoading
            ? <dynamic>[]
            : (movie['videos']?['results'] as List<dynamic>? ?? []);
        final youtubeTrailers = videos
            .where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
            .toList();
        final otherTrailers = videos
            .where((v) => v['type'] == 'Trailer' && v['site'] != 'YouTube')
            .toList();
        final Map<String, dynamic>? trailer = youtubeTrailers.isNotEmpty
            ? youtubeTrailers.first
            : (otherTrailers.isNotEmpty ? otherTrailers.first : null);

        return BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
          builder: (context, watchlistState) {
            bool isAdded = false;
            bool isWatched = false;
            bool isFavorite = false;
            final Set<int> watchlistedIds = {};
            if (watchlistState is MovieWatchlistSuccess && uid != null) {
              for (final m in watchlistState.movies) {
                final rawId = m['id'];
                int? id;
                if (rawId is num) {
                  id = rawId.toInt();
                } else if (rawId is String) {
                  id = int.tryParse(rawId);
                }
                if (id != null) {
                  watchlistedIds.add(id);
                }
              }
              final matched = watchlistState.movies.where((m) {
                final rawId = m['id'];
                int? id;
                if (rawId is num) {
                  id = rawId.toInt();
                } else if (rawId is String) {
                  id = int.tryParse(rawId);
                }
                return id == widget.movieId;
              });
              if (matched.isNotEmpty) {
                isAdded = true;
                isWatched = matched.first['isWatched'] as bool? ?? false;
                isFavorite = matched.first['isFavorite'] as bool? ?? false;
              }
            }

            // Show all collection parts regardless of watchlist status
            final visibleCollectionParts = collectionParts.take(5).toList();

            final visibleSimilarMovies = similarMovies
                .where((item) {
                  final rawId = item['id'];
                  int? id;
                  if (rawId is num) {
                    id = rawId.toInt();
                  } else if (rawId is String) {
                    id = int.tryParse(rawId);
                  }
                  if (id == null) return false;
                  return !watchlistedIds.contains(id);
                })
                .take(5)
                .toList();

            final double bottomPadding = MediaQuery.paddingOf(context).bottom;
            final double buttonHeight = 50.0;
            final double verticalMargin = 12.0;
            final double horizontalMargin = 16.0;
            final double totalContainerHeight =
                buttonHeight + verticalMargin + verticalMargin + bottomPadding;

            return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                bottomNavigationBar: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: (isLoading || isAdded) ? 0.0 : totalContainerHeight,
                  curve: Curves.easeInOut,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: horizontalMargin,
                        right: horizontalMargin,
                        top: verticalMargin,
                        bottom: verticalMargin + bottomPadding,
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (uid != null) {
                            HapticFeedback.mediumImpact();
                            context.read<MovieWatchlistCubit>().addMovie(
                              uid: uid,
                              movieId: widget.movieId,
                              title: title,
                              posterPath: movie['poster_path'],
                              backdropPath: movie['backdrop_path'],
                              releaseDate: releaseDate,
                              runtime: runtimeMinutes,
                              voteAverage: voteAverage,
                              genres: genres,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'ADD MOVIE',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                body: Stack(
                  children: [
                    Skeletonizer(
                      enabled: isLoading,
                      child: CustomScrollView(
                        slivers: [
                          SliverAppBar(
                            automaticallyImplyLeading: false,
                            leading: const SizedBox.shrink(),
                            backgroundColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            expandedHeight: 300.0,
                            pinned: true,
                      actions: [
                        if (isAdded && uid != null)
                          IconButton(
                            icon: const Icon(
                              Icons.more_horiz,
                              size: 28,
                              color: Colors.white,
                            ),
                            onPressed: () => _showMoreActions(
                              context: context,
                              uid: uid,
                              isWatched: isWatched,
                              released: released,
                            ),
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        centerTitle: false,
                        titlePadding: const EdgeInsets.only(
                          left: 16,
                          bottom: 4,
                          right: 48,
                        ),
                        title: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (genres.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                genres,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (backdropPath != null && backdropPath.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: _getImageUrl(backdropPath),
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    Container(color: Colors.grey[900]),
                              )
                            else
                              Container(color: Colors.grey[900]),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black45,
                                    Colors.transparent,
                                    Colors.black,
                                  ],
                                  stops: [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.sm),
                            // Date & Runtime Row
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(releaseDate),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                if (runtime.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    runtime,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if (uid != null) ...[
                                  Skeleton.ignore(
                                    child: ActionCircleButton(
                                      isActive: isFavorite,
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        if (isAdded) {
                                          context
                                              .read<MovieWatchlistCubit>()
                                              .toggleFavorite(
                                                uid: uid,
                                                movieId: widget.movieId,
                                                isFavorite: !isFavorite,
                                              );
                                        } else {
                                          context
                                              .read<MovieWatchlistCubit>()
                                              .addMovie(
                                                uid: uid,
                                                movieId: widget.movieId,
                                                title: title,
                                                posterPath:
                                                    movie['poster_path']
                                                        as String?,
                                                backdropPath:
                                                    movie['backdrop_path']
                                                        as String?,
                                                releaseDate: releaseDate,
                                                runtime: runtimeMinutes,
                                                voteAverage: voteAverage,
                                                genres: genres,
                                                isFavorite: true,
                                              );
                                        }
                                      },
                                      activeIcon: Icons.favorite,
                                      inactiveIcon: Icons.favorite_border,
                                      activeIconColor: Colors.red,
                                      inactiveIconColor: Colors.white,
                                      activeBgColor: Colors.grey.withValues(
                                        alpha: 0.3,
                                      ),
                                      inactiveBgColor: Colors.grey.withValues(
                                        alpha: 0.3,
                                      ),
                                      size: 28.0,
                                      iconSize: 16.0,
                                    ),
                                  ),
                                  if (released) const SizedBox(width: 12),
                                ],
                                if (released && uid != null)
                                  Skeleton.ignore(
                                    child: ActionCircleButton(
                                      isActive: isWatched,
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        if (isAdded) {
                                          context
                                              .read<MovieWatchlistCubit>()
                                              .toggleWatched(
                                                uid: uid,
                                                movieId: widget.movieId,
                                                isWatched: !isWatched,
                                              );
                                        } else {
                                          context
                                              .read<MovieWatchlistCubit>()
                                              .addMovie(
                                                uid: uid,
                                                movieId: widget.movieId,
                                                title: title,
                                                posterPath:
                                                    movie['poster_path']
                                                        as String?,
                                                backdropPath:
                                                    movie['backdrop_path']
                                                        as String?,
                                                releaseDate: releaseDate,
                                                runtime: runtimeMinutes,
                                                voteAverage: voteAverage,
                                                genres: genres,
                                                isWatched: true,
                                              );
                                        }
                                      },
                                      activeIcon: Icons.check,
                                      inactiveIcon: Icons.check,
                                      activeIconColor: Colors.white,
                                      inactiveIconColor: Colors.grey,
                                      activeBgColor: Colors.green,
                                      inactiveBgColor: Colors.grey.withValues(
                                        alpha: 0.3,
                                      ),
                                      size: 28.0,
                                      iconSize: 16.0,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Divider(
                              color: Colors.white24,
                              height: 1,
                              thickness: 0.5,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Movie Info Section
                            const Text(
                              'Movie info',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Rating row
                            Row(
                              children: [
                                ..._buildStars(
                                  voteAverage / 2,
                                ), // TMDb is out of 10, convert to 5
                                const SizedBox(width: 8),
                                Text(
                                  '${(voteAverage / 2).toStringAsFixed(1)}/5',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatVoteCount(voteCount),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (language.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.language,
                                    color: Colors.white54,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Language: $language',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            if (overview.isNotEmpty)
                              Text(
                                overview,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            if (trailer != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              const Divider(
                                color: Colors.white24,
                                height: 1,
                                thickness: 0.5,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              WatchTrailerButton(trailer: trailer),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(
                              color: Colors.white24,
                              height: 1,
                              thickness: 0.5,
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // Cast Section
                            if (cast.isNotEmpty) ...[
                              const Text(
                                'Cast',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 180,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: cast.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final actor =
                                        cast[index] as Map<String, dynamic>;
                                    final actorName =
                                        actor['name'] as String? ?? '';
                                    final character =
                                        actor['character'] as String? ?? '';
                                    final profilePath =
                                        actor['profile_path'] as String?;
                                    return _buildCastCard(
                                      imageUrl: _getImageUrl(
                                        profilePath,
                                        size: 'w185',
                                      ),
                                      realName: actorName,
                                      characterName: character.toUpperCase(),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],

                            // Franchise Collection Parts
                            if (!widget.fromRecommendation &&
                                visibleCollectionParts.isNotEmpty) ...[
                              const Divider(
                                color: Colors.white24,
                                height: 1,
                                thickness: 0.5,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                collectionSectionTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 200,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: visibleCollectionParts.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final rec =
                                        visibleCollectionParts[index]
                                            as Map<String, dynamic>;
                                    final rawRecId = rec['id'];
                                    int? recId;
                                    if (rawRecId is num) {
                                      recId = rawRecId.toInt();
                                    } else if (rawRecId is String) {
                                      recId = int.tryParse(rawRecId);
                                    }
                                    if (recId == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final String recTitle =
                                        rec['title'] ??
                                        rec['name'] ??
                                        'Unknown';
                                    final String? recPoster =
                                        rec['poster_path'];
                                    final String? recBackdrop =
                                        rec['backdrop_path'];
                                    final String? recDate = rec['release_date'];
                                    final double recVote =
                                        (rec['vote_average'] as num?)
                                            ?.toDouble() ??
                                        0.0;

                                    return _buildRecommendationCard(
                                      movieId: recId,
                                      posterPath: recPoster,
                                      title: recTitle,
                                      releaseDate: recDate,
                                      voteAverage: recVote,
                                      backdropPath: recBackdrop,
                                      runtime: 0,
                                      genres: '',
                                      isAdded: watchlistedIds.contains(recId),
                                      uid: uid,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],

                            // Similar Movie Recommendations
                            if (!widget.fromRecommendation &&
                                visibleSimilarMovies.isNotEmpty) ...[
                              const Divider(
                                color: Colors.white24,
                                height: 1,
                                thickness: 0.5,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              const Text(
                                'More Like This',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 200,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: visibleSimilarMovies.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final rec =
                                        visibleSimilarMovies[index]
                                            as Map<String, dynamic>;
                                    final rawRecId = rec['id'];
                                    int? recId;
                                    if (rawRecId is num) {
                                      recId = rawRecId.toInt();
                                    } else if (rawRecId is String) {
                                      recId = int.tryParse(rawRecId);
                                    }
                                    if (recId == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final String recTitle =
                                        rec['title'] ??
                                        rec['name'] ??
                                        'Unknown';
                                    final String? recPoster =
                                        rec['poster_path'];
                                    final String? recBackdrop =
                                        rec['backdrop_path'];
                                    final String? recDate = rec['release_date'];
                                    final double recVote =
                                        (rec['vote_average'] as num?)
                                            ?.toDouble() ??
                                        0.0;

                                    return _buildRecommendationCard(
                                      movieId: recId,
                                      posterPath: recPoster,
                                      title: recTitle,
                                      releaseDate: recDate,
                                      voteAverage: recVote,
                                      backdropPath: recBackdrop,
                                      runtime: 0,
                                      genres: '',
                                      isAdded: false,
                                      uid: uid,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
        },
      );
    }

  List<Widget> _buildStars(double rating) {
    final List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (rating >= i) {
        stars.add(const Icon(Icons.star, color: Colors.amber, size: 16));
      } else if (rating >= i - 0.5) {
        stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 16));
      } else {
        stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 16));
      }
    }
    return stars;
  }

  String _formatVoteCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K ratings';
    }
    return '$count ratings';
  }

  Widget _buildCastCard({
    required String imageUrl,
    required String realName,
    required String characterName,
  }) {
    return Container(
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
    );
  }

  Widget _buildRecommendationCard({
    required int movieId,
    required String? posterPath,
    required String title,
    required String? releaseDate,
    required double voteAverage,
    required String? backdropPath,
    required int runtime,
    required String genres,
    required bool isAdded,
    required String? uid,
  }) {
    final hasImage = posterPath != null && posterPath.isNotEmpty;

    String year = '';
    if (releaseDate != null && releaseDate.isNotEmpty) {
      try {
        year = DateTime.parse(releaseDate).year.toString();
      } catch (_) {
        if (releaseDate.length >= 4) {
          year = releaseDate.substring(0, 4);
        }
      }
    }

    return GestureDetector(
      key: ValueKey(movieId),
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) =>
                MovieDetailsPage(movieId: movieId, fromRecommendation: true),
          ),
        );
      },
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie Poster Image (100x140)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Stack(
                children: [
                  Container(
                    height: 140,
                    width: 100,
                    color: AppColors.surfaceLight,
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: _getImageUrl(posterPath, size: 'w185'),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: AppColors.surfaceLight),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(
                                Icons.movie_creation_outlined,
                                size: 24,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.movie_creation_outlined,
                              size: 24,
                              color: AppColors.textTertiary,
                            ),
                          ),
                  ),
                  if (isAdded)
                    Container(
                      height: 140,
                      width: 100,
                      color: Colors.black.withValues(
                        alpha: 0.15,
                      ), // Very light overlay
                    ),
                  if (isAdded && uid != null)
                    Positioned(
                      top: -10,
                      right: -5,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          context.read<MovieWatchlistCubit>().removeMovie(
                            uid: uid,
                            movieId: movieId,
                          );
                        },
                        child: Container(
                          color: Colors.transparent, // Expands hit area
                          padding: const EdgeInsets.only(
                            left: 8,
                            right: 4,
                            bottom: 8,
                            top: 0,
                          ),
                          child: const Icon(
                            Icons.bookmark_sharp,
                            color: AppColors
                                .primary, // Using the app's brand color
                            size: 40,
                            shadows: [
                              Shadow(
                                blurRadius: 4.0,
                                color: Colors.black87,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Movie Title
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            // Rating & Year Row
            Row(
              children: [
                if (voteAverage > 0.0) ...[
                  const Icon(Icons.star, color: AppColors.primary, size: 10.0),
                  const SizedBox(width: 3),
                  Text(
                    voteAverage.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (year.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Text(
                      '•',
                      style: TextStyle(
                        fontSize: 10.0,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      year,
                      style: const TextStyle(
                        fontSize: 10.0,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ] else if (year.isNotEmpty) ...[
                  Text(
                    year,
                    style: const TextStyle(
                      fontSize: 10.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
