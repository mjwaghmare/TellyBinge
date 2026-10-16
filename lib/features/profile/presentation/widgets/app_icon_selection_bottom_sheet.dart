import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/models/app_icon_option.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/app_icon_cubit.dart';
import '../cubit/app_icon_state.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Modal bottom sheet for selecting the application launcher icon.
/// Displays a 3x4 grid of 12 icon variants (4 free, 8 premium) with live selection.
class AppIconSelectionBottomSheet extends StatelessWidget {
  const AppIconSelectionBottomSheet({super.key});

  /// Displays the app icon selection bottom sheet.
  static Future<void> show(BuildContext context) {
    AppHaptics.selectionClick();

    bool isPro = false;
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is Authenticated) {
        isPro = authState.user.isPro;
      }
    } catch (_) {}

    return showModalBottomSheet<void>(
      context: context,
      shape: AppBottomSheet.shape,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => AppIconCubit(isProUser: isPro),
        child: const AppIconSelectionBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !context.isLight;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return BlocConsumer<AppIconCubit, AppIconState>(
      listenWhen: (previous, current) {
        if (current.errorMessage != null &&
            current.errorMessage != previous.errorMessage) {
          return true;
        }
        if (previous.isApplying &&
            !current.isApplying &&
            current.errorMessage == null &&
            current.currentIcon != previous.currentIcon) {
          return true;
        }
        return false;
      },
      listener: (context, state) {
        if (state.errorMessage != null) {
          AppSnackbar.showError(
            context,
            state.errorMessage!,
          );
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceElevated
                : AppColors.lightSurfaceElevated,
            borderRadius: AppBottomSheet.borderRadius,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: AppSheetHandle(),
                ),

                // Sheet Header with Title and Close Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Application Icon',
                              style: AppTextStyles.lg.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose your preferred Popverse home icon',
                              style: AppTextStyles.sm.copyWith(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.isApplying)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                          size: 22,
                        ),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Scrollable Grid of Icons & Info Footnote
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                    // 3x4 Grid of Icons
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: AppIconOption.values.length,
                      itemBuilder: (context, index) {
                        final option = AppIconOption.values[index];
                        final isSelected = option == state.currentIcon;

                        return _AppIconTile(
                          option: option,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () => _handleSelectIcon(context, option, state),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Platform Info Footnote
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surface.withValues(alpha: 0.6)
                            : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              !kIsWeb && Platform.isIOS
                                  ? 'iOS will display a brief system confirmation when switching.'
                                  : 'The launcher updates your home screen icon instantly.',
                              style: AppTextStyles.xs.copyWith(
                                color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

  void _handleSelectIcon(BuildContext context, AppIconOption option, AppIconState state) {
    if (state.isApplying || option == state.currentIcon) return;
    AppHaptics.selectionClick();
    context.read<AppIconCubit>().selectIcon(option);
  }
}

/// Interactive icon tile widget showcasing the icon thumbnail, selection ring, and crown badge.
class _AppIconTile extends StatelessWidget {
  final AppIconOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _AppIconTile({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isDark ? AppColors.primary : AppColors.lightPrimary;
    final activeText = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
    final regularText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final subtitleText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Outer selection ring with rounded icon card
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(3.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? ringColor : Colors.transparent,
                    width: 2.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: ringColor.withValues(alpha: isDark ? 0.4 : 0.22),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image Thumbnail
                        Image.asset(
                          option.previewAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: isDark ? AppColors.surface : AppColors.lightSurfaceElevated,
                            child: const Center(
                              child: Icon(Icons.movie_filter_rounded, size: 28, color: AppColors.primary),
                            ),
                          ),
                        ),

                        // Subtle inner border for contrast
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Premium Crown Badge
              if (option.isPremium)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: AppSpacing.allXXS,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: AppColors.gold,
                    ),
                  ),
                ),

              // Selected Checkmark Badge (Bottom Right)
              if (isSelected)
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: ringColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.surfaceElevated : AppColors.lightSurface,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Title
          Text(
            option.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: isSelected
                ? AppTextStyles.xsBold.copyWith(color: activeText)
                : AppTextStyles.xsMedium.copyWith(color: regularText),
          ),

          // Subtitle / Tagline
          Text(
            option.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.xs.copyWith(
              color: subtitleText,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
