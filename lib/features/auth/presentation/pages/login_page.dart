import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../widgets/login_poster_wall.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  /// Fades the poster wall into the canvas so the copy and buttons in the lower
  /// half sit on solid colour rather than on artwork.
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
          const LoginPosterWall(),
          DecoratedBox(decoration: BoxDecoration(gradient: _scrim)),
          SafeArea(
            child: Padding(
              padding: AppSpacing.allXL,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/splash_logo.png',
                      width: AppSpacing.huge,
                      height: AppSpacing.huge,
                    ),
                  ),
                  AppSpacing.gapH12,
                  Text(
                    'Everything you watch, in one place.',
                    style: AppTextStyles.display,
                  ),
                  AppSpacing.gapH16,
                  Text(
                    'Track your progress, view release calendars, and join the '
                    'community of TV show & movie lovers.',
                    style: AppTextStyles.md
                        .withColor(AppColors.textSecondary)
                        .copyWith(height: 1.5),
                  ),
                  AppSpacing.gapH32,
                  const _GoogleSignInButton(),
                  AppSpacing.gapH24,
                  const _OrDivider(),
                  AppSpacing.gapH8,
                  const _BrowseWithoutAccountButton(),
                  AppSpacing.gapH8,
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'By continuing you agree to our Terms of Service.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.xs.withColor(AppColors.textTertiary),
                    ),
                  ),
                  AppSpacing.gapH16,
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
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
            minimumSize: const Size.fromHeight(56.0),
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
                      'assets/images/google.png',
                      width: AppSpacing.xl,
                      height: AppSpacing.xl,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(
      child: ColoredBox(
        color: AppColors.textTertiary.withValues(alpha: 0.4),
        child: const SizedBox(height: 1),
      ),
    );

    return Row(
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'OR',
            style: AppTextStyles.xsMedium
                .withColor(AppColors.textTertiary)
                .copyWith(letterSpacing: 1.2),
          ),
        ),
        line(),
      ],
    );
  }
}

class _BrowseWithoutAccountButton extends StatelessWidget {
  const _BrowseWithoutAccountButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => context.read<AuthCubit>().continueAsGuest(),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48.0),
          foregroundColor: AppColors.textPrimary,
        ),
        child: Text(
          'Browse without an account',
          style: AppTextStyles.mdMedium.withColor(AppColors.textPrimary),
        ),
      ),
    );
  }
}
