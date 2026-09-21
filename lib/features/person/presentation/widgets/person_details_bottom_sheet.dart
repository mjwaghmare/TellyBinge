import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../cubit/person_details_cubit.dart';
import '../cubit/person_details_state.dart';

/// A bottom sheet that displays actor/crew profile information, biography,
/// and their complete filmography (movies & TV shows) with direct navigation.
class PersonDetailsBottomSheet extends StatefulWidget {
  final int personId;
  final String? initialName;
  final String? initialProfilePath;

  const PersonDetailsBottomSheet({
    super.key,
    required this.personId,
    this.initialName,
    this.initialProfilePath,
  });

  /// Presents the person details bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required int personId,
    String? initialName,
    String? initialProfilePath,
    TmdbClient? tmdbClient,
  }) {
    AppHaptics.lightImpact();
    final client = tmdbClient ?? context.read<TmdbClient>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      useSafeArea: true,
      builder: (_) => BlocProvider(
        create: (_) =>
            PersonDetailsCubit(tmdbClient: client)..loadPersonDetails(personId),
        child: PersonDetailsBottomSheet(
          personId: personId,
          initialName: initialName,
          initialProfilePath: initialProfilePath,
        ),
      ),
    );
  }

  @override
  State<PersonDetailsBottomSheet> createState() =>
      _PersonDetailsBottomSheetState();
}

class _PersonDetailsBottomSheetState extends State<PersonDetailsBottomSheet> {
  bool _isBioExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isLight ? AppColors.lightSurface : AppColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isLight ? AppColors.borderLight : AppColors.borderDark,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.45),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xs,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textTertiary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Main body driven by Cubit state
              Expanded(
                child: BlocBuilder<PersonDetailsCubit, PersonDetailsState>(
                  builder: (context, state) {
                    if (state is PersonDetailsError) {
                      return _buildErrorView(context, state.message);
                    }

                    final bool isLoading =
                        state is PersonDetailsLoading ||
                        state is PersonDetailsInitial;
                    final Map<String, dynamic> person =
                        state is PersonDetailsSuccess
                            ? state.person
                            : _dummyPersonData();
                    final List<Map<String, dynamic>> works =
                        state is PersonDetailsSuccess
                            ? state.displayedWorks
                            : _dummyWorksList();
                    final String activeFilter =
                        state is PersonDetailsSuccess
                            ? state.selectedFilter
                            : 'all';
                    final int movieCount =
                        state is PersonDetailsSuccess ? state.movieCount : 0;
                    final int tvCount =
                        state is PersonDetailsSuccess ? state.tvCount : 0;
                    final int totalCount =
                        state is PersonDetailsSuccess ? state.totalCount : 0;

                    return Skeletonizer(
                      enabled: isLoading,
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.xl,
                        ),
                        children: [
                          _buildHeader(context, person),
                          _buildBiographySection(context, person),
                          AppSpacing.gapH20,
                          _buildWorksHeader(
                            context,
                            activeFilter: activeFilter,
                            totalCount: totalCount,
                            movieCount: movieCount,
                            tvCount: tvCount,
                            isLoading: isLoading,
                          ),
                          AppSpacing.gapH16,
                          _buildWorksGrid(context, works, isLoading),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> person) {
    final name = (person['name'] as String?)?.trim() ??
        widget.initialName ??
        'Cast Member';
    final department = person['known_for_department'] as String? ?? 'Acting';
    final profilePath =
        person['profile_path'] as String? ?? widget.initialProfilePath;
    final birthday = person['birthday'] as String?;
    final deathday = person['deathday'] as String?;
    final placeOfBirth = person['place_of_birth'] as String?;

    final metadataParts = <String>[];
    if (birthday != null && birthday.isNotEmpty) {
      final birthYear = birthday.split('-').first;
      if (deathday != null && deathday.isNotEmpty) {
        final deathYear = deathday.split('-').first;
        metadataParts.add('$birthYear – $deathYear');
      } else {
        final age = _calculateAge(birthday);
        if (age != null) {
          metadataParts.add('Age $age');
        } else {
          metadataParts.add(birthYear);
        }
      }
    }
    if (placeOfBirth != null && placeOfBirth.isNotEmpty) {
      metadataParts.add(placeOfBirth.trim());
    }

    final imageUrl = profilePath != null && profilePath.isNotEmpty
        ? AppConstants.tmdbImageUrl(profilePath, size: 'w342')
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Actor portrait
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 76,
            height: 98,
            color: context.adaptiveColor(
              light: AppColors.lightSurfaceElevated,
              dark: AppColors.surface,
            ),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: context.textTertiary,
                        size: 36,
                      ),
                    ),
                    errorWidget: (_, _, _) => Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: context.textTertiary,
                        size: 36,
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.person_rounded,
                      color: context.textTertiary,
                      size: 36,
                    ),
                  ),
          ),
        ),
        AppSpacing.gapW16,

        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTextStyles.xl.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.gapH8,

              // Department badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: context.adaptiveColor(
                    light: AppColors.lightPrimaryContainer,
                    dark: AppColors.primary.withValues(alpha: 0.16),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  department.toUpperCase(),
                  style: AppTextStyles.xsBold.copyWith(
                    color: context.adaptiveColor(
                      light: AppColors.lightOnPrimaryContainer,
                      dark: AppColors.primaryLight,
                    ),
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              if (metadataParts.isNotEmpty) ...[
                AppSpacing.gapH8,
                Text(
                  metadataParts.join(' • '),
                  style: AppTextStyles.xs.copyWith(
                    color: context.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Close button with >=48x48 touch target
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(Icons.close_rounded, color: context.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildBiographySection(
    BuildContext context,
    Map<String, dynamic> person,
  ) {
    final biography = (person['biography'] as String?)?.trim() ?? '';
    if (biography.isEmpty) return const SizedBox.shrink();

    final isLong = biography.length > 200;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            biography,
            style: AppTextStyles.sm.copyWith(
              color: context.textSecondary,
              height: 1.45,
            ),
            maxLines: _isBioExpanded ? null : 3,
            overflow: _isBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (isLong)
            GestureDetector(
              onTap: () {
                AppHaptics.selectionClick();
                setState(() {
                  _isBioExpanded = !_isBioExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  _isBioExpanded ? 'Read less' : 'Read more',
                  style: AppTextStyles.xsBold.copyWith(
                    color: context.adaptiveColor(
                      light: AppColors.lightPrimary,
                      dark: AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorksHeader(
    BuildContext context, {
    required String activeFilter,
    required int totalCount,
    required int movieCount,
    required int tvCount,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'KNOWN FOR',
              style: AppTextStyles.posterHeader.copyWith(
                color: context.textPrimary,
              ),
            ),
            if (!isLoading && totalCount > 0)
              Text(
                '$totalCount CREDITS',
                style: AppTextStyles.xsBold.copyWith(
                  color: context.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
        AppSpacing.gapH12,

        // Segmented filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: totalCount > 0 ? 'All ($totalCount)' : 'All',
                filterKey: 'all',
                isActive: activeFilter == 'all',
                isLoading: isLoading,
              ),
              AppSpacing.gapW8,
              _buildFilterChip(
                context,
                label: movieCount > 0 ? 'Movies ($movieCount)' : 'Movies',
                filterKey: 'movie',
                isActive: activeFilter == 'movie',
                isLoading: isLoading,
              ),
              AppSpacing.gapW8,
              _buildFilterChip(
                context,
                label: tvCount > 0 ? 'TV Shows ($tvCount)' : 'TV Shows',
                filterKey: 'tv',
                isActive: activeFilter == 'tv',
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required String filterKey,
    required bool isActive,
    required bool isLoading,
  }) {
    final isLight = context.isLight;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: isLoading
          ? null
          : () {
              AppHaptics.selectionClick();
              context.read<PersonDetailsCubit>().setFilter(filterKey);
            },
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? (isLight
                  ? AppColors.lightPrimaryContainer
                  : AppColors.primary.withValues(alpha: 0.22))
              : (isLight
                  ? AppColors.lightSurfaceElevated
                  : AppColors.surface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? (isLight
                    ? AppColors.lightPrimary.withValues(alpha: 0.3)
                    : AppColors.primary.withValues(alpha: 0.6))
                : (isLight ? AppColors.borderLight : AppColors.borderDark),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.xsBold.copyWith(
              color: isActive
                  ? (isLight
                      ? AppColors.lightOnPrimaryContainer
                      : AppColors.primaryLight)
                  : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorksGrid(
    BuildContext context,
    List<Map<String, dynamic>> works,
    bool isLoading,
  ) {
    if (works.isEmpty && !isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.movie_filter_outlined,
                size: 40,
                color: context.textTertiary,
              ),
              AppSpacing.gapH8,
              Text(
                'No credits found in this category.',
                style: AppTextStyles.sm.copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: works.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.48,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final work = works[index];
        return _buildWorkCard(context, work, isLoading);
      },
    );
  }

  Widget _buildWorkCard(
    BuildContext context,
    Map<String, dynamic> work,
    bool isLoading,
  ) {
    final mediaType = work['media_type'] as String? ?? 'movie';
    final isMovie = mediaType == 'movie';
    final title = isMovie
        ? (work['title'] as String? ?? 'Untitled')
        : (work['name'] as String? ?? 'Untitled');
    final character = work['character'] as String? ?? '';
    final posterPath = work['poster_path'] as String?;
    final voteAverage = (work['vote_average'] as num?)?.toDouble() ?? 0.0;
    final dateStr = isMovie
        ? (work['release_date'] as String?)
        : (work['first_air_date'] as String?);
    final year = dateStr != null && dateStr.length >= 4
        ? dateStr.substring(0, 4)
        : null;

    final posterUrl = posterPath != null && posterPath.isNotEmpty
        ? AppConstants.tmdbImageUrl(posterPath, size: 'w342')
        : '';

    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              final id = (work['id'] as num?)?.toInt();
              if (id == null || id <= 0) return;

              AppHaptics.lightImpact();

              if (isMovie) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MovieDetailsPage(
                      movieId: id,
                      title: title,
                      posterPath: posterPath,
                    ),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (routeContext) => BlocProvider<ShowDetailsCubit>(
                      create: (_) => ShowDetailsCubit(
                        tmdbClient: routeContext.read<TmdbClient>(),
                      ),
                      child: ShowDetailsPage(
                        mediaId: id,
                        mediaType: 'tv',
                        title: title,
                      ),
                    ),
                  ),
                );
              }
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster Card
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: context.adaptiveColor(
                      light: AppColors.lightSurfaceElevated,
                      dark: AppColors.surface,
                    ),
                    child: posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Center(
                              child: Icon(
                                isMovie
                                    ? Icons.movie_outlined
                                    : Icons.tv_outlined,
                                color: context.textTertiary,
                                size: 28,
                              ),
                            ),
                            errorWidget: (_, _, _) => Center(
                              child: Icon(
                                isMovie
                                    ? Icons.movie_outlined
                                    : Icons.tv_outlined,
                                color: context.textTertiary,
                                size: 28,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              isMovie
                                  ? Icons.movie_outlined
                                  : Icons.tv_outlined,
                              color: context.textTertiary,
                              size: 28,
                            ),
                          ),
                  ),

                  // Subtle gradient for bottom tags
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ),

                  // Media Type Badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isMovie ? 'MOVIE' : 'TV',
                        style: AppTextStyles.xsBold.copyWith(
                          fontSize: 9,
                          color: AppColors.textOnPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),

                  // Rating Pill (if rated)
                  if (voteAverage > 0)
                    Positioned(
                      bottom: 4,
                      left: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            voteAverage.toStringAsFixed(1),
                            style: AppTextStyles.xsBold.copyWith(
                              fontSize: 10,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          AppSpacing.gapH8,

          // Title
          Text(
            title,
            style: AppTextStyles.xsBold.copyWith(
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Character / Role
          if (character.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              character,
              style: AppTextStyles.xs.copyWith(
                fontSize: 11,
                color: context.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Release year
          if (year != null) ...[
            const SizedBox(height: 1),
            Text(
              year,
              style: AppTextStyles.xs.copyWith(
                fontSize: 10,
                color: context.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            AppSpacing.gapH16,
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.sm.copyWith(color: context.textSecondary),
            ),
            AppSpacing.gapH16,
            ElevatedButton.icon(
              onPressed: () => context
                  .read<PersonDetailsCubit>()
                  .loadPersonDetails(widget.personId),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.adaptiveColor(
                  light: AppColors.lightPrimary,
                  dark: AppColors.primary,
                ),
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _calculateAge(String birthday) {
    try {
      final parts = birthday.split('-');
      if (parts.length != 3) return null;
      final birthDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _dummyPersonData() => {
        'name': 'Loading Actor Name',
        'known_for_department': 'Acting',
        'biography':
            'This is a placeholder biography that provides realistic text length for the skeleton loading animation while network data is retrieved from TMDB.',
        'birthday': '1985-05-15',
        'place_of_birth': 'London, United Kingdom',
      };

  static List<Map<String, dynamic>> _dummyWorksList() => List.generate(
        6,
        (i) => {
          'id': i + 1,
          'media_type': i.isEven ? 'movie' : 'tv',
          'title': 'Placeholder Work Title',
          'name': 'Placeholder Work Title',
          'character': 'Character Role',
          'vote_average': 8.0,
          'release_date': '2023-01-01',
        },
      );
}
