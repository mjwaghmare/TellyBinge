import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isDeleteExpanded = false;
  bool _isPauseExpanded = true;
  bool _isProcessing = false;

  void _showDeleteConfirmationDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authCubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              AppSpacing.gapW8,
              Expanded(
                child: Text(
                  'Delete Account?',
                  style: AppTextStyles.lg.copyWith(
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'This action is irreversible. All your watch history, watchlists, custom lists, and profile data will be permanently erased.',
            style: AppTextStyles.sm.copyWith(
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Keep Account',
                style: AppTextStyles.smBold.copyWith(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                setState(() => _isProcessing = true);
                try {
                  await authCubit.deleteAccount();
                  if (mounted) {
                    nav.popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error deleting account: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  void _onPauseAccount(BuildContext context) async {
    HapticFeedback.lightImpact();
    final authCubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() => _isProcessing = true);
    try {
      await authCubit.signOut();
      if (mounted) {
        nav.popUntil((route) => route.isFirst);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Account paused. You can log back in anytime!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error pausing account: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;

    final displayName = (user?.displayName.isNotEmpty == true)
        ? user!.displayName
        : 'there';
    final photoURL = user?.photoUrl;

    final movieWatchlistState = context.watch<MovieWatchlistCubit>().state;
    final tvWatchlistState = context.watch<TvShowWatchlistCubit>().state;

    int moviesAddedCount = 0;
    if (movieWatchlistState is MovieWatchlistSuccess) {
      moviesAddedCount = movieWatchlistState.movies.length;
    }

    int showsWatchedCount = 0;
    if (tvWatchlistState is TvShowWatchlistSuccess) {
      showsWatchedCount = tvWatchlistState.shows
          .where((s) => s['category'] == 'FINISHED' || s['category'] == 'UP_TO_DATE' || (s['watchedEpisodes'] as List?)?.isNotEmpty == true)
          .length;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Delete Account',
          style: AppTextStyles.lg.copyWith(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              // Top Stats Hero Card
              _buildTopStatsCard(
                moviesAddedCount: moviesAddedCount,
                showsWatchedCount: showsWatchedCount,
                displayName: displayName,
                photoURL: photoURL,
              ),
              AppSpacing.gapH24,

              // Personalized Message
              _buildEmpathyMessage(displayName: displayName, isDark: isDark),
              AppSpacing.gapH24,

              // Expandable Card 1: Are you sure you want to delete your account?
              _buildExpandableCard(
                context: context,
                title: 'Are you sure you want to delete your account?',
                isExpanded: _isDeleteExpanded,
                isDark: isDark,
                onToggle: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isDeleteExpanded = !_isDeleteExpanded);
                },
                content: Text(
                  'Deleting your account is permanent. All your data including watch history, watchlists, custom lists, ratings, and preferences will be permanently erased. This action cannot be undone.',
                  style: AppTextStyles.sm.copyWith(
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              AppSpacing.gapH16,

              // Expandable Card 2: Or, You can Pause your Account
              _buildExpandableCard(
                context: context,
                title: 'Or, You can Pause your Account',
                isExpanded: _isPauseExpanded,
                isDark: isDark,
                onToggle: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isPauseExpanded = !_isPauseExpanded);
                },
                content: Text(
                  'You can also pause your account and come back any time later. Keep your progress, streaks, and watchlists safe without losing anything.',
                  style: AppTextStyles.sm.copyWith(
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              AppSpacing.gapH32,

              // Action Buttons
              _buildActionButtons(context: context, isDark: isDark),
              AppSpacing.gapH32,
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopStatsCard({
    required int moviesAddedCount,
    required int showsWatchedCount,
    required String displayName,
    required String? photoURL,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B1E78),
            Color(0xFF5B21B6),
            Color(0xFF2E1065),
            Color(0xFF1E1035),
          ],
          stops: [0.0, 0.4, 0.8, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Background decorative subtle light glow circles
          Positioned(
            top: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            right: -15,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.xl,
              bottom: AppSpacing.xl + 28,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left Stat: Movies Added
                _buildCardStatItem(
                  iconWidget: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFFA726),
                    size: 26,
                  ),
                  iconBgColor: const Color(0xFF2A154A),
                  label: 'Movies Added',
                  value: moviesAddedCount.toString(),
                ),

                // Right Stat: Shows Watched
                _buildCardStatItem(
                  iconWidget: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFFFD54F),
                    size: 26,
                  ),
                  iconBgColor: const Color(0xFF2A154A),
                  label: 'Shows Watched',
                  value: showsWatchedCount.toString(),
                ),
              ],
            ),
          ),

          // Overlapping Profile Avatar at Bottom Center
          Positioned(
            bottom: -28,
            child: Container(
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF374151),
                  backgroundImage: (photoURL != null && photoURL.isNotEmpty)
                      ? CachedNetworkImageProvider(photoURL)
                      : null,
                  child: (photoURL == null || photoURL.isEmpty)
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: AppTextStyles.xl.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStatItem({
    required Widget iconWidget,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconBgColor,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Center(child: iconWidget),
        ),
        AppSpacing.gapH8,
        Text(
          label,
          style: AppTextStyles.xsMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        AppSpacing.gapH4,
        Text(
          value,
          style: AppTextStyles.lg.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ).withTabularFigures(),
        ),
      ],
    );
  }

  Widget _buildEmpathyMessage({
    required String displayName,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey $displayName,',
                  style: AppTextStyles.mdBold.copyWith(
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                AppSpacing.gapH4,
                Text(
                  'You have been doing great!',
                  style: AppTextStyles.smMedium.copyWith(
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                AppSpacing.gapH4,
                Text(
                  'We are sad to see you go',
                  style: AppTextStyles.smMedium.copyWith(
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapW16,
          // Sad Emoji Icon
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFCC00),
            ),
            child: const Center(
              child: Text(
                '🙁',
                style: TextStyle(fontSize: 32, height: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCard({
    required BuildContext context,
    required String title,
    required bool isExpanded,
    required bool isDark,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    final cardBg = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.mdBold.copyWith(
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    AppSpacing.gapW8,
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: content,
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pause My Account Button (Primary Violet)
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26.0),
              ),
            ),
            onPressed: _isProcessing ? null : () => _onPauseAccount(context),
            child: Text(
              'Pause my account',
              style: AppTextStyles.mdBold.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
        AppSpacing.gapH16,

        // Delete My Account Button (Outlined)
        SizedBox(
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDark ? const Color(0xFF6B5599) : const Color(0xFF7C3AED),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26.0),
              ),
            ),
            onPressed: _isProcessing ? null : () => _showDeleteConfirmationDialog(context),
            child: Text(
              'Delete my account',
              style: AppTextStyles.mdBold.copyWith(
                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
