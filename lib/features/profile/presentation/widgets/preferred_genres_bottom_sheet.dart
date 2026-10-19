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
import '../../../search/data/explore_genres.dart';
import '../cubit/settings_cubit.dart';

/// Modal bottom sheet allowing users to view and update their preferred genres.
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

  @override
  void initState() {
    super.initState();
    final initial = context.read<SettingsCubit>().state.preferredGenres;
    _selectedGenres = Set<String>.from(initial);
  }

  void _toggleGenre(String label) {
    unawaited(AppHaptics.selectionClick());
    setState(() {
      if (_selectedGenres.contains(label)) {
        if (_selectedGenres.length > 1) {
          _selectedGenres.remove(label);
        }
      } else {
        _selectedGenres.add(label);
      }
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
    final availableGenres = kExploreGenres.where((g) => !g.isAll).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceElevated
            : AppColors.lightSurfaceElevated,
        borderRadius: AppBottomSheet.borderRadius,
      ),
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              'Preferred Genres',
              style: AppTextStyles.lg.copyWith(
                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),

            // Subtitle
            Text(
              'Select genres to personalize your "FOR YOU" feed recommendations',
              style: AppTextStyles.sm.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Genre Chips / Cards Grid
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: availableGenres.map((genre) {
                final isSelected = _selectedGenres.contains(genre.label);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleGenre(genre.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : (isDark
                              ? AppColors.surface
                              : AppColors.lightSurface),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (genre.emoji.isNotEmpty) ...[
                          Text(
                            genre.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Text(
                          genre.label,
                          style: AppTextStyles.smMedium.copyWith(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.textPrimary
                                    : AppColors.primary)
                                : (isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Done / Save Button
            ElevatedButton(
              onPressed: _saveAndClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: Text(
                'Save Preferences',
                style: AppTextStyles.mdMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
