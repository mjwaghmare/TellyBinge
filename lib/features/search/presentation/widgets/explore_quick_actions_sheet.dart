import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_confirm_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/polaroid_share_modal.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/auth_required_view.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';

/// Shows a quick haptic action sheet for Explore cards (both posters and backdrops).
Future<void> showExploreQuickActions(
  BuildContext context, {
  required dynamic item,
  required String defaultType,
}) async {
  unawaited(AppHaptics.mediumImpact());

  final int id = item['id'] as int? ?? 0;
  final String title = item['name'] ?? item['title'] ?? 'Unknown';
  final String mediaType = item['media_type'] ?? defaultType;
  final String? posterPath = item['poster_path'] as String?;
  final String? backdropPath = item['backdrop_path'] as String?;
  final double voteAverage =
      (item['vote_average'] as num?)?.toDouble() ?? 0.0;
  final String? dateStr =
      item['release_date'] ?? item['first_air_date'] as String?;
  final int runtime = (item['runtime'] as num?)?.toInt() ?? 0;
  final originCountry = item['origin_country'] ??
      (item['production_countries'] as List<dynamic>?)
          ?.map((c) => (c as Map<String, dynamic>)['iso_3166_1']?.toString())
          .whereType<String>()
          .toList();
  final originalLanguage = item['original_language'] as String?;

  final year = (dateStr != null && dateStr.length >= 4)
      ? dateStr.substring(0, 4)
      : '';
  final typeLabel = mediaType == 'tv' ? 'TV Series' : 'Movie';
  final ratingPart = voteAverage >= 1.0 ? '★ ${voteAverage.toStringAsFixed(1)}' : '';
  final metaParts = [
    if (year.isNotEmpty) year,
    typeLabel,
    if (ratingPart.isNotEmpty) ratingPart,
  ];
  final subtitle = metaParts.join(' • ');

  // Safe Bloc lookups to support test environments
  T? safeRead<T extends Object>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  final authCubit = safeRead<AuthCubit>();
  final authState = authCubit?.state;
  final String? uid = authState is Authenticated ? authState.user.uid : null;

  void requireAuth() {
    AuthRequiredBottomSheet.show(
      context,
      title: 'Sign in to Track',
      subtitle: 'Sign in to save and track titles in your personal library.',
      icon: Icons.bookmark_outline_rounded,
    );
  }

  final actions = <AppActionSheetAction>[];

  if (mediaType == 'movie') {
    final movieCubit = safeRead<MovieWatchlistCubit>();
    final movieState = movieCubit?.state;
    bool isWatchlisted = false;
    bool isWatched = false;
    bool isFavorite = false;

    if (movieState is MovieWatchlistSuccess) {
      final found = movieState.movies.where((m) => m['id'] == id).firstOrNull;
      if (found != null) {
        isWatchlisted = true;
        isWatched = found['isWatched'] as bool? ?? false;
        isFavorite = found['isFavorite'] as bool? ?? false;
      }
    }

    // 1. Watchlist Action
    actions.add(
      AppActionSheetAction(
        label: isWatchlisted ? 'Remove from Watchlist' : 'Add to Watchlist',
        subtitle: isWatchlisted
            ? 'Remove from your saved movies'
            : 'Save to watch later',
        icon: isWatchlisted
            ? Icons.bookmark_remove_rounded
            : Icons.bookmark_add_rounded,
        iconColor: isWatchlisted ? AppColors.error : AppColors.primary,
        isDestructive: isWatchlisted,
        onTap: () {
          if (uid == null) {
            requireAuth();
            return;
          }
          AppHaptics.mediumImpact();
          if (isWatchlisted) {
            movieCubit?.removeMovie(uid: uid, movieId: id);
            AppSnackbar.showInfo(context, 'Removed from Watchlist');
          } else {
            movieCubit?.addMovie(
              uid: uid,
              movieId: id,
              title: title,
              posterPath: posterPath,
              backdropPath: backdropPath,
              releaseDate: dateStr,
              runtime: runtime,
              voteAverage: voteAverage,
              originCountry: originCountry,
              originalLanguage: originalLanguage,
            );
            AppSnackbar.showSuccess(context, 'Added to Watchlist');
          }
        },
      ),
    );

    // 2. Watched Status Action
    actions.add(
      AppActionSheetAction(
        label: isWatched ? 'Mark as Unwatched' : 'Mark as Watched',
        subtitle: isWatched
            ? 'Remove from your watched diary'
            : 'Add to your watched diary',
        icon: isWatched
            ? Icons.visibility_off_rounded
            : Icons.check_circle_outline_rounded,
        iconColor: isWatched ? AppColors.ended : AppColors.brandGreen,
        onTap: () {
          if (uid == null) {
            requireAuth();
            return;
          }
          AppHaptics.mediumImpact();
          if (isWatchlisted) {
            movieCubit?.toggleWatched(
              uid: uid,
              movieId: id,
              isWatched: !isWatched,
            );
          } else {
            movieCubit?.addMovie(
              uid: uid,
              movieId: id,
              title: title,
              posterPath: posterPath,
              backdropPath: backdropPath,
              releaseDate: dateStr,
              runtime: runtime,
              voteAverage: voteAverage,
              originCountry: originCountry,
              originalLanguage: originalLanguage,
              isWatched: true,
            );
          }
          if (isWatched) {
            AppSnackbar.showInfo(context, 'Marked as unwatched');
          } else {
            AppSnackbar.showSuccess(context, 'Marked as watched');
          }
        },
      ),
    );

    // 3. Favorite Action
    actions.add(
      AppActionSheetAction(
        label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
        subtitle: isFavorite
            ? 'Remove from your favorites'
            : 'Feature on your profile',
        icon: isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        iconColor: isFavorite ? AppColors.error : AppColors.primary,
        onTap: () {
          if (uid == null) {
            requireAuth();
            return;
          }
          AppHaptics.mediumImpact();
          if (isWatchlisted) {
            movieCubit?.toggleFavorite(
              uid: uid,
              movieId: id,
              isFavorite: !isFavorite,
            );
          } else {
            movieCubit?.addMovie(
              uid: uid,
              movieId: id,
              title: title,
              posterPath: posterPath,
              backdropPath: backdropPath,
              releaseDate: dateStr,
              runtime: runtime,
              voteAverage: voteAverage,
              originCountry: originCountry,
              originalLanguage: originalLanguage,
              isFavorite: true,
            );
          }
          if (isFavorite) {
            AppSnackbar.showInfo(context, 'Removed from favorites');
          } else {
            AppSnackbar.showSuccess(context, 'Added to favorites');
          }
        },
      ),
    );
  } else {
    // TV Show
    final tvCubit = safeRead<TvShowWatchlistCubit>();
    final tvState = tvCubit?.state;
    bool isTracked = false;
    bool isFavorite = false;

    if (tvState is TvShowWatchlistSuccess) {
      final found = tvState.shows.where((s) => s['id'] == id).firstOrNull;
      if (found != null) {
        isTracked = true;
        isFavorite = found['isFavorite'] as bool? ?? false;
      }
    }

    // 1. Track Show / Watchlist Action
    actions.add(
      AppActionSheetAction(
        label: isTracked ? 'Stop Tracking' : 'Track Show',
        subtitle: isTracked
            ? 'Remove from your TV watchlist'
            : 'Follow episodes on your Dashboard',
        icon: isTracked
            ? Icons.bookmark_remove_rounded
            : Icons.bookmark_add_rounded,
        iconColor: isTracked ? AppColors.error : AppColors.primary,
        isDestructive: isTracked,
        onTap: () {
          if (uid == null) {
            requireAuth();
            return;
          }
          AppHaptics.mediumImpact();
          if (isTracked) {
            tvCubit?.removeShow(uid: uid, showId: id);
            AppSnackbar.showInfo(context, 'Stopped tracking show');
          } else {
            tvCubit?.addShow(
              uid: uid,
              showId: id,
              name: title,
              posterPath: posterPath,
              backdropPath: backdropPath,
              firstAirDate: dateStr,
              voteAverage: voteAverage,
              originCountry: originCountry,
              originalLanguage: originalLanguage,
            );
            AppSnackbar.showSuccess(context, 'Added to Dashboard tracking');
          }
        },
      ),
    );

    // 2. Mark All as Watched Action (with Safety Confirmation)
    actions.add(
      AppActionSheetAction(
        label: 'Mark All as Watched',
        subtitle: 'Log all released episodes as watched',
        icon: Icons.done_all_rounded,
        iconColor: AppColors.brandGreen,
        onTap: () async {
          if (uid == null) {
            requireAuth();
            return;
          }
          final confirmed = await AppConfirmSheet.show(
            context,
            icon: Icons.done_all_rounded,
            title: 'Mark All Watched?',
            message: 'Are you sure you want to mark all released episodes of "$title" as watched?',
            confirmLabel: 'Mark All Watched',
            isDestructive: false,
          );
          if (confirmed != true || !context.mounted) return;

          await AppHaptics.mediumImpact();
          if (!isTracked) {
            await tvCubit?.addShow(
              uid: uid,
              showId: id,
              name: title,
              posterPath: posterPath,
              backdropPath: backdropPath,
              firstAirDate: dateStr,
              voteAverage: voteAverage,
            );
          }

          final tmdb = safeRead<TmdbClient>();
          if (tmdb != null) {
            try {
              final details = await tmdb.getTvShowDetails(id);
              final seasons = details['seasons'] as List<dynamic>? ?? [];
              final episodeKeys = <String>[];
              for (final season in seasons) {
                final seasonNum = season['season_number'] as int? ?? 0;
                if (seasonNum == 0) continue; // Skip specials
                final epCount = season['episode_count'] as int? ?? 0;
                for (var ep = 1; ep <= epCount; ep++) {
                  episodeKeys.add('$seasonNum-$ep');
                }
              }
              if (episodeKeys.isNotEmpty) {
                await tvCubit?.markMultipleEpisodesWatched(
                  uid: uid,
                  showId: id,
                  episodeKeys: episodeKeys,
                );
              }
            } catch (_) {}
          }
          if (context.mounted) {
            AppSnackbar.showSuccess(
              context,
              'Marked all episodes of "$title" as watched',
            );
          }
        },
      ),
    );

    // 3. Favorite Action
    actions.add(
      AppActionSheetAction(
        label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
        subtitle: isFavorite
            ? 'Remove from favorite shows'
            : 'Feature on your profile',
        icon: isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        iconColor: isFavorite ? AppColors.error : AppColors.primary,
        onTap: () {
          if (uid == null) {
            requireAuth();
            return;
          }
          AppHaptics.mediumImpact();
          if (isTracked) {
            tvCubit?.toggleFavorite(
              uid: uid,
              showId: id,
              isFavorite: !isFavorite,
            );
          } else {
            tvCubit?.addShow(
              uid: uid,
              showId: id,
              name: title,
              posterPath: posterPath,
              backdropPath: backdropPath,
              firstAirDate: dateStr,
              voteAverage: voteAverage,
            );
            tvCubit?.toggleFavorite(
              uid: uid,
              showId: id,
              isFavorite: true,
            );
          }
          if (isFavorite) {
            AppSnackbar.showInfo(context, 'Removed from favorites');
          } else {
            AppSnackbar.showSuccess(context, 'Added to favorites');
          }
        },
      ),
    );
  }

  // 4. Share Polaroid Action (Universal)
  actions.add(
    AppActionSheetAction(
      label: 'Share Polaroid',
      subtitle: 'Export a 3D aesthetic photo card',
      icon: Icons.photo_camera_rounded,
      iconColor: AppColors.primary,
      onTap: () {
        AppHaptics.lightImpact();
        final imagePath = backdropPath ?? posterPath;
        final shareImageUrl = imagePath != null && imagePath.isNotEmpty
            ? AppConstants.tmdbImageUrl(imagePath, size: 'w780')
            : null;
        PolaroidShareModal.show(
          context,
          title: title,
          imageUrl: shareImageUrl,
          rating: voteAverage,
          mediaType: mediaType,
          tmdbId: id,
        );
      },
    ),
  );

  await AppActionSheet.show(
    context,
    title: title,
    subtitle: subtitle,
    actions: actions,
  );
}
