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
        child: Column(
          children: [
            _EpisodeRow(
              title: 'S2 · E6 Attila',
              subtitle: 'Watched · Aug 14',
              isWatched: true,
            ),
            AppSpacing.gapH16,
            _EpisodeRow(
              title: 'S2 · E7 Chikhai Bardo',
              subtitle: 'Watched · Aug 18',
              isWatched: true,
            ),
            AppSpacing.gapH16,
            _EpisodeRow(
              title: 'S2 · E8 Sweet Vitriol',
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

  static const double _markerSize = 28.0;

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
                  size: AppSpacing.md,
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
      title: 'A nudge the morning it airs',
      body:
          'Follow a show and we watch the air dates for you — episode drops, '
          'premieres, and finales.',
      child: Column(
        children: [
          _NotificationPreview(),
          AppSpacing.gapH12,
          Row(
            children: [
              Expanded(
                child: _AlertTypeChip(
                  label: 'Episodes',
                  color: AppColors.airing,
                ),
              ),
              AppSpacing.gapW8,
              Expanded(
                child: _AlertTypeChip(
                  label: 'Premieres',
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.gapW8,
              Expanded(
                child: _AlertTypeChip(
                  label: 'Finales',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          AppSpacing.gapH12,
          OnboardingNote(
            text: 'All three are on by default — mute any of them in Settings.',
          ),
        ],
      ),
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview();

  static const double _iconSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
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
                  "Severance S2 E8 just landed. You're 1 episode from the "
                  'finale.',
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

class _AlertTypeChip extends StatelessWidget {
  const _AlertTypeChip({required this.label, required this.color});

  static const double _dotSize = 8.0;

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          AppSpacing.gapH8,
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.xsMedium,
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
      title: 'Twelve weeks of you, in amber',
      body:
          'Every marked episode fills a square. Streaks, hours, and totals '
          'build themselves.',
      child: Column(
        children: [
          OnboardingCard(
            child: Column(
              children: [
                _ActivityHeatmap(),
                AppSpacing.gapH12,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeatmapCaption(text: '312 episodes'),
                    _HeatmapCaption(text: '21-day streak', isStreak: true),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapH12,
          Row(
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
                  label: 'Episodes watched',
                  color: AppColors.success,
                ),
              ),
              AppSpacing.gapW8,
              Expanded(
                child: _StatTile(
                  value: '9',
                  label: 'Movies watched',
                  color: AppColors.airing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Twelve weeks (columns) by seven days (rows) of sample activity. Fixed rather
/// than randomised so the illustration is identical on every run — this is
/// artwork, not the user's real history, which lands once they start tracking.
///
/// Each character is an intensity from 0 (no episodes) to 4 (a heavy day).
const List<String> _sampleActivityWeeks = [
  '001202300411',
  '120033104022',
  '203114002340',
  '011240321003',
  '330021140230',
  '102403012341',
  '021130204012',
];

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap();

  static const double _cellGap = 3.0;
  static const double _cellRadius = 2.0;

  @override
  Widget build(BuildContext context) {
    final columnCount = _sampleActivityWeeks.first.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - _cellGap * (columnCount - 1)) / columnCount;

        return Column(
          children: [
            for (var row = 0; row < _sampleActivityWeeks.length; row++) ...[
              if (row > 0) const SizedBox(height: _cellGap),
              Row(
                children: [
                  for (var column = 0; column < columnCount; column++) ...[
                    if (column > 0) const SizedBox(width: _cellGap),
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _colorFor(
                            _sampleActivityWeeks[row].codeUnitAt(column) - 0x30,
                          ),
                          borderRadius: BorderRadius.circular(_cellRadius),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Color _colorFor(int intensity) => intensity <= 0
      ? AppColors.heatmapEmptyDark
      : AppColors.heatmapYellowScale[intensity - 1];
}

class _HeatmapCaption extends StatelessWidget {
  const _HeatmapCaption({required this.text, this.isStreak = false});

  final String text;
  final bool isStreak;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          (isStreak
                  ? AppTextStyles.xsBold.withColor(AppColors.success)
                  : AppTextStyles.xs.withColor(AppColors.textTertiary))
              .withTabularFigures(),
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
