import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'onboarding_slide.dart';

// =============================================================================
// SLIDE 1: TRACKING SHOWS & MOVIES
// =============================================================================

/// Slide 1 — tracking TV shows and movies with one tap.
class TrackingSlide extends StatelessWidget {
  const TrackingSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlide(
      badge: 'Tracking',
      title: 'Track your shows and movies in one place',
      body:
          'Mark episodes watched with a single tap, track your season '
          'progress, and organize your complete movie watchlist.',
      child: _TrackingPreview(),
    );
  }
}

class _TrackingPreview extends StatefulWidget {
  const _TrackingPreview();

  @override
  State<_TrackingPreview> createState() => _TrackingPreviewState();
}

class _TrackingPreviewState extends State<_TrackingPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      padding: AppSpacing.allSM,
      child: Column(
        children: [
          _EpisodeRow(
            title: 'Severance · S2 E4',
            subtitle: 'Watched · Season on track',
            isWatched: true,
            scaleAnimation: _scaleAnimation,
          ),
          AppSpacing.gapH12,
          const _EpisodeRow(
            title: 'Dune: Part Two',
            subtitle: 'In your Movie Watchlist',
            isWatched: false,
            icon: Icons.movie_filter_rounded,
          ),
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.title,
    required this.subtitle,
    required this.isWatched,
    this.scaleAnimation,
    this.icon,
  });

  static const double _markerSize = 24.0;

  final String title;
  final String subtitle;
  final bool isWatched;
  final Animation<double>? scaleAnimation;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Widget marker = Container(
      width: _markerSize,
      height: _markerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWatched
            ? AppColors.primary
            : (icon != null
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent),
        border: isWatched || icon != null
            ? null
            : Border.all(color: AppColors.textTertiary, width: 2),
      ),
      child: isWatched
          ? const Icon(
              Icons.check,
              size: AppSpacing.sm,
              color: AppColors.textOnPrimary,
            )
          : (icon != null
              ? Icon(icon, size: 13.0, color: AppColors.primary)
              : null),
    );

    if (scaleAnimation != null && isWatched) {
      marker = ScaleTransition(scale: scaleAnimation!, child: marker);
    }

    return Row(
      children: [
        marker,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.gapH4,
              Text(
                subtitle,
                style: AppTextStyles.xs.withColor(AppColors.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SLIDE 2: RELEASES & AIR-DATES
// =============================================================================

/// Slide 2 — air-date reminders and release alerts.
class ReleasesSlide extends StatelessWidget {
  const ReleasesSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlide(
      badge: 'Releases',
      title: 'Never miss a premiere or finale',
      body:
          'Follow upcoming air-dates on your schedule and receive smart '
          'alerts the moment new episodes and movies drop.',
      child: _ReleasesPreview(),
    );
  }
}

class _ReleasesPreview extends StatefulWidget {
  const _ReleasesPreview();

  @override
  State<_ReleasesPreview> createState() => _ReleasesPreviewState();
}

class _ReleasesPreviewState extends State<_ReleasesPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: OnboardingCard(
          padding: AppSpacing.allSM,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/splash_logo.png',
                  width: 36.0,
                  height: 36.0,
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
                          style: AppTextStyles.xs.withColor(
                            AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH4,
                    Text(
                      "Severance S2 finale airs tonight at 9 PM. You're up to date!",
                      style: AppTextStyles.sm
                          .withColor(AppColors.textSecondary)
                          .copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SLIDE 3: SURPRISE ME
// =============================================================================

/// Slide 3 — roll the dice for instant picks.
class DiscoverSlide extends StatelessWidget {
  const DiscoverSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlide(
      badge: 'Surprise Me',
      title: 'Can’t decide? Roll the dice',
      body:
          'Tap Surprise Me to roll the dice and get instant, personalized '
          'movie and TV show recommendations when you’re stuck.',
      child: _SurpriseMePreview(),
    );
  }
}

class _SurpriseMePreview extends StatefulWidget {
  const _SurpriseMePreview();

  @override
  State<_SurpriseMePreview> createState() => _SurpriseMePreviewState();
}

class _SurpriseMePreviewState extends State<_SurpriseMePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _wobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: -0.03)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.03, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      padding: AppSpacing.allSM,
      child: Row(
        children: [
          RotationTransition(
            turns: _wobbleAnimation,
            child: Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.casino_rounded,
                size: 22.0,
                color: AppColors.primary,
              ),
            ),
          ),
          AppSpacing.gapW12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Surprise Me', style: AppTextStyles.smBold),
                AppSpacing.gapH4,
                Text(
                  'Roll for random movies & TV shows',
                  style: AppTextStyles.xs.withColor(AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Roll 🎲',
              style: AppTextStyles.xsBold.withColor(AppColors.primaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SLIDE 4: STATS & INSIGHTS
// =============================================================================

/// Slide 4 — watch time stats and streak built by the app.
class StatsSlide extends StatelessWidget {
  const StatsSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlide(
      badge: 'Your Stats',
      title: 'Your watch habits, beautifully visualized',
      body:
          'Track your total watch time across shows and movies, build your '
          'streak, and see your habits grow automatically.',
      child: _StatsPreview(),
    );
  }
}

class _StatsPreview extends StatefulWidget {
  const _StatsPreview();

  @override
  State<_StatsPreview> createState() => _StatsPreviewState();
}

class _StatsPreviewState extends State<_StatsPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: const [
          Expanded(
            child: _StatTile(
              value: '18d 10h',
              label: 'Shows time',
              color: AppColors.primary,
            ),
          ),
          AppSpacing.gapW8,
          Expanded(
            child: _StatTile(
              value: '6d 4h',
              label: 'Movies time',
              color: AppColors.airing,
            ),
          ),
          AppSpacing.gapW8,
          Expanded(
            child: _StatTile(
              value: '21 days',
              label: 'Watch streak',
              color: AppColors.success,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mdBold
                .withColor(color)
                .withTabularFigures(),
          ),
          AppSpacing.gapH4,
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.xs.withColor(AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}


