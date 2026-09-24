import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_confirm_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/polaroid_share_modal.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../pages/profile_page.dart' show HorizontalItem;

/// Shows a quick haptic action sheet for Profile grid items.
Future<void> showProfileQuickActions(
  BuildContext context, {
  required HorizontalItem item,
}) async {
  unawaited(AppHaptics.mediumImpact());

  final int id = item.movieId;
  final String title = item.title.isNotEmpty ? item.title : 'Unknown';
  final bool isMovie = item.isMovie;
  final String mediaType = isMovie ? 'movie' : 'tv';
  final double rating = item.voteAverage;
  final String dateStr = item.releaseDate;

  final year = (dateStr.length >= 4) ? dateStr.substring(0, 4) : '';
  final typeLabel = isMovie ? 'Movie' : 'TV Series';
  final ratingPart =
      rating >= 1.0 ? '★ ${rating.toStringAsFixed(1)}' : '';
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

  final actions = <AppActionSheetAction>[];

  if (isMovie) {
    final movieCubit = safeRead<MovieWatchlistCubit>();
    final isWatched = item.isWatched;
    final isFavorite = item.isFavorite;

    // 1. Watched Status Action
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
          if (uid == null) return;
          AppHaptics.mediumImpact();
          movieCubit?.toggleWatched(
            uid: uid,
            movieId: id,
            isWatched: !isWatched,
          );
          if (isWatched) {
            AppSnackbar.showInfo(context, 'Marked as unwatched');
          } else {
            AppSnackbar.showSuccess(context, 'Marked as watched');
          }
        },
      ),
    );

    // 2. Favorite Action
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
          if (uid == null) return;
          AppHaptics.mediumImpact();
          movieCubit?.toggleFavorite(
            uid: uid,
            movieId: id,
            isFavorite: !isFavorite,
          );
          if (isFavorite) {
            AppSnackbar.showInfo(context, 'Removed from favorites');
          } else {
            AppSnackbar.showSuccess(context, 'Added to favorites');
          }
        },
      ),
    );

    // 3. Remove Action (Destructive)
    actions.add(
      AppActionSheetAction(
        label: 'Remove from Watchlist',
        subtitle: 'Remove from your saved movies',
        icon: Icons.bookmark_remove_rounded,
        iconColor: AppColors.error,
        isDestructive: true,
        onTap: () {
          if (uid == null) return;
          AppHaptics.mediumImpact();
          movieCubit?.removeMovie(uid: uid, movieId: id);
          AppSnackbar.showInfo(context, 'Removed from Watchlist');
        },
      ),
    );
  } else {
    // TV Show
    final tvCubit = safeRead<TvShowWatchlistCubit>();
    final isFavorite = item.isFavorite;
    final isAllWatched = item.isWatched ||
        (item.totalEpisodes > 0 && item.watchedCount >= item.totalEpisodes);

    // 1. Watched Action
    if (!isAllWatched) {
      actions.add(
        AppActionSheetAction(
          label: 'Mark All as Watched',
          subtitle: item.totalEpisodes > 0
              ? 'Log all released episodes (${item.watchedCount}/${item.totalEpisodes})'
              : 'Log all released episodes as watched',
          icon: Icons.done_all_rounded,
          iconColor: AppColors.brandGreen,
          onTap: () async {
            if (uid == null) return;
            final confirmed = await AppConfirmSheet.show(
              context,
              icon: Icons.done_all_rounded,
              title: 'Mark All Watched?',
              message:
                  'Are you sure you want to mark all released episodes of "$title" as watched?',
              confirmLabel: 'Mark All Watched',
              isDestructive: false,
            );
            if (confirmed != true || !context.mounted) return;

            await AppHaptics.mediumImpact();
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
    } else {
      actions.add(
        AppActionSheetAction(
          label: 'Mark as Unwatched',
          subtitle: 'Reset episode watch history',
          icon: Icons.remove_done_rounded,
          iconColor: AppColors.ended,
          onTap: () async {
            if (uid == null) return;
            final confirmed = await AppConfirmSheet.show(
              context,
              icon: Icons.remove_done_rounded,
              title: 'Mark as Unwatched?',
              message:
                  'Are you sure you want to reset your watch history for "$title"?',
              confirmLabel: 'Mark Unwatched',
              isDestructive: true,
            );
            if (confirmed != true || !context.mounted) return;

            await AppHaptics.mediumImpact();
            final tvState = tvCubit?.state;
            List<String> watchedKeys = [];
            if (tvState is TvShowWatchlistSuccess) {
              final found = tvState.shows.where((s) => s['id'] == id).firstOrNull;
              if (found != null && found['watchedEpisodes'] is List) {
                watchedKeys =
                    List<String>.from(found['watchedEpisodes'] as List);
              }
            }
            if (watchedKeys.isNotEmpty) {
              await tvCubit?.unmarkMultipleEpisodesWatched(
                uid: uid,
                showId: id,
                episodeKeys: watchedKeys,
              );
            }
            if (context.mounted) {
              AppSnackbar.showInfo(context, 'Reset watch history for "$title"');
            }
          },
        ),
      );
    }

    // 2. Favorite Action
    actions.add(
      AppActionSheetAction(
        label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
        subtitle: isFavorite
            ? 'Remove from your favorite shows'
            : 'Feature on your profile',
        icon: isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        iconColor: isFavorite ? AppColors.error : AppColors.primary,
        onTap: () {
          if (uid == null) return;
          AppHaptics.mediumImpact();
          tvCubit?.toggleFavorite(
            uid: uid,
            showId: id,
            isFavorite: !isFavorite,
          );
          if (isFavorite) {
            AppSnackbar.showInfo(context, 'Removed from favorites');
          } else {
            AppSnackbar.showSuccess(context, 'Added to favorites');
          }
        },
      ),
    );

    // 3. Stop Tracking Action (Destructive)
    actions.add(
      AppActionSheetAction(
        label: 'Stop Tracking',
        subtitle: 'Remove from your TV watchlist',
        icon: Icons.bookmark_remove_rounded,
        iconColor: AppColors.error,
        isDestructive: true,
        onTap: () {
          if (uid == null) return;
          AppHaptics.mediumImpact();
          tvCubit?.removeShow(uid: uid, showId: id);
          AppSnackbar.showInfo(context, 'Stopped tracking show');
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
        final watchedDate = item.watchedAt != null
            ? DateTime.tryParse(item.watchedAt!)
            : null;
        PolaroidShareModal.show(
          context,
          title: title,
          imageUrl: item.imageUrl.isNotEmpty ? item.imageUrl : null,
          rating: rating,
          watchedDate: watchedDate,
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
