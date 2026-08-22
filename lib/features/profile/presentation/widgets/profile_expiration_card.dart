import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A card widget displaying a live reverse countdown timer for the 6-day
/// free Apple Developer provisioning profile expiration.
class ProfileExpirationCard extends StatefulWidget {
  const ProfileExpirationCard({super.key});

  @override
  State<ProfileExpirationCard> createState() => _ProfileExpirationCardState();
}

class _ProfileExpirationCardState extends State<ProfileExpirationCard> {
  DateTime? _expirationDate;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpirationDate();
  }

  Future<void> _loadExpirationDate() async {
    final expirationDate = await NotificationService().getProfileExpirationDate();
    if (!mounted) return;
    setState(() {
      _expirationDate = expirationDate;
      _isLoading = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _expirationDate == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final difference = _expirationDate!.difference(now);
    final isExpired = difference.isNegative || difference.inSeconds <= 0;

    final days = isExpired ? 0 : difference.inDays;
    final hours = isExpired ? 0 : (difference.inHours % 24);
    final minutes = isExpired ? 0 : (difference.inMinutes % 60);
    final seconds = isExpired ? 0 : (difference.inSeconds % 60);

    final isExpiringSoon = !isExpired && difference <= const Duration(hours: 24);

    final statusColor = isExpired
        ? AppColors.error
        : isExpiringSoon
        ? AppColors.primary
        : AppColors.success;

    final statusLabel = isExpired
        ? 'EXPIRED'
        : isExpiringSoon
        ? 'EXPIRING SOON'
        : 'ACTIVE';

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final digitBgColor = isDarkMode ? AppColors.surfaceElevated : Theme.of(context).colorScheme.surface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: statusColor, size: 20),
                  AppSpacing.gapW8,
                  Text(
                    'Profile Expiration',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          AppSpacing.gapH16,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeUnit(
                context: context,
                value: days.toString().padLeft(2, '0'),
                label: 'DAYS',
                bgColor: digitBgColor,
                accentColor: statusColor,
              ),
              _buildColon(context),
              _buildTimeUnit(
                context: context,
                value: hours.toString().padLeft(2, '0'),
                label: 'HOURS',
                bgColor: digitBgColor,
                accentColor: statusColor,
              ),
              _buildColon(context),
              _buildTimeUnit(
                context: context,
                value: minutes.toString().padLeft(2, '0'),
                label: 'MINS',
                bgColor: digitBgColor,
                accentColor: statusColor,
              ),
              _buildColon(context),
              _buildTimeUnit(
                context: context,
                value: seconds.toString().padLeft(2, '0'),
                label: 'SECS',
                bgColor: digitBgColor,
                accentColor: statusColor,
              ),
            ],
          ),
          AppSpacing.gapH16,
          Text(
            'Free 6-day Apple Developer provisioning profile. Connect to Xcode and rebuild before the timer reaches zero to prevent app launch failure.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit({
    required BuildContext context,
    required String value,
    required String label,
    required Color bgColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      constraints: const BoxConstraints(minWidth: 54),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.lg.withTabularFigures().copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildColon(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
