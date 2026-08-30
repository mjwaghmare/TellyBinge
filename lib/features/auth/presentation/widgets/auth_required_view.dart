import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// Reusable full-tab prompt displayed when a guest user navigates to a tab
/// requiring an account (e.g. Shows, Movies, Profile).
class AuthRequiredView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> features;

  const AuthRequiredView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
  });

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

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Header with glowing gradient container
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 40, color: AppColors.primary),
              ),
              AppSpacing.gapH24,

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.xl.withColor(textColor),
              ),
              AppSpacing.gapH12,

              // Subtitle
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.md
                    .withColor(textSecColor)
                    .copyWith(height: 1.4),
              ),
              AppSpacing.gapH24,

              // Feature Highlights Card
              if (features.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: AppSpacing.allMD,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < features.length; i++) ...[
                        if (i > 0) AppSpacing.gapH12,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: AppColors.brandGreen,
                            ),
                            AppSpacing.gapW12,
                            Expanded(
                              child: Text(
                                features[i],
                                style: AppTextStyles.smMedium.withColor(
                                  textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              AppSpacing.gapH32,

              // Sign-in CTA Button
              const AuthGoogleSignInButton(),
              AppSpacing.gapH16,
              Text(
                'Sync your progress seamlessly across devices.',
                textAlign: TextAlign.center,
                style: AppTextStyles.xs.withColor(AppColors.textTertiary),
              ),
            ],
          ),
        ),
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
                      'assets/images/google.png',
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
