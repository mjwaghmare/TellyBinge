import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../onboarding/data/onboarding_storage.dart';
import '../../../onboarding/presentation/widgets/genre_poster_collage.dart';
import '../../../search/data/explore_genres.dart';
import '../cubit/settings_cubit.dart';

/// Modal bottom sheet allowing users to view and update their preferred genres
/// matching the exact OBS poster collage experience.
class PreferredGenresBottomSheet extends StatefulWidget {
  const PreferredGenresBottomSheet({super.key});

  /// Displays the preferred genres bottom sheet.
  static Future<void> show(BuildContext context) {
    unawaited(AppHaptics.selectionClick());
    return showModalBottomSheet<void>(
      context: context,
      shape: AppBottomSheet.shape,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PreferredGenresBottomSheet(),
    );
  }

  @override
  State<PreferredGenresBottomSheet> createState() =>
      _PreferredGenresBottomSheetState();
}

class _PreferredGenresBottomSheetState
    extends State<PreferredGenresBottomSheet> {
  late Set<String> _selectedGenres;
  late Set<int> _selectedPosterIndices;

  @override
  void initState() {
    super.initState();
    final initial = context.read<SettingsCubit>().state.preferredGenres;
    final validFeedGenres = kExploreGenres
        .where((g) => !g.isAll)
        .map((g) => g.label)
        .toSet();

    final validSelected = <String>{};
    for (final raw in initial) {
      final normalized = normalizePosterGenre(raw);
      var matched = false;
      for (final feedGenre in validFeedGenres) {
        if (feedGenre.toLowerCase() == normalized.toLowerCase()) {
          validSelected.add(feedGenre);
          matched = true;
          break;
        }
      }
      if (!matched && raw.trim().isNotEmpty) {
        validSelected.add(raw.trim());
      }
    }

    // Ensure at least one genre remains selected when empty
    if (validSelected.isEmpty) {
      validSelected.add(kMatchingPosters.first.genre);
    }

    _selectedGenres = validSelected;
    _selectedPosterIndices = {
      for (var i = 0; i < kMatchingPosters.length; i++)
        if (_selectedGenres.contains(kMatchingPosters[i].genre)) i,
    };
  }

  void _togglePoster(int index) {
    unawaited(AppHaptics.selectionClick());
    setState(() {
      togglePosterSelection(
        index: index,
        selectedIndices: _selectedPosterIndices,
        selectedGenres: _selectedGenres,
        allowEmpty: false,
      );
    });
  }

  void _removeUnsupportedGenre(String genre) {
    if (_selectedGenres.length <= 1) {
      unawaited(AppHaptics.lightImpact());
      return;
    }
    unawaited(AppHaptics.selectionClick());
    setState(() {
      _selectedGenres.remove(genre);
      _selectedPosterIndices = {
        for (var i = 0; i < kMatchingPosters.length; i++)
          if (_selectedGenres.contains(kMatchingPosters[i].genre)) i,
      };
    });
  }

  Future<void> _saveAndClose() async {
    unawaited(AppHaptics.selectionClick());
    final list = _selectedGenres.toList();
    if (!mounted) return;
    await context.read<SettingsCubit>().setPreferredGenres(list);
    if (!mounted) return;
    final prefs = context.read<SharedPreferences>();
    await OnboardingStorage(prefs).savePreferredGenres(list);
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !context.isLight;
    final screenHeight = MediaQuery.of(context).size.height;
    final posterGenres = kMatchingPosters.map((p) => p.genre).toSet();
    final unsupportedGenres = _selectedGenres
        .where((g) => !posterGenres.contains(g))
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceElevated
            : AppColors.lightSurfaceElevated,
        borderRadius: AppBottomSheet.borderRadius,
      ),
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const AppSheetHandle(),
            const SizedBox(height: AppSpacing.sm),

            // Header Title
            Text(
              'Preferred Genres',
              style: AppTextStyles.lg.copyWith(
                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2.0),

            // Subtitle
            Text(
              'Select genres to personalize your "FOR YOU" feed recommendations • ${_selectedGenres.length} selected',
              style: AppTextStyles.xs.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Removable chips for selected feed genres not represented on posters
            if (unsupportedGenres.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final genre in unsupportedGenres)
                      _buildUnsupportedGenreChip(genre, isDark),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],

            // 12-Poster Collage matching OBS Screen
            Expanded(
              child: GenrePosterCollage(
                selectedIndices: _selectedPosterIndices,
                onToggle: _togglePoster,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Save Preferences Button
            SizedBox(
              width: double.infinity,
              height: 50.0,
              child: ElevatedButton(
                onPressed: _saveAndClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: Text(
                  'Save Preferences',
                  style: AppTextStyles.mdMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedGenreChip(String genre, bool isDark) {
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.xs,
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            genre,
            style: AppTextStyles.xsBold.copyWith(
              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
            ),
          ),
          AppSpacing.gapW4,
          GestureDetector(
            onTap: () => _removeUnsupportedGenre(genre),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14.0,
                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
