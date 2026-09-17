import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';

/// Modal bottom sheet for selecting the application theme (System, Light, Dark).
/// Features realistic interactive smartphone mockups showcasing Popverse's
/// signature 3-column poster grid UI.
class ThemeSelectionBottomSheet extends StatelessWidget {
  const ThemeSelectionBottomSheet({super.key});

  /// Displays the theme selection bottom sheet.
  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();

    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
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

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevated : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
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
                  const SizedBox(height: 4),
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
    HapticFeedback.lightImpact();
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
            padding: const EdgeInsets.all(3.0),
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
                    color: const Color(0xFF111111),
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
                          ? const Color(0xFFD1D5DB)
                          : (mode == ThemeMode.dark
                              ? const Color(0xFF2E2E34)
                              : const Color(0xFF4B5563)),
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
                color: const Color(0xFF9CA3AF).withValues(alpha: 0.4),
              ),
            ),
          ],
        );
    }
  }
}

/// Reusable mini screen representing Popverse's 3-column poster grid UI.
/// Custom created once and reused across Light, Dark, and System modes.
class _MiniPopverseScreen extends StatelessWidget {
  final bool isDark;

  const _MiniPopverseScreen({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F9FB);
    final surface = isDark ? const Color(0xFF161616) : const Color(0xFFFFFFFF);
    final cardBg = isDark ? const Color(0xFF222228) : const Color(0xFFE2E8F0);
    final cardAccent = isDark ? const Color(0xFF2D2D36) : const Color(0xFFCBD5E1);
    final textMuted = isDark ? const Color(0xFF52525C) : const Color(0xFF94A3B8);
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top app bar / header strip (clearing the Dynamic Island)
          Container(
            padding: const EdgeInsets.only(top: 13, left: 6, right: 6, bottom: 4),
            color: surface,
            child: Row(
              children: [
                // Popverse brand logo bar
                Container(
                  width: 18,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                // Search dot
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 2.5),
                // Filter dot
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Section header pill row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),

          // Popverse 3-Column Poster Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.5),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 2 / 3,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: List.generate(6, (index) {
                  final hasBadge = index == 0 || index == 3;
                  return Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(2.5),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cardAccent,
                          cardBg,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Watched / tracking badge on posters
                        if (hasBadge)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        // Mini title strip at bottom of poster
                        Positioned(
                          bottom: 2,
                          left: 2,
                          right: 2,
                          child: Container(
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: textMuted.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

          // Mini bottom navigation dock
          Container(
            height: 11,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: surface,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF222228) : const Color(0xFFE5E7EB),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Active tab (primary violet dot)
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
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
