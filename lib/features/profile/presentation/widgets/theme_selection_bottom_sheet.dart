import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Modal bottom sheet for selecting the application theme (System, Light, Dark).
/// Features realistic interactive smartphone mockups showcasing Popverse's
/// signature 3-column poster grid UI.
class ThemeSelectionBottomSheet extends StatelessWidget {
  const ThemeSelectionBottomSheet({super.key});

  /// Displays the theme selection bottom sheet.
  static Future<void> show(BuildContext context) {
    AppHaptics.selectionClick();

    return showModalBottomSheet<void>(
      context: context,
      shape: AppBottomSheet.shape,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<ThemeCubit>(),
        child: const ThemeSelectionBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final currentMode = themeState.themeMode;
        final isDark = switch (currentMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceElevated
                : AppColors.lightSurfaceElevated,
            borderRadius: AppBottomSheet.borderRadius,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Top drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Sheet Header
                  Text(
                    'Appearance',
                    style: AppTextStyles.lg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  AppSpacing.gapH4,
                  Text(
                    'Choose how Popverse looks on your device',
                    style: AppTextStyles.sm.copyWith(
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 3-Mockup Theme Selector Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ThemePhoneOption(
                          mode: ThemeMode.system,
                          title: 'System',
                          isSelected: currentMode == ThemeMode.system,
                          isDark: isDark,
                          onTap: () => _handleSelect(context, ThemeMode.system),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ThemePhoneOption(
                          mode: ThemeMode.light,
                          title: 'Light',
                          isSelected: currentMode == ThemeMode.light,
                          isDark: isDark,
                          onTap: () => _handleSelect(context, ThemeMode.light),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ThemePhoneOption(
                          mode: ThemeMode.dark,
                          title: 'Dark',
                          isSelected: currentMode == ThemeMode.dark,
                          isDark: isDark,
                          onTap: () => _handleSelect(context, ThemeMode.dark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  void _handleSelect(BuildContext context, ThemeMode mode) {
    AppHaptics.selectionClick();
    context.read<ThemeCubit>().setThemeMode(mode);
  }
}

/// Interactive phone option card with outer selection ring and device mockup.
class _ThemePhoneOption extends StatelessWidget {
  final ThemeMode mode;
  final String title;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemePhoneOption({
    required this.mode,
    required this.title,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeAccent = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
    final inactiveText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final ringColor = isDark ? AppColors.primary : AppColors.lightPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Outer selection border container (wraps around phone with subtle gap)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: AppSpacing.allXXS,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? ringColor : Colors.transparent,
                width: 2.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ringColor.withValues(alpha: isDark ? 0.35 : 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: AspectRatio(
              aspectRatio: 1 / 1.95,
              child: _PhoneDeviceFrame(mode: mode),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Option label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            style: isSelected
                ? AppTextStyles.smBold.copyWith(color: activeAccent)
                : AppTextStyles.smMedium.copyWith(color: inactiveText),
            child: Text(title),
          ),
        ],
      ),
    );
  }
}

/// Realistic smartphone bezel frame containing the mini screen preview.
class _PhoneDeviceFrame extends StatelessWidget {
  final ThemeMode mode;

  const _PhoneDeviceFrame({required this.mode});

  @override
  Widget build(BuildContext context) {
    const bezelRadius = BorderRadius.all(Radius.circular(18));

    return Container(
      decoration: BoxDecoration(
        borderRadius: bezelRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: bezelRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Screen preview content
            _buildScreenPreview(),

            // Top speaker / camera hint (Dynamic Island pill)
            Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 20,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            // Device bezel border overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: bezelRadius,
                    border: Border.all(
                      color: mode == ThemeMode.light
                          ? AppColors.borderLight
                          : (mode == ThemeMode.dark
                              ? AppColors.borderDark
                              : AppColors.textTertiary),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenPreview() {
    switch (mode) {
      case ThemeMode.light:
        return const _MiniPopverseScreen(isDark: false);
      case ThemeMode.dark:
        return const _MiniPopverseScreen(isDark: true);
      case ThemeMode.system:
        // Reuses the exact same custom mini screen widget in a split view
        return Stack(
          fit: StackFit.expand,
          children: [
            // Left Half: Light Theme
            ClipRect(
              clipper: _LeftHalfClipper(),
              child: const _MiniPopverseScreen(isDark: false),
            ),
            // Right Half: Dark Theme
            ClipRect(
              clipper: _RightHalfClipper(),
              child: const _MiniPopverseScreen(isDark: true),
            ),
            // Center Split Hairline
            Center(
              child: Container(
                width: 1.0,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ],
        );
    }
  }
}

/// Reusable mini screen representing Popverse's Movies grid view UI.
/// Custom created once and reused across Light, Dark, and System modes.
class _MiniPopverseScreen extends StatelessWidget {
  final bool isDark;

  const _MiniPopverseScreen({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final cardBg = isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;
    final cardAccent = isDark ? AppColors.surfaceStackedDark : AppColors.borderLight;
    final textMuted = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    final chipBg = isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top area: Dynamic Island clearance + TabBar ──
          Container(
            color: surface,
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              children: [
                // TabBar: 2 tab pills ("WATCH LIST" active, "UPCOMING" muted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                  child: Row(
                    children: [
                      // Active tab
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: textMuted.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapW4,
                      // Inactive tab
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: textMuted.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.micro),

          // ── Sticky section chip ("WATCH NEXT") ──
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.micro,
              ),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Container(
                width: 14,
                height: 2,
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.micro),

          // ── 3-Column Poster Grid with gradient overlays ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 3;
                  const spacing = 2.5;
                  final cellWidth =
                      (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                          crossAxisCount;
                  final cellHeight = cellWidth * 1.5; // 2:3 aspect ratio

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: List.generate(6, (index) {
                      final hasDate = index == 0 || index == 2 || index == 4;
                      return SizedBox(
                        width: cellWidth,
                        height: cellHeight,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [cardAccent, cardBg],
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Bottom gradient overlay (matches real movie card)
                              if (hasDate)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: cellHeight * 0.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.darkBackground
                                              .withValues(alpha: 0.9),
                                          AppColors.darkBackground
                                              .withValues(alpha: 0.3),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              // Date text at bottom-left
                              if (hasDate)
                                Positioned(
                                  bottom: 2,
                                  left: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          borderRadius:
                                              BorderRadius.circular(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 0.5),
                                      Container(
                                        width: 7,
                                        height: 2,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          borderRadius:
                                              BorderRadius.circular(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),

          // ── 5-Slot Bottom Navigation with center FAB ──
          Container(
            height: 13,
            decoration: BoxDecoration(
              color: surface,
              border: Border(
                top: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Shows tab (muted)
                _buildNavDot(textMuted),
                // Movies tab (active)
                _buildNavDot(primary),
                // Center FAB circle
                Expanded(
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // Explore tab (muted)
                _buildNavDot(textMuted),
                // Profile tab (muted)
                _buildNavDot(textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavDot(Color color) {
    return Expanded(
      child: Center(
        child: Container(
          width: 3.5,
          height: 3.5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Custom clipper that clips a widget to its left 50% width.
class _LeftHalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

/// Custom clipper that clips a widget to its right 50% width.
class _RightHalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
