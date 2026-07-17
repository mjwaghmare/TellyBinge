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

class MovieDetailsPage extends StatefulWidget {
  final int movieId;
  final bool fromRecommendation;

  const MovieDetailsPage({
    super.key,
    required this.movieId,
    this.fromRecommendation = false,
  });

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  Map<String, dynamic>? _movieData;
  List<dynamic> _cast = [];
  bool _isLoading = true;
  String? _error;

  // Recommendation list state variables
  List<dynamic> _collectionParts = [];
  String _collectionSectionTitle = 'Franchise';
  List<dynamic> _similarMovies = [];

  @override
  void initState() {
    super.initState();
    _fetchMovieData();
  }

  Future<void> _fetchMovieData() async {
    final tmdbClient = context.read<TmdbClient>();

    // Retry up to 3 times to handle flaky network connections
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final movieDetails = await tmdbClient.getMovieDetails(widget.movieId);
        // Stagger by 100ms to avoid concurrent connection resets
        await Future.delayed(const Duration(milliseconds: 100));
        final movieCredits = await tmdbClient.getMovieCredits(widget.movieId);

        if (!mounted) return;
        
        final belongsToCollection = movieDetails['belongs_to_collection'];
        final List<dynamic> collectionParts = [];
        String collectionSectionTitle = 'Franchise';
        if (belongsToCollection != null && belongsToCollection['id'] != null) {
          final collectionId = belongsToCollection['id'] as int;
          try {
            final collectionDetails = await tmdbClient.getCollectionDetails(
              collectionId,
            );
            final parts = collectionDetails['parts'] as List<dynamic>? ?? [];
            collectionParts.addAll(
              parts.where((item) => item['id'] != widget.movieId),
            );
            final collectionName =
                belongsToCollection['name'] as String? ?? 'Franchise';
            collectionSectionTitle = 'More from $collectionName';
          } catch (e) {
            debugPrint('Failed to load collection details: $e');
          }
        }

        // Always fetch similar movies
        List<dynamic> similarMovies = [];
        try {
          similarMovies = await tmdbClient.getSimilarMovies(widget.movieId);
        } catch (e) {
          debugPrint('Failed to load similar movies: $e');
        }

        // Sort collection parts by release date descending (latest first)
        collectionParts.sort((a, b) {
          final aDateStr = a['release_date'] as String? ?? '';
          final bDateStr = b['release_date'] as String? ?? '';
          if (aDateStr.isEmpty) return 1;
          if (bDateStr.isEmpty) return -1;
          try {
            final aDate = DateTime.parse(aDateStr);
            final bDate = DateTime.parse(bDateStr);
            return bDate.compareTo(aDate);
          } catch (_) {
            return 0;
          }
        });

        // Sort similar movies by release date descending (latest first)
        similarMovies.sort((a, b) {
          final aDateStr = a['release_date'] as String? ?? '';
          final bDateStr = b['release_date'] as String? ?? '';
          if (aDateStr.isEmpty) return 1;
          if (bDateStr.isEmpty) return -1;
          try {
            final aDate = DateTime.parse(aDateStr);
            final bDate = DateTime.parse(bDateStr);
            return bDate.compareTo(aDate);
          } catch (_) {
            return 0;
          }
        });

        if (!mounted) return;
        setState(() {
          _movieData = movieDetails;
          _cast = (movieCredits['cast'] as List<dynamic>? ?? [])
              .take(10)
              .toList();
          _collectionParts = collectionParts;
          _similarMovies = similarMovies;
          _isLoading = false;
          _collectionSectionTitle = collectionSectionTitle;
        });
        return; // Success, exit
      } catch (e) {
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 1));
          continue; // Retry
        }
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
  Widget build(BuildContext context) {
    if (_error != null && _movieData == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 32,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/error_devices.png',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Failed to load movie details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? '',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _fetchMovieData();
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

    final authState = context.read<AuthCubit>().state;
    final String? uid = authState is Authenticated ? authState.user.uid : null;

    final movie = _isLoading ? _dummyMovieData() : _movieData!;
    final cast = _isLoading ? _dummyCastList() : _cast;
    final title = movie['title'] as String? ?? 'Unknown';
    final backdropPath = movie['backdrop_path'] as String?;
    final releaseDate = movie['release_date'] as String?;
    final genres = _formatGenres(movie['genres'] as List<dynamic>?);
    final overview = movie['overview'] as String? ?? '';
    final voteAverage = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
    final voteCount = movie['vote_count'] as int? ?? 0;
    final runtime = _formatRuntime(movie['runtime'] as int?);
    final released = _isReleased(releaseDate);

    final videos = _isLoading
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
        final visibleCollectionParts = _collectionParts.take(5).toList();

        final visibleSimilarMovies = _similarMovies
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

        return Skeletonizer(
          enabled: _isLoading,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            bottomNavigationBar: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: (_isLoading || isAdded) ? 0.0 : kToolbarHeight,
              curve: Curves.easeInOut,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: InkWell(
                  onTap: () {
                    if (uid != null) {
                      HapticFeedback.mediumImpact();
                      context.read<MovieWatchlistCubit>().addMovie(
                        uid: uid,
                        movieId: widget.movieId,
                        title: title,
                        posterPath: movie['poster_path'],
                        backdropPath: movie['backdrop_path'],
                        releaseDate: releaseDate,
                        runtime: movie['runtime'] as int? ?? 0,
                        voteAverage: voteAverage,
                        genres: genres,
                      );
                    }
                  },
                  child: Container(
                    height: kToolbarHeight,
                    color: Colors.yellow,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.black, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'ADD MOVIE',
                          style: TextStyle(
                            color: Colors.black,
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
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  expandedHeight: 300.0,
                  pinned: true,
                  leading: Skeleton.ignore(
                    child: IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 32,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
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
                                padding: EdgeInsets.symmetric(horizontal: 8),
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
                                                movie['poster_path'] as String?,
                                            backdropPath:
                                                movie['backdrop_path']
                                                    as String?,
                                            releaseDate: releaseDate,
                                            runtime:
                                                movie['runtime'] as int? ?? 0,
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
                                                movie['poster_path'] as String?,
                                            backdropPath:
                                                movie['backdrop_path']
                                                    as String?,
                                            releaseDate: releaseDate,
                                            runtime:
                                                movie['runtime'] as int? ?? 0,
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
                            _collectionSectionTitle,
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
                                    rec['title'] ?? rec['name'] ?? 'Unknown';
                                final String? recPoster = rec['poster_path'];
                                final String? recBackdrop =
                                    rec['backdrop_path'];
                                final String? recDate = rec['release_date'];
                                final double recVote =
                                    (rec['vote_average'] as num?)?.toDouble() ??
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
                                    rec['title'] ?? rec['name'] ?? 'Unknown';
                                final String? recPoster = rec['poster_path'];
                                final String? recBackdrop =
                                    rec['backdrop_path'];
                                final String? recDate = rec['release_date'];
                                final double recVote =
                                    (rec['vote_average'] as num?)?.toDouble() ??
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
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MovieDetailsPage(movieId: movieId, fromRecommendation: true),
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
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie Poster Image (100x140)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
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
