import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/onboarding_poster_wall.dart';
import '../widgets/onboarding_slides.dart';

/// Four-slide intro carousel shown once per install, ahead of the login
/// screen. Calls [onFinished] when the user reaches the end or skips.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const List<Widget> _slides = [
    TrackingSlide(),
    ReleasesSlide(),
    DiscoverSlide(),
    StatsSlide(),
  ];

  /// Fades the poster wall into the canvas so the top half reveals the poster grid
  /// while the lower half sits on solid background color, matching the login screen.
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

  bool get _isLastSlide => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLastSlide) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      // Kept in the tree on the last slide so the slides below
                      // don't shift up when it goes away.
                      child: Visibility(
                        visible: !_isLastSlide,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: TextButton(
                          onPressed: widget.onFinished,
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
                      children: _slides,
                    ),
                  ),
                  AppSpacing.gapH20,
                  _PageDots(count: _slides.length, activeIndex: _index),
                  AppSpacing.gapH20,
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
