import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/action_circle_button.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_confirm_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/collapsing_header_snap.dart';
import '../../../../core/widgets/media_hero_image.dart';
import '../../../../core/widgets/watch_trailer_button.dart';
import '../../../../core/widgets/watch_providers_section.dart';
import '../../../../core/utils/tmdb_artwork.dart';
import '../../../../core/widgets/polaroid_share_modal.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/auth_required_view.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../cubit/show_details_cubit.dart';
import '../cubit/show_details_state.dart';
import '../widgets/tv_status_badge.dart';
import '../../../person/presentation/widgets/person_details_bottom_sheet.dart';
import '../../../custom_lists/domain/models/custom_list_item_model.dart';
import '../../../custom_lists/presentation/widgets/add_to_list_bottom_sheet.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

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
  static const double _heroExpandedHeight = 300.0;

  late final ScrollController _scrollController;
  final ValueNotifier<bool> _isCollapsed = ValueNotifier<bool>(false);
  final Map<int, bool> _expandedSeasons = {};
  final Map<int, ExpansibleController> _controllers = {};
  final Set<String> _loadingEpisodeKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.hasClients) {
          // Title shows as the header finishes collapsing, on every device.
          final isCurrentlyCollapsed = _scrollController.offset >=
              CollapsingHeaderSnap.collapseExtentOf(
                    context,
                    _heroExpandedHeight,
                  ) -
                  8;
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
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _scrollController.dispose();
    _isCollapsed.dispose();
    super.dispose();
  }

  String _getImageUrl(String? path, {String size = 'w500'}) {
    return AppConstants.tmdbImageUrl(path ?? '', size: size);
  }

  String _getYear(String? dateStr) {
    if (dateStr == null || dateStr.length < 4) return '';
    return dateStr.substring(0, 4);
  }

  String _getGenresString(dynamic genresList) {
    if (genresList == null || genresList is! List) return '';
    return genresList.map((g) => g['name']).join(', ');
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBA';
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatVoteCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K ratings';
    }
    return '$count ratings';
  }

  void _showMoreActions({
    required BuildContext context,
    required String uid,
    required bool isTracked,
    required bool isStopped,
    required String title,
    required String? posterPath,
    required String? backdropPath,
    required String? firstAirDate,
    required double? rating,
    bool hasLoadedDetails = true,
  }) {
    AppActionSheet.show(
      context,
      title: 'Show Actions',
      actions: [
        if (hasLoadedDetails)
          AppActionSheetAction(
            label: 'Add to List',
            subtitle: 'Save to your custom collections',
            icon: Icons.playlist_add_rounded,
            iconColor: context.primary,
            onTap: () {
              AddToListBottomSheet.show(
                context,
                item: CustomListItemModel(
                  id: widget.mediaId,
                  mediaType: widget.mediaType,
                  title: title,
                  posterPath: posterPath,
                  backdropPath: backdropPath,
                  voteAverage: rating ?? 0.0,
                  releaseDate: firstAirDate,
                  addedAt: DateTime.now(),
                ),
              );
            },
          ),
        if (isTracked)
          AppActionSheetAction(
            label: isStopped ? 'Resume Watching' : 'Pause Watching',
            subtitle: isStopped
                ? 'Continue tracking new episodes'
                : 'Put tracking on hold',
            icon: isStopped
                ? Icons.play_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            iconColor: isStopped ? AppColors.brandGreen : AppColors.accentBlue,
            onTap: () {
              AppHaptics.mediumImpact();
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
          ),
        if (isTracked)
          AppActionSheetAction(
            label: 'Remove from Watchlist',
            subtitle: 'Remove from your tracked shows',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onTap: () {
              AppHaptics.mediumImpact();
              context.read<TvShowWatchlistCubit>().removeShow(
                uid: uid,
                showId: widget.mediaId,
              );
            },
          ),
      ],
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
        {'name': 'Network'},
      ],
      'genres': [
        {'name': 'Drama'},
        {'name': 'Action'},
      ],
      'seasons': [
        {'season_number': 1, 'name': 'Season 1', 'episode_count': 10},
      ],
      'created_by': [
        {
          'id': 10001,
          'name': 'Creator Name',
          'profile_path': null,
        },
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
        final bool isCastLoading =
            state is ShowDetailsSuccess && state.isCastLoading;
        final bool isSimilarLoading =
            state is ShowDetailsSuccess && state.isSimilarLoading;
        final String? error = state is ShowDetailsError ? state.message : null;

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
                      style: AppTextStyles.md.copyWith(
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapH32,
                    ElevatedButton(
                      onPressed: () => context
                          .read<ShowDetailsCubit>()
                          .loadDetails(widget.mediaId, widget.mediaType),
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

        final details = isLoading
            ? _dummyShowDetails()
            : (state as ShowDetailsSuccess).details;
        final seasonsData = isLoading
            ? <int, List<dynamic>>{}
            : (state as ShowDetailsSuccess).seasonsData;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              Skeletonizer(
                enabled: isLoading,
                child: _buildDetailsView(
                  context,
                  details,
                  seasonsData,
                  isLoading: isLoading,
                  isCastLoading: isCastLoading,
                  isSimilarLoading: isSimilarLoading,
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
  }

  Widget _buildDetailsView(
    BuildContext context,
    Map<String, dynamic> rawDetailsData,
    Map<int, List<dynamic>> seasonsData, {
    bool isLoading = false,
    bool isCastLoading = false,
    bool isSimilarLoading = false,
  }) {
    final Map<String, dynamic> details = isLoading
        ? _dummyShowDetails()
        : Map<String, dynamic>.from(rawDetailsData);

    if (isCastLoading && !isLoading) {
      details['credits'] = _dummyShowDetails()['credits'];
    }
    if (isSimilarLoading && !isLoading) {
      details['similar'] = _dummyShowDetails()['similar'];
    }

    final String title = details['name'] ?? details['title'] ?? widget.title;
    final String? backdropPath = details['backdrop_path'];
    final String? posterPath = details['poster_path'];
    final String? firstAirDate =
        details['first_air_date'] ?? details['release_date'];
    final String tagline = (details['tagline'] as String? ?? '').trim();
    final String overview = details['overview'] ?? '';
    final double voteAverage =
        (details['vote_average'] as num?)?.toDouble() ?? 0.0;
    final int voteCount = (details['vote_count'] as num?)?.toInt() ?? 0;

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

    // Creators / Directors extraction
    final bool isMovie = widget.mediaType == 'movie';
    final List<Map<String, dynamic>> creatorsOrDirectors = [];
    final Set<int> seenCreatorIds = {};

    if (!isMovie) {
      final createdByList = details['created_by'] as List<dynamic>? ?? [];
      for (final item in createdByList) {
        if (item is Map<String, dynamic>) {
          final id = (item['id'] as num?)?.toInt();
          if (id != null && seenCreatorIds.add(id)) {
            creatorsOrDirectors.add({
              'id': id,
              'name': item['name'] as String? ?? '',
              'profile_path': item['profile_path'] as String?,
              'role': 'CREATOR',
            });
          }
        }
      }
    }

    if (creatorsOrDirectors.isEmpty && details['credits'] != null) {
      final crew = details['credits']['crew'] as List<dynamic>? ?? [];
      for (final item in crew) {
        if (item is Map<String, dynamic>) {
          final job = item['job'] as String? ?? '';
          final isTarget = isMovie
              ? (job == 'Director')
              : (job == 'Creator' || job == 'Director');
          if (isTarget) {
            final id = (item['id'] as num?)?.toInt();
            if (id != null && seenCreatorIds.add(id)) {
              creatorsOrDirectors.add({
                'id': id,
                'name': item['name'] as String? ?? '',
                'profile_path': item['profile_path'] as String?,
                'role': isMovie
                    ? 'DIRECTOR'
                    : (job == 'Creator' ? 'CREATOR' : 'DIRECTOR'),
              });
            }
          }
        }
      }
    }

    final rawCastList =
        (details['credits'] != null && details['credits']['cast'] is List)
            ? (details['credits']['cast'] as List).take(10).toList()
            : <dynamic>[];

    final creatorCards = creatorsOrDirectors.map((c) => {
      'id': c['id'],
      'name': c['name'],
      'character': c['role'] ?? (isMovie ? 'DIRECTOR' : 'CREATOR'),
      'profile_path': c['profile_path'],
      'is_crew': true,
    }).toList();

    final combinedCredits = [
      ...creatorCards,
      ...rawCastList,
    ];

    Widget buildSliverAppBar() {
      return SliverAppBar(
        automaticallyImplyLeading: false,
        leading: const SizedBox.shrink(),
        expandedHeight: _heroExpandedHeight,
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
                style: AppTextStyles.mdBold,
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
                onPressed: isLoading
                    ? null
                    : () {
                        final images =
                            details['images'] as Map<String, dynamic>?;
                        final shareImageUrl = _getImageUrl(
                          TmdbArtwork.bestSharePath(images) ??
                              backdropPath ??
                              posterPath,
                          size: 'w780',
                        );
                        PolaroidShareModal.show(
                          context,
                          title: title,
                          imageUrl: shareImageUrl,
                          rating: voteAverage,
                          mediaType: widget.mediaType,
                          tmdbId: widget.mediaId,
                          images: images,
                        );
                      },
              ),
            ),
          ),
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
                  if (uid != null) {
                    return Padding(
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
                            _showMoreActions(
                              context: context,
                              uid: uid,
                              isTracked: isTracked,
                              isStopped: isStopped,
                              title: title,
                              posterPath: posterPath,
                              backdropPath: backdropPath,
                              firstAirDate: firstAirDate,
                              rating: voteAverage,
                              hasLoadedDetails: !isLoading,
                            );
                          },
                        ),
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
              MediaHeroImage(
                backdropPath: TmdbArtwork.bestBannerPath(
                      details['images'] as Map<String, dynamic>?,
                    ) ??
                    backdropPath,
                posterPath: posterPath,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.4, 1.0],
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
                            style: AppTextStyles.xxl.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            widget.mediaType == 'tv'
                                ? () {
                                    final parts = <String>[
                                      if (numberOfSeasons > 0)
                                        '$numberOfSeasons season${numberOfSeasons == 1 ? '' : 's'}',
                                      if (networkName.isNotEmpty) networkName,
                                    ];
                                    if (parts.isEmpty) {
                                      final year = _getYear(
                                        details['first_air_date'],
                                      );
                                      if (year.isNotEmpty) parts.add(year);
                                    }
                                    return parts.join(' • ');
                                  }()
                                : _getYear(details['release_date']),
                            style: AppTextStyles.sm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.mediaType == 'tv' &&
                              status.trim().isNotEmpty) ...[
                            const SizedBox(height: 8.0),
                            TvStatusBadge(status: status, isHero: true),
                          ],
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
                        final uid = authState is Authenticated
                            ? authState.user.uid
                            : null;

                        if (uid == null) {
                          return const SizedBox.shrink();
                        }

                        return ActionCircleButton(
                          isActive: isFavorite,
                          onTap: () {
                            AppHaptics.mediumImpact();
                            if (isAdded) {
                              context
                                  .read<TvShowWatchlistCubit>()
                                  .toggleFavorite(
                                    uid: uid,
                                    showId: widget.mediaId,
                                    isFavorite: !isFavorite,
                                  );
                            } else {
                              AppSnackbar.showInfo(
                                context,
                                widget.mediaType == 'movie'
                                    ? 'Add movie to watchlist first'
                                    : 'Track show first',
                              );
                            }
                          },
                          activeIcon: Icons.favorite,
                          inactiveIcon: Icons.favorite_border,
                          activeIconColor: AppColors.error,
                          inactiveIconColor: AppColors.textOnPrimary,
                          activeBgColor:
                              AppColors.surfaceElevated.withValues(alpha: 0.6),
                          inactiveBgColor:
                              AppColors.surfaceElevated.withValues(alpha: 0.6),
                          size: 28.0,
                          iconSize: 16.0,
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
      final bool hasCreators = creatorsOrDirectors.any(
        (c) => c['role'] == 'CREATOR',
      );
      final bool hasDirectors = creatorsOrDirectors.any(
        (c) => c['role'] == 'DIRECTOR',
      );
      final String creatorsOrDirectorsLabel;
      if (hasCreators && hasDirectors) {
        creatorsOrDirectorsLabel = 'Creators / Directors';
      } else if (hasDirectors) {
        final directorCount = creatorsOrDirectors
            .where((c) => c['role'] == 'DIRECTOR')
            .length;
        creatorsOrDirectorsLabel = directorCount > 1 ? 'Directors' : 'Director';
      } else {
        creatorsOrDirectorsLabel = 'Created by';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoading)
              AppSpacing.gapH24
            else
              Row(children: [Expanded(child: _buildTrackButton(details))]),
            Text(
              'Show info',
              style: AppTextStyles.mdBold,
            ),
            AppSpacing.gapH4,
            Text(
              '${_getYear(details['first_air_date'] ?? details['release_date'])} • ${_getGenresString(details['genres'])}',
              style: AppTextStyles.sm.copyWith(
                color: context.textSecondary,
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
                  AppSpacing.gapW8,
                  Text(
                    'Language: $language',
                    style: AppTextStyles.sm.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (creatorsOrDirectors.isNotEmpty) ...[
              AppSpacing.gapH4,
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    isMovie
                        ? Icons.movie_creation_outlined
                        : Icons.tv_outlined,
                    color: Theme.of(context).disabledColor,
                    size: 14,
                  ),
                  AppSpacing.gapW8,
                  Text(
                    '$creatorsOrDirectorsLabel: ',
                    style: AppTextStyles.sm.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0;
                              i < creatorsOrDirectors.length;
                              i++) ...[
                            if (i > 0)
                              Text(
                                ', ',
                                style: AppTextStyles.sm.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                            GestureDetector(
                              onTap: () {
                                final id =
                                    (creatorsOrDirectors[i]['id'] as num?)
                                        ?.toInt() ??
                                    0;
                                if (id > 0) {
                                  PersonDetailsBottomSheet.show(
                                    context,
                                    personId: id,
                                    initialName:
                                        creatorsOrDirectors[i]['name']
                                            as String?,
                                    initialProfilePath:
                                        creatorsOrDirectors[i]['profile_path']
                                            as String?,
                                  );
                                }
                              },
                              child: Text(
                                creatorsOrDirectors[i]['name'] as String? ?? '',
                                style: AppTextStyles.smMedium.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary
                                      .withValues(alpha: 0.5),
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
            AppSpacing.gapH12,
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.primary, size: 16),
                AppSpacing.gapW4,
                Text(
                  '${voteAverage.toStringAsFixed(1)} / 10',
                  style: AppTextStyles.smBold,
                ),
                if (voteCount > 0) ...[
                  AppSpacing.gapW8,
                  Text(
                    '(${_formatVoteCount(voteCount)})',
                    style: AppTextStyles.sm.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
            if (tagline.isNotEmpty) ...[
              AppSpacing.gapH8,
              Text(
                '“$tagline”',
                style: AppTextStyles.editorialTagline.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                ),
              ),
            ],
            AppSpacing.gapH12,
            Text(
              overview.isNotEmpty ? overview : 'No overview available.',
              style: AppTextStyles.sm.copyWith(height: 1.4),
            ),
            AppSpacing.gapH24,
            if (trailer != null) ...[
              WatchTrailerButton(
                trailer: trailer,
                allTrailers: youtubeTrailers,
              ),
              AppSpacing.gapH24,
            ],

            if (WatchProvidersSection.hasProviders(
              details['watch/providers'],
            )) ...[
              const Divider(height: 1, thickness: 0.5),
              AppSpacing.gapH24,
              WatchProvidersSection(
                watchProvidersData:
                    details['watch/providers'] as Map<String, dynamic>?,
                mediaTitle: title,
              ),
              AppSpacing.gapH24,
            ],

            if (combinedCredits.isNotEmpty) ...[
              const Divider(height: 1, thickness: 0.5),
              AppSpacing.gapH24,
              Text(
                'CAST & CREW',
                style: AppTextStyles.posterHeader.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              AppSpacing.gapH16,
              Skeletonizer(
                enabled: isCastLoading || isLoading,
                child: SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: combinedCredits.length,
                    separatorBuilder: (context, index) => AppSpacing.gapW12,
                    itemBuilder: (context, index) {
                      final member =
                          combinedCredits[index] as Map<String, dynamic>;
                      final memberName = member['name'] as String? ?? 'Unknown';
                      final character = member['character'] as String? ?? '';
                      final profilePath = member['profile_path'] as String?;
                      final isCrew = member['is_crew'] as bool? ?? false;
                      return _buildCastCard(
                        personId: (member['id'] as num?)?.toInt() ?? 0,
                        imageUrl: _getImageUrl(profilePath, size: 'w185'),
                        realName: memberName,
                        characterName: character.toUpperCase(),
                        profilePath: profilePath,
                        isCrew: isCrew,
                      );
                    },
                  ),
                ),
              ),
              AppSpacing.gapH24,
            ],

            if (details['similar'] != null &&
                details['similar']['results'] != null &&
                (details['similar']['results'] as List).isNotEmpty) ...[
              const Divider(height: 1, thickness: 0.5),
              AppSpacing.gapH24,
              Text(
                'MORE LIKE THIS',
                style: AppTextStyles.posterHeader.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              AppSpacing.gapH16,
              BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
                builder: (context, watchState) {
                  final Set<int> trackedShowIds = {};
                  if (watchState is TvShowWatchlistSuccess) {
                    for (final s in watchState.shows) {
                      final rawId = s['id'];
                      if (rawId is num) {
                        trackedShowIds.add(rawId.toInt());
                      } else if (rawId is String) {
                        final parsed = int.tryParse(rawId);
                        if (parsed != null) trackedShowIds.add(parsed);
                      }
                    }
                  }

                  return Skeletonizer(
                    enabled: isSimilarLoading || isLoading,
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: (details['similar']['results'] as List)
                            .take(10)
                            .length,
                        separatorBuilder: (context, index) => AppSpacing.gapW12,
                        itemBuilder: (context, index) {
                          final similar =
                              (details['similar']['results'] as List)
                                  .take(10)
                                  .toList();
                          final item = similar[index] as Map<String, dynamic>;
                          final posterPath = item['poster_path'] as String?;
                          final rawId = item['id'];
                          int? simId;
                          if (rawId is num) {
                            simId = rawId.toInt();
                          } else if (rawId is String) {
                            simId = int.tryParse(rawId);
                          }
                          final isAdded =
                              simId != null && trackedShowIds.contains(simId);

                          return GestureDetector(
                            onTap: () {
                              AppHaptics.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BlocProvider<ShowDetailsCubit>(
                                        create: (context) => ShowDetailsCubit(
                                          tmdbClient: context
                                              .read<TmdbClient>(),
                                        ),
                                        child: ShowDetailsPage(
                                          mediaId: (item['id'] as num).toInt(),
                                          title: item['name'] ?? 'Unknown',
                                          mediaType: 'tv',
                                        ),
                                      ),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 130,
                              height: 200,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child:
                                          posterPath != null &&
                                              posterPath.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: _getImageUrl(
                                                posterPath,
                                              ),
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    color: context
                                                        .adaptiveColor(
                                                          light: AppColors
                                                              .lightSurfaceElevated,
                                                          dark: AppColors
                                                              .surfaceLight,
                                                        ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    error,
                                                  ) => Container(
                                                    color: context
                                                        .adaptiveColor(
                                                          light: AppColors
                                                              .lightSurfaceElevated,
                                                          dark: AppColors
                                                              .surfaceLight,
                                                        ),
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.movie_outlined,
                                                        color: context
                                                            .adaptiveColor(
                                                              light: AppColors
                                                                  .lightTextTertiary,
                                                              dark: AppColors
                                                                  .textTertiary,
                                                            ),
                                                        size: 40,
                                                      ),
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              color: context.adaptiveColor(
                                                light: AppColors
                                                    .lightSurfaceElevated,
                                                dark: AppColors.surfaceLight,
                                              ),
                                              padding: const EdgeInsets.all(
                                                AppSpacing.xs,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.movie_outlined,
                                                    color: context
                                                        .adaptiveColor(
                                                          light: AppColors
                                                              .lightTextTertiary,
                                                          dark: AppColors
                                                              .textTertiary,
                                                        ),
                                                    size: 40,
                                                  ),
                                                  AppSpacing.gapH8,
                                                  Text(
                                                    item['name'] ?? '',
                                                    style: AppTextStyles.xs.copyWith(
                                                      color: context.adaptiveColor(
                                                        light: AppColors
                                                            .lightTextSecondary,
                                                        dark: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                    maxLines: 2,
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    if (isAdded)
                                      Positioned(
                                        top: -10,
                                        right: -5,
                                        child: Container(
                                          color: Colors.transparent,
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                            right: 4,
                                            bottom: 8,
                                            top: 0,
                                          ),
                                          child: const Icon(
                                            Icons.bookmark_sharp,
                                            color: AppColors.primary,
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
                                    if (item['vote_average'] != null &&
                                        (item['vote_average'] as num) > 0)
                                      Positioned(
                                        top: 8,
                                        right: isAdded ? 36 : 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                            vertical: AppSpacing.micro,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.7,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: AppColors.gold,
                                                size: 12,
                                              ),
                                              AppSpacing.gapW4,
                                              Text(
                                                (item['vote_average'] as num)
                                                    .toStringAsFixed(1),
                                                style: AppTextStyles.xsBold.copyWith(
                                                  color: AppColors.textOnPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
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
            AppSpacing.gapH24,
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

    if (widget.mediaType == 'movie') {
      return CollapsingHeaderSnap(
        controller: _scrollController,
        expandedHeight: _heroExpandedHeight,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            buildSliverAppBar(),
            SliverToBoxAdapter(child: buildAboutSection()),
            CollapsingHeaderSnap.fullCollapseFiller(
              expandedHeight: _heroExpandedHeight,
            ),
          ],
        ),
      );
    } else {
      return DefaultTabController(
        length: 2,
        initialIndex: widget.initialTabIndex,
        child: CollapsingHeaderSnap(
         controller: _scrollController,
         expandedHeight: _heroExpandedHeight,
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

      final epCount = (season['episode_count'] as num?)?.toInt() ?? 0;
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
          return _trackButtonUI(
            isTracked: false,
            onPressed: () {
              AuthRequiredBottomSheet.show(
                context,
                title: widget.mediaType == 'movie'
                    ? 'Sign in to Track Movies'
                    : 'Sign in to Track Shows',
                subtitle: widget.mediaType == 'movie'
                    ? 'Sign in to add movies to your personal watchlist.'
                    : 'Sign in to track shows and episodes.',
                icon: widget.mediaType == 'movie'
                    ? Icons.movie_filter_rounded
                    : Icons.tv_rounded,
              );
            },
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
    if (isTracked) return AppSpacing.gapH24;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        ),
        child: Text(
          widget.mediaType == 'movie' ? 'Add to Watchlist' : 'Track Show',
        ),
      ),
    );
  }

  Widget _buildSeasonsAccordion(
    List<dynamic> seasons,
    Map<int, List<dynamic>> seasonsData,
    Map<String, dynamic> showDetails,
  ) {
    return PageStorage(
      bucket: PageStorageBucket(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(seasons.length, (index) {
          final season = seasons[index];
          final int seasonNumber =
              (season['season_number'] as num?)?.toInt() ?? 1;
          final String name = 'Season $seasonNumber';
          final int epCount = (season['episode_count'] as num?)?.toInt() ?? 0;

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
                        (showDetails['number_of_seasons'] as num?)?.toInt() ??
                        0;
                    if (seasonNumber < totalSeasons) {
                      for (int i = 1; i <= epCount; i++) {
                        releasedEpisodesKeys.add('$seasonNumber-$i');
                      }
                    } else {
                      final episodesForSeason = seasonsData[seasonNumber];
                      if (episodesForSeason != null &&
                          episodesForSeason.isNotEmpty) {
                        for (var ep in episodesForSeason) {
                          if (ep is! Map) continue;
                          final epNum =
                              (ep['episode_number'] as num?)?.toInt() ?? 0;
                          if (epNum > 0) {
                            final airDateStr = ep['air_date'] as String?;
                            if (airDateStr != null && airDateStr.isNotEmpty) {
                              final airDate = DateTime.tryParse(airDateStr);
                              if (airDate != null) {
                                final now = DateTime.now();
                                final today = DateTime.utc(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                final targetDate = DateTime.utc(
                                  airDate.year,
                                  airDate.month,
                                  airDate.day,
                                );
                                if (!targetDate.isAfter(today)) {
                                  releasedEpisodesKeys.add(
                                    '$seasonNumber-$epNum',
                                  );
                                }
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
                  final bool allWatched =
                      epCount > 0 && watchedCount >= epCount;

                  final controller = _controllers.putIfAbsent(
                    seasonNumber,
                    () => ExpansibleController(),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: (_expandedSeasons[seasonNumber] ?? false)
                          ? Colors.transparent
                          : context.adaptiveColor(
                              light: AppColors.lightSurface,
                              dark: AppColors.surface,
                            ),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          context.isLight &&
                              !(_expandedSeasons[seasonNumber] ?? false)
                          ? Border.all(color: AppColors.borderLight)
                          : null,
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        ExpansionTile(
                          controller: controller,
                          initiallyExpanded:
                              _expandedSeasons[seasonNumber] ?? false,
                          key: ValueKey<String>(
                            'season_${widget.mediaId}_$seasonNumber',
                          ),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          childrenPadding: EdgeInsets.zero,
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
                                style: AppTextStyles.mdBold.copyWith(
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                (_expandedSeasons[seasonNumber] ?? false)
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: context.textPrimary,
                                size: 20,
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$watchedCount/$epCount',
                                style: AppTextStyles.sm.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                              if (isTracked && hasAnyReleased) ...[
                                AppSpacing.gapW12,
                                GestureDetector(
                                  onTap: () {
                                    AppHaptics.lightImpact();
                                    if (authState is! Authenticated) {
                                      AuthRequiredBottomSheet.show(
                                        context,
                                        title: 'Sign in to Track Episodes',
                                        subtitle:
                                            'Keep track of episodes you have watched and see your progress.',
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                      );
                                      return;
                                    }
                                    if (!isTracked) {
                                      AppSnackbar.showInfo(
                                        context,
                                        'Track show first',
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
                                          ? AppColors.brandGreen
                                          : context.adaptiveColor(
                                              light: AppColors.borderLight,
                                              dark: AppColors.borderDark,
                                            ),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 20,
                                      color: allReleasedWatched
                                          ? AppColors.textOnPrimary
                                          : context.adaptiveColor(
                                              light: AppColors.lightTextSecondary,
                                              dark: AppColors.textSecondary,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _expandedSeasons[seasonNumber] = expanded;
                              if (expanded) {
                                for (var entry in _controllers.entries) {
                                  if (entry.key != seasonNumber) {
                                    _expandedSeasons[entry.key] = false;
                                  }
                                }
                              }
                            });
                            if (expanded) {
                              // Collapse all other expanded tiles
                              for (var entry in _controllers.entries) {
                                if (entry.key != seasonNumber) {
                                  try {
                                    if (entry.value.isExpanded) {
                                      entry.value.collapse();
                                    }
                                  } catch (_) {}
                                }
                              }

                              context
                                  .read<ShowDetailsCubit>()
                                  .loadSeasonEpisodes(
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
                                            ? AppColors.success
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
      ),
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
    AppBottomSheet.show(
      context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stillPath != null && stillPath.isNotEmpty)
                ClipRRect(
                  borderRadius: AppBottomSheet.borderRadius,
                  child: CachedNetworkImage(
                    imageUrl: _getImageUrl(stillPath, size: 'w780'),
                    fit: BoxFit.cover,
                    height: 220,
                    width: double.infinity,
                    errorWidget: (context, url, error) => SizedBox(
                      height: 220,
                      child: Icon(
                        Icons.tv,
                        size: 50,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 100,
                  child: Icon(Icons.tv, size: 50, color: context.textTertiary),
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
                                style: AppTextStyles.mdBold.copyWith(
                                  color: context.textPrimary,
                                ),
                                maxLines: 2,
                              ),
                              if (voteCount > 0) ...[
                                AppSpacing.gapH4,
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: AppColors.gold,
                                      size: 16,
                                    ),
                                    AppSpacing.gapW4,
                                    Text(
                                      '${voteAverage.toStringAsFixed(1)}/10 ($voteCount)',
                                      style: AppTextStyles.smMedium.copyWith(
                                        color: context.textTertiary,
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
                          style: AppTextStyles.sm.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH16,
                    if (overview.isNotEmpty)
                      Text(
                        overview,
                        style: AppTextStyles.sm.copyWith(
                          color: context.textSecondary,
                          height: 1.5,
                        ),
                      )
                    else
                      Text(
                        'No description available.',
                        style: AppTextStyles.sm.copyWith(
                          color: context.textTertiary,
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
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'No episodes listed for this season.',
          style: AppTextStyles.sm.copyWith(color: context.textTertiary),
        ),
      );
    }

    return ListView.builder(
      key: ValueKey('episodes_list_$seasonNumber'),
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final ep = episodes[index];
        final int epNum =
            (ep['episode_number'] as num?)?.toInt() ?? (index + 1);
        final String name = ep['name'] ?? 'Episode $epNum';
        String airDate = ep['air_date'] ?? 'No Air Date';
        bool isReleased = false;
        int? daysUntilRelease;

        if (airDate != 'No Air Date' && airDate.isNotEmpty) {
          try {
            final date = DateTime.parse(airDate);
            final now = DateTime.now();
            final today = DateTime.utc(now.year, now.month, now.day);
            final targetDate = DateTime.utc(date.year, date.month, date.day);
            isReleased = !targetDate.isAfter(today);
            if (!isReleased) {
              daysUntilRelease = targetDate.difference(today).inDays;
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
        final int voteCount = (ep['vote_count'] as num?)?.toInt() ?? 0;
        final String episodeKey = '$seasonNumber-$epNum';

        // Format season/episode as S01 | E02
        final String seasonLabel =
            'S${seasonNumber.toString().padLeft(2, '0')}';
        final String episodeLabel = 'E${epNum.toString().padLeft(2, '0')}';

        return Container(
          margin: const EdgeInsets.only(left: AppSpacing.micro, right: AppSpacing.micro, bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            color: context.adaptiveColor(
              light: AppColors.lightSurface,
              dark: AppColors.surfaceDarkAlt,
            ),
            borderRadius: BorderRadius.circular(8.0),
            border: context.isLight
                ? Border.all(color: AppColors.borderLight)
                : null,
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
                  color: context.adaptiveColor(
                    light: AppColors.lightSurfaceElevated,
                    dark: AppColors.surfaceLight,
                  ),
                  child: stillPath != null && stillPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _getImageUrl(stillPath, size: 'w300'),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: context.adaptiveColor(
                              light: AppColors.lightSurfaceElevated,
                              dark: AppColors.surfaceLight,
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.tv,
                              size: 24,
                              color: context.textTertiary,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.tv,
                            size: 24,
                            color: context.textTertiary,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Episode info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$seasonLabel | $episodeLabel',
                        style: AppTextStyles.smBold.copyWith(
                          color: context.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      AppSpacing.gapH4,
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sm.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                      AppSpacing.gapH4,
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 11,
                            color: context.textTertiary,
                          ),
                          AppSpacing.gapW4,
                          Text(
                            airDate,
                            style: AppTextStyles.xs.copyWith(
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
                        builder: (context, watchState) {
                          bool isWatched = false;
                          String? watchedAtStr;
                          if (watchState is TvShowWatchlistSuccess) {
                            try {
                              final showDoc = watchState.shows.firstWhere(
                                (s) => s['id'] == widget.mediaId,
                              );
                              if (showDoc['watchedEpisodes'] != null) {
                                final watchedEpisodes = List<String>.from(
                                  showDoc['watchedEpisodes'],
                                );
                                isWatched = watchedEpisodes.contains(
                                  episodeKey,
                                );

                                // Try to get exact episode watched date
                                if (isWatched &&
                                    showDoc.containsKey(
                                      'episodeWatchedDates',
                                    )) {
                                  final datesMap =
                                      showDoc['episodeWatchedDates']
                                          as Map<String, dynamic>?;
                                  if (datesMap != null &&
                                      datesMap.containsKey(episodeKey)) {
                                    watchedAtStr =
                                        datesMap[episodeKey] as String?;
                                  }
                                }
                              }
                              // Fallback to show-level date if episode date is not available
                              watchedAtStr ??=
                                  showDoc['watchedAt'] as String? ??
                                  showDoc['addedAt'] as String?;
                            } catch (e) {
                              // Ignore
                            }
                          }
                          if (!isWatched) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: context.isLight
                                      ? AppColors.brandGreen
                                      : AppColors.success,
                                  size: 11,
                                ),
                                AppSpacing.gapW4,
                                Text(
                                  watchedAtStr != null
                                      ? _formatDate(watchedAtStr)
                                      : 'Watched',
                                  style: AppTextStyles.xsBold.copyWith(
                                    color: context.isLight
                                        ? AppColors.brandGreen
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapW12,
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

                          final isLoadingThisEp = _loadingEpisodeKeys.contains(
                            episodeKey,
                          );

                          return GestureDetector(
                            onTap: () async {
                              if (isLoadingThisEp) return;
                              unawaited(AppHaptics.lightImpact());
                              if (authState is! Authenticated) {
                                unawaited(
                                  AuthRequiredBottomSheet.show(
                                    context,
                                    title: 'Sign in to Track Episodes',
                                    subtitle:
                                        'Keep track of episodes you have watched and see your progress.',
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                );
                                return;
                              }

                              if (!isTracked) {
                                AppSnackbar.showInfo(
                                  context,
                                  'Track show first',
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
                                    Future<void> markJustThisOne() async {
                                      if (!mounted) return;
                                      setState(() {
                                        _loadingEpisodeKeys.add(episodeKey);
                                      });
                                      try {
                                        await cubit.toggleEpisodeWatched(
                                          uid: uid,
                                          showId: widget.mediaId,
                                          episodeKey: episodeKey,
                                          isWatched: true,
                                          showName: details['name']?.toString(),
                                          showPoster:
                                              details['poster_path']?.toString(),
                                          episodeTitle:
                                              ep['name']?.toString() ??
                                              'Episode ${ep['episode_number']}',
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _loadingEpisodeKeys.remove(
                                              episodeKey,
                                            );
                                          });
                                        }
                                      }
                                    }

                                    Future<void> markAll() async {
                                      if (!mounted) return;
                                      final allToMark = [
                                        ...unwatchedPrev,
                                        episodeKey,
                                      ];
                                      setState(() {
                                        _loadingEpisodeKeys.addAll(allToMark);
                                      });
                                      try {
                                        await cubit.markMultipleEpisodesWatched(
                                          uid: uid,
                                          showId: widget.mediaId,
                                          episodeKeys: allToMark,
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _loadingEpisodeKeys.removeAll(
                                              allToMark,
                                            );
                                          });
                                        }
                                      }
                                    }

                                    unawaited(
                                      AppConfirmSheet.show(
                                        context,
                                        icon: Icons.playlist_add_check_rounded,
                                        title: 'Mark Previous Episodes?',
                                        message:
                                            'You have ${unwatchedPrev.length} unwatched previous episodes. Would you like to mark them as watched too?',
                                        confirmLabel: 'Yes, mark all',
                                        cancelLabel: 'No, just this one',
                                        isDestructive: false,
                                        onCancel: markJustThisOne,
                                      ).then((confirmed) {
                                        if (confirmed) markAll();
                                      }),
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

                              setState(() {
                                _loadingEpisodeKeys.add(episodeKey);
                              });

                              try {
                                await cubit.toggleEpisodeWatched(
                                  uid: uid,
                                  showId: widget.mediaId,
                                  episodeKey: episodeKey,
                                  isWatched: !isWatched,
                                  showName: details?['name']?.toString(),
                                  showPoster: details?['poster_path']
                                      ?.toString(),
                                  episodeTitle:
                                      ep['name']?.toString() ??
                                      'Episode ${ep['episode_number']}',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _loadingEpisodeKeys.remove(episodeKey);
                                  });
                                }
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isWatched
                                    ? AppColors.success
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isWatched
                                      ? AppColors.success
                                      : (context.isLight
                                            ? AppColors.lightTextTertiary
                                            : AppColors.textTertiary),
                                  width: 2,
                                ),
                              ),
                              child: isLoadingThisEp
                                  ? const CircularProgressIndicator.adaptive()
                                  : Icon(
                                      Icons.check,
                                      size: 20,
                                      color: isWatched
                                          ? AppColors.textOnPrimary
                                          : (context.isLight
                                                ? AppColors.lightTextTertiary
                                                : AppColors.textTertiary),
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
                        '$daysUntilRelease',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.lg.copyWith(
                          color: context.textPrimary,
                          height: 1.0,
                        ),
                      ),
                      AppSpacing.gapH4,
                      Text(
                        daysUntilRelease == 1 ? 'DAY' : 'DAYS',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.xsBold.copyWith(
                          color: context.textTertiary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                AppSpacing.gapW12,
              ],
            ),
          ),
        );
      },
    );
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
                    child: Icon(Icons.person, color: context.textTertiary, size: 40),
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
                  child: Icon(Icons.person, color: context.textTertiary, size: 40),
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
                    style: AppTextStyles.smBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.gapH4,
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
