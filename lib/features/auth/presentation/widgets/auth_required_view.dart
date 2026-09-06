import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import 'login_poster_wall.dart';

/// Reusable full-tab prompt displayed when a guest user navigates to a tab
/// requiring an account (e.g. Shows, Movies, Profile).
///
/// Styled identically to the Login and Onboarding screens with the poster wall
/// backdrop, scrim gradient, bottom-anchored layout, and smooth staggered entrance animations.
class AuthRequiredView extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> features;
  final IconData? icon;
  final String? badge;
  final bool showPosterWall;
  final ValueNotifier<int>? tabNotifier;
  final int? tabIndex;

  const AuthRequiredView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.features,
    this.icon,
    this.badge,
    this.showPosterWall = true,
    this.tabNotifier,
    this.tabIndex,
  });

  @override
  State<AuthRequiredView> createState() => _AuthRequiredViewState();
}

class _AuthRequiredViewState extends State<AuthRequiredView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _headerSlideAnimation;
  late final Animation<Offset> _cardSlideAnimation;
  late final Animation<Offset> _ctaSlideAnimation;
  late final List<Animation<double>> _checkmarkAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _ctaSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    final totalFeatures = widget.features.length;
    _checkmarkAnimations = List.generate(totalFeatures, (i) {
      final start = (0.28 + (i * 0.12)).clamp(0.0, 0.85);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.elasticOut),
        ),
      );
    });

    widget.tabNotifier?.addListener(_onTabChanged);

    // If no tabNotifier is bound or this tab is currently selected, animate in immediately.
    if (widget.tabNotifier == null ||
        widget.tabNotifier?.value == widget.tabIndex) {
      _controller.forward();
    }
  }

  void _onTabChanged() {
    if (widget.tabNotifier?.value == widget.tabIndex) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final textSecColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final scrimGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              AppColors.background.withValues(alpha: 0.25),
              AppColors.background.withValues(alpha: 0.65),
              AppColors.background,
              AppColors.background,
            ]
          : [
              AppColors.lightBackground.withValues(alpha: 0.25),
              AppColors.lightBackground.withValues(alpha: 0.70),
              AppColors.lightBackground,
              AppColors.lightBackground,
            ],
      stops: const [0.0, 0.32, 0.52, 1.0],
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.lightBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.showPosterWall) ...[
            const LoginPosterWall(),
            DecoratedBox(decoration: BoxDecoration(gradient: scrimGradient)),
          ],
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.md,
                              AppSpacing.xl,
                              128.0, // Clearance for elevated center dice and bottom bar
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Title & Subtitle with slide entrance
                                  SlideTransition(
                                    position: _headerSlideAnimation,
                                    child: Column(
                                      children: [
                                        Text(
                                          widget.title,
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.xl
                                              .withColor(textColor)
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        AppSpacing.gapH8,
                                        Text(
                                          widget.subtitle,
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.sm
                                              .withColor(textSecColor)
                                              .copyWith(height: 1.45),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppSpacing.gapH20,

                                  // Feature Highlights Card
                                  if (widget.features.isNotEmpty)
                                    SlideTransition(
                                      position: _cardSlideAnimation,
                                      child: Container(
                                        width: double.infinity,
                                        padding: AppSpacing.allMD,
                                        decoration: BoxDecoration(
                                          color: surfaceColor,
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                          border: Border.all(color: borderColor),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: isDark ? 0.35 : 0.05,
                                              ),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            for (int i = 0;
                                                i < widget.features.length;
                                                i++) ...[
                                              if (i > 0) AppSpacing.gapH12,
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.only(
                                                      top: 2.0,
                                                    ),
                                                    child: ScaleTransition(
                                                      scale: _checkmarkAnimations[i],
                                                      child: const Icon(
                                                        Icons.check_circle_rounded,
                                                        size: 18,
                                                        color:
                                                            AppColors.brandGreen,
                                                      ),
                                                    ),
                                                  ),
                                                  AppSpacing.gapW12,
                                                  Expanded(
                                                    child: FadeTransition(
                                                      opacity: _checkmarkAnimations[i],
                                                      child: Text(
                                                        widget.features[i],
                                                        style: AppTextStyles
                                                            .smMedium
                                                            .withColor(textColor)
                                                            .copyWith(
                                                              height: 1.35,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  AppSpacing.gapH24,

                                  // Sign-in CTA & subtitle
                                  SlideTransition(
                                    position: _ctaSlideAnimation,
                                    child: Column(
                                      children: [
                                        const AuthGoogleSignInButton(),
                                        AppSpacing.gapH12,
                                        Text(
                                          'Sync your progress seamlessly across devices.',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.xs.withColor(
                                            AppColors.textTertiary,
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Google Sign-in button with state loading/error handling.
class AuthGoogleSignInButton extends StatelessWidget {
  final VoidCallback? onSuccess;

  const AuthGoogleSignInButton({super.key, this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          onSuccess?.call();
        } else if (state is AuthError) {
          AppSnackbar.showError(context, state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoginLoading || state is AuthLoading;

        return ElevatedButton(
          onPressed: isLoading
              ? null
              : () => context.read<AuthCubit>().signInWithGoogle(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            disabledForegroundColor: AppColors.textOnPrimary.withValues(
              alpha: 0.5,
            ),
            minimumSize: const Size.fromHeight(54.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: AppSpacing.xl,
                  height: AppSpacing.xl,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textOnPrimary,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AppAssets.googleLogo,
                      width: AppSpacing.xl,
                      height: AppSpacing.xl,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.login,
                        size: AppSpacing.xl,
                        color: Colors.white,
                      ),
                    ),
                    AppSpacing.gapW12,
                    Flexible(
                      child: Text(
                        'Continue with Google',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.mdBold.withColor(
                          AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Modal bottom sheet shown when a guest user tries to perform a protected action
/// (such as adding to watchlist, rating, marking watched).
class AuthRequiredBottomSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AuthRequiredBottomSheet({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.lock_outline_rounded,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    IconData icon = Icons.lock_outline_rounded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          AuthRequiredBottomSheet(title: title, subtitle: subtitle, icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.surfaceElevated
        : AppColors.lightSurfaceElevated;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final textSecColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppSpacing.gapH24,

              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
                child: Icon(icon, size: 30, color: AppColors.primary),
              ),
              AppSpacing.gapH16,

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.lg.withColor(textColor),
              ),
              AppSpacing.gapH8,

              // Subtitle
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.sm
                    .withColor(textSecColor)
                    .copyWith(height: 1.4),
              ),
              AppSpacing.gapH24,

              // Sign In Button
              AuthGoogleSignInButton(
                onSuccess: () {
                  Navigator.of(context).pop();
                },
              ),
              AppSpacing.gapH12,
            ],
          ),
        ),
      ),
    );
  }
}
