import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shared frame for a carousel slide: eyebrow badge, headline, body copy and a
/// slide-specific illustration below them.
///
/// Content is bottom-aligned so the poster wall stays visible above it, and
/// scrolls when a tall slide meets a short screen rather than overflowing.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({
    super.key,
    required this.badge,
    required this.title,
    required this.body,
    required this.child,
  });

  final String badge;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnboardingBadge(label: badge),
                AppSpacing.gapH16,
                Text(title, style: AppTextStyles.xl.copyWith(height: 1.2)),
                AppSpacing.gapH12,
                Text(
                  body,
                  style: AppTextStyles.sm
                      .withColor(AppColors.textSecondary)
                      .copyWith(height: 1.5),
                ),
                AppSpacing.gapH20,
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Amber eyebrow label naming the feature a slide is about.
class OnboardingBadge extends StatelessWidget {
  const OnboardingBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.xsBold
            .withColor(AppColors.textOnPrimary)
            .copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

/// Bordered panel the slide illustrations sit in.
class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? AppSpacing.allMD,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: child,
    );
  }
}

/// Footnote line — a small amber icon beside a sentence of fine print.
class OnboardingNote extends StatelessWidget {
  const OnboardingNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: AppSpacing.md,
            color: AppColors.primary,
          ),
          AppSpacing.gapW8,
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.xs
                  .withColor(AppColors.textSecondary)
                  .copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
