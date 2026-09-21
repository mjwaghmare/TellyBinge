import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/action_circle_button.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/auth_required_view.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../../core/widgets/watch_trailer_button.dart';
import '../../../../core/widgets/watch_providers_section.dart';
import '../../../../core/widgets/polaroid_share_modal.dart';
import '../cubit/movie_details_cubit.dart';
import '../cubit/movie_details_state.dart';
import '../../../person/presentation/widgets/person_details_bottom_sheet.dart';

class MovieDetailsPage extends StatelessWidget {
  final int movieId;
  final String? title;
  final String? posterPath;
  final String? backdropPath;
  final bool fromRecommendation;

  const MovieDetailsPage({
    super.key,
    required this.movieId,
    this.title,
    this.posterPath,
    this.backdropPath,
    this.fromRecommendation = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MovieDetailsCubit>(
      create: (context) =>
          MovieDetailsCubit(tmdbClient: context.read<TmdbClient>())
            ..loadMovieDetails(movieId),
      child: MovieDetailsView(
        movieId: movieId,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        fromRecommendation: fromRecommendation,
      ),
    );
  }
}

class MovieDetailsView extends StatefulWidget {
  final int movieId;
  final String? title;
  final String? posterPath;
  final String? backdropPath;
  final bool fromRecommendation;

  const MovieDetailsView({
    super.key,
    required this.movieId,
    this.title,
    this.posterPath,
    this.backdropPath,
    this.fromRecommendation = false,
  });

  @override
  State<MovieDetailsView> createState() => _MovieDetailsViewState();
}

class _MovieDetailsViewState extends State<MovieDetailsView> {
  bool _hasAutoSyncedMetadata = false;
  late final ScrollController _scrollController;
  final ValueNotifier<bool> _isCollapsed = ValueNotifier<bool>(false);

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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isCollapsed.dispose();
    super.dispose();
  }

  Map<String, dynamic> _dummyMovieData() {
    return {
      'title': widget.title ?? 'Loading Movie Details',
      'poster_path': widget.posterPath,
      'backdrop_path': widget.backdropPath ?? '',
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

  List<dynamic> _dummyCollectionParts() {
    return List.generate(
      4,
      (index) => {
        'id': index + 1000,
        'title': 'Collection Part',
        'poster_path': null,
        'backdrop_path': null,
        'release_date': '2026-06-19',
        'vote_average': 8.0,
      },
    );
  }

  List<dynamic> _dummySimilarMovies() {
    return List.generate(
      4,
      (index) => {
        'id': index + 2000,
        'title': 'Similar Movie',
        'poster_path': null,
        'backdrop_path': null,
        'release_date': '2026-06-19',
        'vote_average': 8.0,
      },
    );
  }

  String _getImageUrl(String? path, {String size = 'w500'}) {
    return AppConstants.tmdbImageUrl(path ?? '', size: size);
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
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      final relDay = DateTime.utc(date.year, date.month, date.day);
      return !relDay.isAfter(today);
    } catch (_) {
      return false;
    }
  }

  void _showMoreActions({
    required BuildContext context,
    required String uid,
    required bool isWatched,
    required bool released,
    required String title,
    required String? imageUrl,
    required double? rating,
    required DateTime? watchedDate,
    bool canShare = true,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Movie Actions'),
        actions: <CupertinoActionSheetAction>[
          if (canShare)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                PolaroidShareModal.show(
                  context,
                  title: title,
                  imageUrl: imageUrl,
                  rating: rating,
                  watchedDate: watchedDate,
                  mediaType: 'movie',
                );
              },
              child: const Text('Share Polaroid 📸'),
            ),
          if (released)
            CupertinoActionSheetAction(
              onPressed: () {
                AppHaptics.mediumImpact();
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
              AppHaptics.mediumImpact();
              Navigator.pop(context);
              context.read<MovieWatchlistCubit>().removeMovie(
                uid: uid,
                movieId: widget.movieId,
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

  @override
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MovieDetailsCubit, MovieDetailsState>(
      builder: (context, state) {
        final bool isLoading =
            state is MovieDetailsInitial || state is MovieDetailsLoading;
        final bool isCastLoading =
            state is MovieDetailsSuccess && state.isCastLoading;
        final bool isCollectionLoading =
            state is MovieDetailsSuccess && state.isCollectionLoading;
        final bool isSimilarLoading =
            state is MovieDetailsSuccess && state.isSimilarLoading;

        final String? error = state is MovieDetailsError ? state.message : null;

        if (error != null && state is! MovieDetailsSuccess) {
          String userFriendlyError =
              'An unexpected error occurred. Please try again.';
          if (error.contains('404')) {
            userFriendlyError =
                'This movie could not be found or may have been removed.';
          } else if (error.contains('SocketException') ||
              error.contains('DioException')) {
            userFriendlyError =
                'Please check your internet connection and try again.';
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 22,
                  color: context.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Padding(
                padding: AppSpacing.allXXL,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      AppAssets.errorDevices,
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                    AppSpacing.gapH32,
                    Text(
                      'Oops! Something went wrong',
                      style: AppTextStyles.lg.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapH12,
                    Text(
                      userFriendlyError,
                      style: AppTextStyles.sm.copyWith(
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapH32,
                    ElevatedButton(
                      onPressed: () {
                        context.read<MovieDetailsCubit>().loadMovieDetails(
                          widget.movieId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.xl),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      child: Text(
                        'RETRY',
                        style: AppTextStyles.smBold.copyWith(
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
        final crewData = state is MovieDetailsSuccess
            ? (state.movieCredits['crew'] as List<dynamic>? ?? [])
            : [];
        final List<Map<String, dynamic>> directors = [];
        final Set<int> seenDirectorIds = {};
        for (final member in crewData) {
          if (member is Map<String, dynamic> && member['job'] == 'Director') {
            final id = (member['id'] as num?)?.toInt();
            if (id != null && seenDirectorIds.add(id)) {
              directors.add(member);
            }
          }
        }

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

        final List<Map<String, dynamic>> directorCards = directors.map((d) {
          return {
            'id': d['id'],
            'name': d['name'],
            'character': 'DIRECTOR',
            'profile_path': d['profile_path'],
            'is_crew': true,
          };
        }).toList();

        final combinedCredits = [
          ...directorCards,
          ...castData,
        ];

        final cast = isLoading || isCastLoading
            ? _dummyCastList()
            : combinedCredits;
        final visibleCollectionParts = isCollectionLoading
            ? _dummyCollectionParts()
            : collectionParts.take(5).toList();
        final visibleSimilarMoviesRaw = isSimilarLoading
            ? _dummySimilarMovies()
            : similarMovies;

        final authState = context.read<AuthCubit>().state;
        final String? uid = authState is Authenticated
            ? authState.user.uid
            : null;

        final movie = isLoading
            ? _dummyMovieData()
            : (movieData ?? _dummyMovieData());
        final title = movie['title'] as String? ?? 'Unknown';
        final backdropPath = movie['backdrop_path'] as String?;
        final releaseDate = movie['release_date'] as String?;
        final genres = _formatGenres(movie['genres'] as List<dynamic>?);
        final tagline = (movie['tagline'] as String? ?? '').trim();
        final overview = movie['overview'] as String? ?? '';
        final voteAverage = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
        final voteCount = (movie['vote_count'] as num?)?.toInt() ?? 0;
        final runtimeMinutes = (movie['runtime'] as num?)?.toInt() ?? 0;
        final runtime = _formatRuntime(runtimeMinutes);
        final language = (movie['original_language'] as String? ?? '')
            .toUpperCase();
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
            String? watchedAtStr;
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
                watchedAtStr =
                    matched.first['watchedAt'] as String? ??
                    matched.first['addedAt'] as String?;

                // Auto-sync release date and metadata if TMDb has updated info
                if (!_hasAutoSyncedMetadata &&
                    !isLoading &&
                    releaseDate != null &&
                    releaseDate.isNotEmpty) {
                  final storedDate =
                      (matched.first['releaseDate'] ??
                              matched.first['release_date'])
                          as String? ??
                      '';
                  final storedRuntime =
                      (matched.first['runtime'] as num?)?.toInt() ?? 0;

                  if (storedDate != releaseDate ||
                      (runtimeMinutes > 0 && storedRuntime == 0)) {
                    _hasAutoSyncedMetadata = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        context
                            .read<MovieWatchlistCubit>()
                            .updateMovieReleaseDate(
                              uid: uid,
                              movieId: widget.movieId,
                              releaseDate: releaseDate,
                              runtime:
                                  runtimeMinutes > 0 ? runtimeMinutes : null,
                              voteAverage: voteAverage > 0 ? voteAverage : null,
                            );
                      }
                    });
                  }
                }
              }
            }

            // Show all collection parts regardless of watchlist status

            final visibleSimilarMovies = isSimilarLoading
                ? visibleSimilarMoviesRaw
                : visibleSimilarMoviesRaw
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
                          AppHaptics.mediumImpact();
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
                        } else {
                          AuthRequiredBottomSheet.show(
                            context,
                            title: 'Sign in to Track Movies',
                            subtitle:
                                'Sign in to add movies to your personal watchlist.',
                            icon: Icons.movie_filter_rounded,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 22),
                          AppSpacing.gapW8,
                          Text(
                            'ADD TO WATCHLIST',
                            style: AppTextStyles.smBold.copyWith(
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
                      controller: _scrollController,
                      slivers: [
                        SliverAppBar(
                          automaticallyImplyLeading: false,
                          leading: const SizedBox.shrink(),
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          expandedHeight: 300.0,
                          pinned: true,
                          title: ValueListenableBuilder<bool>(
                            valueListenable: _isCollapsed,
                            builder: (context, isCollapsed, child) {
                              return AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: isCollapsed ? 1.0 : 0.0,
                                child: Text(
                                  title,
                                  style: AppTextStyles.mdBold,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                          centerTitle: true,
                          actions: [
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.ios_share_rounded,
                                    size: 20,
                                    color: AppColors.textOnPrimary,
                                  ),
                                  onPressed: (isLoading || state is! MovieDetailsSuccess)
                                      ? null
                                      : () {
                                          final shareImageUrl = _getImageUrl(
                                            movie['backdrop_path'] ?? movie['poster_path'],
                                            size: 'w780',
                                          );
                                          final watchedDate =
                                              (isWatched && watchedAtStr != null)
                                              ? DateTime.tryParse(watchedAtStr)
                                              : null;
                                          PolaroidShareModal.show(
                                            context,
                                            title: title,
                                            imageUrl: shareImageUrl,
                                            rating: voteAverage,
                                            watchedDate: watchedDate,
                                            mediaType: 'movie',
                                          );
                                        },
                                ),
                              ),
                            ),
                            if (isAdded && uid != null)
                              Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.xs),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      size: 24,
                                      color: AppColors.textOnPrimary,
                                    ),
                                    onPressed: () {
                                      final shareImageUrl = _getImageUrl(
                                        movie['backdrop_path'] ?? movie['poster_path'],
                                        size: 'w780',
                                      );
                                      final watchedDate =
                                          (isWatched && watchedAtStr != null)
                                          ? DateTime.tryParse(watchedAtStr)
                                          : null;
                                      _showMoreActions(
                                        context: context,
                                        uid: uid,
                                        isWatched: isWatched,
                                        released: released,
                                        title: title,
                                        imageUrl: shareImageUrl,
                                        rating: voteAverage,
                                        watchedDate: watchedDate,
                                        canShare: !isLoading && state is MovieDetailsSuccess,
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (backdropPath != null &&
                                    backdropPath.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: _getImageUrl(
                                      backdropPath,
                                    ),
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (context, url, error) =>
                                            Container(
                                              color: AppColors.surface,
                                            ),
                                  )
                                else
                                  Container(color: AppColors.surface),
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
                                Positioned(
                                  left: 16.0,
                                  right: 16.0,
                                  bottom: 16.0,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        style: AppTextStyles.xxl.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (genres.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          genres,
                                          style: AppTextStyles.sm.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          color: context.textTertiary,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(releaseDate),
                                          style: AppTextStyles.sm.copyWith(
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        if (runtime.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.xs,
                                            ),
                                            child: Text(
                                              '•',
                                              style: AppTextStyles.sm.copyWith(
                                                color: context.textTertiary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            runtime,
                                            style: AppTextStyles.sm.copyWith(
                                              color: context.textTertiary,
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Skeleton.ignore(
                                          child: ActionCircleButton(
                                            isActive: isFavorite,
                                            onTap: () {
                                              AppHaptics.mediumImpact();
                                              if (uid == null) {
                                                AuthRequiredBottomSheet.show(
                                                  context,
                                                  title:
                                                      'Sign in to Track Movies',
                                                  subtitle:
                                                      'Sign in to favorite and track movies you want to watch.',
                                                  icon: Icons
                                                      .movie_filter_rounded,
                                                );
                                                return;
                                              }
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
                                            activeIconColor: AppColors.error,
                                            inactiveIconColor: context.isLight
                                                ? AppColors.lightTextSecondary
                                                : AppColors.textPrimary,
                                            activeBgColor: context.isLight
                                                ? AppColors.error.withValues(alpha: 0.12)
                                                : AppColors.error.withValues(alpha: 0.2),
                                            inactiveBgColor: context.isLight
                                                ? AppColors.borderLight.withValues(alpha: 0.5)
                                                : AppColors.surfaceElevated.withValues(alpha: 0.5),
                                            size: 28.0,
                                            iconSize: 16.0,
                                          ),
                                        ),
                                        if (released) AppSpacing.gapW12,
                                        if (released)
                                          Skeleton.ignore(
                                            child: ActionCircleButton(
                                              isActive: isWatched,
                                              onTap: () {
                                                AppHaptics.mediumImpact();
                                                if (uid == null) {
                                                  AuthRequiredBottomSheet.show(
                                                    context,
                                                    title:
                                                        'Sign in to Track Movies',
                                                    subtitle:
                                                        'Sign in to track movies you have watched.',
                                                    icon: Icons
                                                        .check_circle_outline_rounded,
                                                  );
                                                  return;
                                                }
                                                if (isAdded) {
                                                  context
                                                      .read<
                                                        MovieWatchlistCubit
                                                      >()
                                                      .toggleWatched(
                                                        uid: uid,
                                                        movieId: widget.movieId,
                                                        isWatched: !isWatched,
                                                      );
                                                } else {
                                                  context
                                                      .read<
                                                        MovieWatchlistCubit
                                                      >()
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
                                                        releaseDate:
                                                            releaseDate,
                                                        runtime: runtimeMinutes,
                                                        voteAverage:
                                                            voteAverage,
                                                        genres: genres,
                                                        isWatched: true,
                                                      );
                                                }
                                              },
                                              activeIcon: Icons.check,
                                              inactiveIcon: Icons.check,
                                              activeIconColor: AppColors.success,
                                              inactiveIconColor: context.isLight
                                                  ? AppColors.lightTextSecondary
                                                  : AppColors.textPrimary,
                                              activeBgColor: context.isLight
                                                  ? AppColors.success.withValues(alpha: 0.12)
                                                  : AppColors.success.withValues(alpha: 0.2),
                                              inactiveBgColor: context.isLight
                                                  ? AppColors.borderLight.withValues(alpha: 0.5)
                                                  : AppColors.surfaceElevated.withValues(alpha: 0.5),
                                              size: 28.0,
                                              iconSize: 16.0,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isWatched) ...[
                                      AppSpacing.gapH8,
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.remove_red_eye_outlined,
                                            color: AppColors.success,
                                            size: 14,
                                          ),
                                          AppSpacing.gapW4,
                                          Text(
                                            watchedAtStr != null
                                                ? _formatDate(watchedAtStr)
                                                : 'Watched',
                                            style: AppTextStyles.xsBold.copyWith(
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                if (tagline.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    '“$tagline”',
                                    style: AppTextStyles.editorialTagline.copyWith(
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                AppSpacing.gapH16,
                                Divider(
                                  color: Theme.of(context).dividerColor,
                                  height: 1,
                                  thickness: 0.5,
                                ),
                                AppSpacing.gapH16,

                                // Movie Info Section
                                Text(
                                  'MOVIE INFO',
                                  style: AppTextStyles.posterHeader.copyWith(
                                    color: context.textPrimary,
                                  ),
                                ),
                                AppSpacing.gapH8,
                                // Rating row
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                    AppSpacing.gapW4,
                                    Text(
                                      '${voteAverage.toStringAsFixed(1)} / 10',
                                      style: AppTextStyles.smBold.copyWith(
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    AppSpacing.gapW8,
                                    Text(
                                      '(${_formatVoteCount(voteCount)})',
                                      style: AppTextStyles.xs.copyWith(
                                        color: context.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (language.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.language,
                                        color: context.textTertiary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Language: $language',
                                        style: AppTextStyles.xs.copyWith(
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (directors.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.movie_creation_outlined,
                                        color: context.textTertiary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Director${directors.length > 1 ? 's' : ''}: ',
                                        style: AppTextStyles.xs.copyWith(
                                          color: context.textSecondary,
                                        ),
                                      ),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              for (int i = 0;
                                                  i < directors.length;
                                                  i++) ...[
                                                if (i > 0)
                                                  Text(
                                                    ', ',
                                                    style: AppTextStyles.xs
                                                        .copyWith(
                                                      color:
                                                          context.textSecondary,
                                                    ),
                                                  ),
                                                GestureDetector(
                                                  onTap: () {
                                                    final id =
                                                        (directors[i]['id']
                                                                as num?)
                                                            ?.toInt() ??
                                                        0;
                                                    if (id > 0) {
                                                      PersonDetailsBottomSheet
                                                          .show(
                                                        context,
                                                        personId: id,
                                                        initialName:
                                                            directors[i]['name']
                                                                as String?,
                                                        initialProfilePath:
                                                            directors[i][
                                                                    'profile_path']
                                                                as String?,
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                    directors[i]['name']
                                                            as String? ??
                                                        '',
                                                    style: AppTextStyles
                                                        .xsMedium
                                                        .copyWith(
                                                      color: AppColors.primary,
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                      decorationColor: AppColors
                                                          .primary
                                                          .withValues(
                                                              alpha: 0.5),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                if (overview.isNotEmpty)
                                  Text(
                                    overview,
                                    style: AppTextStyles.sm.copyWith(
                                      color: context.textPrimary,
                                      height: 1.5,
                                    ),
                                  ),
                                if (trailer != null) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  Divider(
                                    color: Theme.of(context).dividerColor,
                                    height: 1,
                                    thickness: 0.5,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  WatchTrailerButton(
                                    trailer: trailer,
                                    allTrailers: youtubeTrailers,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                Divider(
                                  color: Theme.of(context).dividerColor,
                                  height: 1,
                                  thickness: 0.5,
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Where to Watch Section
                                if (WatchProvidersSection.hasProviders(
                                  movie['watch/providers'],
                                )) ...[
                                  WatchProvidersSection(
                                    watchProvidersData:
                                        movie['watch/providers']
                                            as Map<String, dynamic>?,
                                    mediaTitle: title,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Divider(
                                    color: Theme.of(context).dividerColor,
                                    height: 1,
                                    thickness: 0.5,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],

                                // Cast Section
                                if (cast.isNotEmpty) ...[
                                  Text(
                                    'CAST & CREW',
                                    style: AppTextStyles.posterHeader.copyWith(
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Skeletonizer(
                                    enabled: isCastLoading,
                                    child: SizedBox(
                                      height: 180,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: cast.length,
                                        separatorBuilder: (context, index) =>
                                            AppSpacing.gapW12,
                                        itemBuilder: (context, index) {
                                          final actor =
                                              cast[index] as Map<String, dynamic>;
                                          final actorName =
                                              actor['name'] as String? ?? '';
                                          final character =
                                              actor['character'] as String? ?? '';
                                          final profilePath =
                                              actor['profile_path'] as String?;
                                          final personId =
                                              (actor['id'] as num?)?.toInt() ?? 0;
                                          final isCrew =
                                              actor['is_crew'] as bool? ?? false;
                                          return _buildCastCard(
                                            personId: personId,
                                            imageUrl: _getImageUrl(
                                              profilePath,
                                              size: 'w185',
                                            ),
                                            realName: actorName,
                                            characterName: character
                                                .toUpperCase(),
                                            profilePath: profilePath,
                                            isCrew: isCrew,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],

                                // Franchise Collection Parts
                                if (!widget.fromRecommendation &&
                                    visibleCollectionParts.isNotEmpty) ...[
                                  Divider(
                                    color: Theme.of(context).dividerColor,
                                    height: 1,
                                    thickness: 0.5,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    collectionSectionTitle,
                                    style: AppTextStyles.lg.copyWith(
                                      color: context.textPrimary,
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
                                        final data = _parseRecommendationData(
                                          visibleCollectionParts[index],
                                        );
                                        if (data == null) {
                                          return const SizedBox.shrink();
                                        }

                                        return _buildRecommendationCard(
                                          movieId: data.id,
                                          posterPath: data.posterPath,
                                          title: data.title,
                                          releaseDate: data.releaseDate,
                                          voteAverage: data.voteAverage,
                                          backdropPath: data.backdropPath,
                                          runtime: 0,
                                          genres: '',
                                          isAdded: watchlistedIds.contains(
                                            data.id,
                                          ),
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
                                  Divider(
                                    color: Theme.of(context).dividerColor,
                                    height: 1,
                                    thickness: 0.5,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    'MORE LIKE THIS',
                                    style: AppTextStyles.posterHeader.copyWith(
                                      color: context.textPrimary,
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
                                        final String? recDate =
                                            rec['release_date'];
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
                                          isAdded: watchlistedIds.contains(
                                            recId,
                                          ),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: AppColors.textOnPrimary,
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

  String _formatVoteCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K ratings';
    }
    return '$count ratings';
  }

  Widget _buildCastCard({
    required int personId,
    required String imageUrl,
    required String realName,
    required String characterName,
    String? profilePath,
    bool isCrew = false,
  }) {
    return GestureDetector(
      onTap: personId > 0
          ? () => PersonDetailsBottomSheet.show(
                context,
                personId: personId,
                initialName: realName,
                initialProfilePath: profilePath,
              )
          : null,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: context.adaptiveColor(
            light: AppColors.lightSurfaceElevated,
            dark: AppColors.surface,
          ),
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
                color: context.adaptiveColor(
                  light: AppColors.lightSurfaceElevated,
                  dark: AppColors.surfaceElevated,
                ),
                child: Center(
                  child: Icon(
                    Icons.person,
                    color: context.adaptiveColor(
                      light: AppColors.lightTextTertiary,
                      dark: AppColors.textTertiary,
                    ),
                    size: 40,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 120,
              height: 180,
              color: context.adaptiveColor(
                light: AppColors.lightSurfaceElevated,
                dark: AppColors.surfaceElevated,
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  color: context.adaptiveColor(
                    light: AppColors.lightTextTertiary,
                    dark: AppColors.textTertiary,
                  ),
                  size: 40,
                ),
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
                  style: AppTextStyles.xsBold.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  characterName,
                  style: AppTextStyles.xs.copyWith(
                    color: isCrew ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isCrew ? FontWeight.w600 : FontWeight.normal,
                  ),
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

  _RecommendationData? _parseRecommendationData(dynamic item) {
    if (item is! Map<String, dynamic>) return null;
    final rawId = item['id'];
    int? id;
    if (rawId is num) {
      id = rawId.toInt();
    } else if (rawId is String) {
      id = int.tryParse(rawId);
    }
    if (id == null) return null;

    return _RecommendationData(
      id: id,
      title: item['title'] ?? item['name'] ?? 'Unknown',
      posterPath: item['poster_path'] as String?,
      backdropPath: item['backdrop_path'] as String?,
      releaseDate:
          item['release_date'] ?? item['first_air_date'] as String? ?? '',
      voteAverage: (item['vote_average'] as num?)?.toDouble() ?? 0.0,
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
    final year = (releaseDate != null && releaseDate.isNotEmpty)
        ? releaseDate.split('-')[0]
        : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsPage(
              movieId: movieId,
              title: title,
              posterPath: posterPath,
              backdropPath: backdropPath,
              fromRecommendation: true,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: posterPath != null && posterPath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _getImageUrl(posterPath, size: 'w342'),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppColors.lightSurfaceElevated
                                  : AppColors.surfaceLight,
                              child: const Center(
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppColors.lightSurfaceElevated
                                  : AppColors.surfaceLight,
                              child: Icon(
                                Icons.broken_image,
                                color: context.adaptiveColor(
                                  light: AppColors.lightTextTertiary,
                                  dark: AppColors.textTertiary,
                                ),
                                size: 30,
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(context).brightness ==
                                    Brightness.light
                                ? AppColors.lightSurfaceElevated
                                : AppColors.surfaceLight,
                            child: Icon(
                              Icons.movie,
                              color: context.adaptiveColor(
                                light: AppColors.lightTextTertiary,
                                dark: AppColors.textTertiary,
                              ),
                              size: 30,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapH8,
            // Movie Title
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.xsBold.copyWith(
                color: context.textPrimary,
              ),
            ),
            AppSpacing.gapH4,
            // Rating & Year Row
            Row(
              children: [
                if (voteAverage > 0.0) ...[
                  const Icon(Icons.star, color: AppColors.primary, size: 10.0),
                  AppSpacing.gapW4,
                  Text(
                    voteAverage.toStringAsFixed(1),
                    style: AppTextStyles.xs.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  if (year.isNotEmpty) ...[
                    AppSpacing.gapW4,
                    Text(
                      '•',
                      style: AppTextStyles.xs.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                    AppSpacing.gapW4,
                    Text(
                      year,
                      style: AppTextStyles.xs.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ] else if (year.isNotEmpty) ...[
                  Text(
                    year,
                    style: AppTextStyles.xs.copyWith(
                      color: context.textSecondary,
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

class _RecommendationData {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;

  const _RecommendationData({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    required this.voteAverage,
  });
}
