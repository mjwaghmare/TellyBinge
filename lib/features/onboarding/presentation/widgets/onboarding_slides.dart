import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'onboarding_slide.dart';

/// Slide 1 — marking an episode watched.
class TrackingSlide extends StatelessWidget {
  const TrackingSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlide(
      badge: 'Tracking',
      title: 'Mark it watched, forget the spreadsheet',
      body:
          'Tap an episode and PopVerse advances your season, your progress '
          'bar, and your stats in one move.',
      child: OnboardingCard(
        padding: AppSpacing.allSM,
        child: Column(
          children: [
            _EpisodeRow(
              title: 'S2 · E6 Attila',
              subtitle: 'Watched · Aug 14',
              isWatched: true,
            ),
            AppSpacing.gapH12,
            _EpisodeRow(
              title: 'S2 · E7 Sweet Vitriol',
              subtitle: 'Airs Sep 17',
              isWatched: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.title,
    required this.subtitle,
    required this.isWatched,
  });

  static const double _markerSize = 24.0;

  final String title;
  final String subtitle;
  final bool isWatched;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: _markerSize,
          height: _markerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWatched ? AppColors.primary : Colors.transparent,
            border: isWatched
                ? null
                : Border.all(color: AppColors.textTertiary, width: 2),
          ),
          child: isWatched
              ? const Icon(
                  Icons.check,
                  size: AppSpacing.sm,
                  color: AppColors.textOnPrimary,
                )
              : null,
        ),
        AppSpacing.gapW12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: isWatched
                    ? AppTextStyles.smMedium.withColor(AppColors.textSecondary)
                    : AppTextStyles.smBold,
              ),
              AppSpacing.gapH4,
              Text(
                subtitle,
                style: AppTextStyles.xs.withColor(AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slide 2 — air-date notifications.
class NotificationsSlide extends StatelessWidget {
  const NotificationsSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlide(
      badge: 'Notifications',
      title: 'Dodge the spoilers, catch every drop the moment it airs',
      body:
          'Get instant alerts when new episodes and finales drop so '
          'you’re always first to watch.',
      child: _NotificationPreview(),
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview();

  static const double _iconSize = 36.0;

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      padding: AppSpacing.allSM,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              'assets/images/splash_logo.png',
              width: _iconSize,
              height: _iconSize,
            ),
          ),
          AppSpacing.gapW12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('PopVerse', style: AppTextStyles.smBold),
                    AppSpacing.gapW8,
                    Text(
                      'now',
                      style: AppTextStyles.xs.withColor(AppColors.textTertiary),
                    ),
                  ],
                ),
                AppSpacing.gapH4,
                Text(
                  "Severance S2 E8 just landed. You're 1 episode from the finale.",
                  style: AppTextStyles.sm
                      .withColor(AppColors.textSecondary)
                      .copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide 3 — the stats the app builds on its own.
class StatsSlide extends StatelessWidget {
  const StatsSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlide(
      badge: 'Your stats',
      title: 'Zero spoilers, zero FOMO — always know where you stand',
      body:
          'Build your watch streak, hit your milestones, and stay ahead '
          'of what everyone is talking about.',
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              value: '14',
              label: 'Shows added',
              color: AppColors.primary,
            ),
          ),
          AppSpacing.gapW8,
          Expanded(
            child: _StatTile(
              value: '312',
              label: 'Episodes',
              color: AppColors.success,
            ),
          ),
          AppSpacing.gapW8,
          Expanded(
            child: _StatTile(
              value: '9',
              label: 'Movies',
              color: AppColors.airing,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.xl.withColor(color).withTabularFigures(),
          ),
          AppSpacing.gapH4,
          Text(
            label,
            style: AppTextStyles.xs.withColor(AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
