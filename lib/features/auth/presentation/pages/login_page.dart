import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.allXL,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // App Logo
              Center(
                child: Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                  ),
                ),
              ),
              AppSpacing.gapH24,
              const Text(
                'Telly Binge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              AppSpacing.gapH12,
              const Text(
                'Track your progress, view release calendars, and join the community of TV show & movie lovers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              // Authentication UI states
              BlocConsumer<AuthCubit, AuthState>(
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
                  if (state is AuthLoading) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    );
                  }

                  final isLoading = state is AuthLoginLoading;

                  return ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            context.read<AuthCubit>().signInWithGoogle();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white70,
                      disabledForegroundColor: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLoading)
                          const CircularProgressIndicator.adaptive()
                        else ...[
                          // Google Icon Asset
                          Image.asset(
                            'assets/images/google.png',
                            width: 24,
                            height: 24,
                          ),
                          AppSpacing.gapW12,
                          Flexible(
                            child: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
              AppSpacing.gapH32,
              const Text(
                'By continuing, you agree to our Terms of Service.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              AppSpacing.gapH16,
            ],
          ),
        ),
      ),
    );
  }
}
