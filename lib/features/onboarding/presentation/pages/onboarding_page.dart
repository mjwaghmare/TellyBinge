import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/genre_poster_collage.dart';
import '../widgets/onboarding_poster_wall.dart';
import '../widgets/onboarding_slides.dart';

/// Five-slide intro carousel shown once per install ahead of the login screen.
/// Slide 5 includes the interactive 12-poster genre matching experience.
/// Calls [onFinished] when the user completes the flow or skips.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static final LinearGradient _scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.background.withValues(alpha: 0.35),
      AppColors.background.withValues(alpha: 0.75),
      AppColors.background,
      AppColors.background,
    ],
    stops: const [0.0, 0.34, 0.58, 1.0],
  );

  final PageController _controller = PageController();
  int _index = 0;

  final Set<int> _selectedPosterIndices = {};
  final Set<String> _selectedGenres = {};

  static const int _totalSlideCount = 5;
  bool get _isLastSlide => _index == _totalSlideCount - 1;


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePoster(int index) {
    setState(() {
      togglePosterSelection(
        index: index,
        selectedIndices: _selectedPosterIndices,
        selectedGenres: _selectedGenres,
      );
    });
  }

  Future<void> _next() async {
    unawaited(AppHaptics.selectionClick());
    if (_isLastSlide) {
      await _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    unawaited(AppHaptics.lightImpact());
    await _finish();
  }

  Future<void> _finish() async {
    if (mounted) {
      await saveOnboardingGenres(
        context: context,
        selectedGenres: _selectedGenres,
      );
    }
    if (mounted) {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = [
      const TrackingSlide(),
      const ReleasesSlide(),
      const DiscoverSlide(),
      const StatsSlide(),
      MatchingSlide(
        selectedIndices: _selectedPosterIndices,
        onToggle: _togglePoster,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const OnboardingPosterWall(),
            DecoratedBox(decoration: BoxDecoration(gradient: _scrim)),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Visibility(
                        visible: !_isLastSlide,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              AppSpacing.huge,
                              AppSpacing.xxxl,
                            ),
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: Text(
                            AppConstants.onboardingSkipButton,
                            style: AppTextStyles.smMedium.withColor(
                              AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (index) => setState(() => _index = index),
                      children: slides,
                    ),
                  ),
                  AppSpacing.gapH16,
                  _PageDots(count: _totalSlideCount, activeIndex: _index),
                  AppSpacing.gapH16,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.md,
                    ),
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        minimumSize: const Size.fromHeight(56.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isLastSlide
                            ? AppConstants.onboardingStartButton
                            : AppConstants.onboardingNextButton,
                        style: AppTextStyles.mdBold.withColor(
                          AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.activeIndex});

  static const double _dotSize = 6.0;
  static const double _activeDotWidth = 24.0;

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) AppSpacing.gapW8,
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: index == activeIndex ? _activeDotWidth : _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? AppColors.primary
                  : AppColors.textTertiary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(_dotSize / 2),
            ),
          ),
        ],
      ],
    );
  }
}
