import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../domain/models/cinema_passport.dart';
import 'passport_stamp_widget.dart';

/// Modal bottom sheet showcasing the user's authentic World Cinema Passport.
class CinemaPassportModal extends StatefulWidget {
  final CinemaPassportData data;
  final String username;
  final String? rankTitle;

  const CinemaPassportModal({
    super.key,
    required this.data,
    required this.username,
    this.rankTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required CinemaPassportData data,
    required String username,
    String? rankTitle,
  }) {
    AppHaptics.selectionClick();
    return AppBottomSheet.show<void>(
      context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CinemaPassportModal(
        data: data,
        username: username,
        rankTitle: rankTitle,
      ),
    );
  }

  @override
  State<CinemaPassportModal> createState() => _CinemaPassportModalState();
}

class _CinemaPassportModalState extends State<CinemaPassportModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _sharePassport() {
    AppHaptics.mediumImpact();
    final data = widget.data;
    final topCountries = data.countries
        .take(5)
        .map((c) => '${c.flagEmoji} ${c.name} (${c.totalTitles})')
        .join('\n');

    final text =
        '🛂 My World Cinema Passport on PopVerse! 🌍🎬\n\n'
        '• ${data.totalCountries} Countries Visited Through Cinema\n'
        '• ${data.unlockedStampsCount}/${data.totalStampsCount} Passport Stamps Unlocked\n'
        '• ${data.totalTitles} Total Titles Logged\n\n'
        'Top Destinations:\n$topCountries\n\n'
        'Track your global cinema journey:\n'
        '🍎 iOS: ${AppConstants.appStoreUrl}\n'
        '🤖 Android: ${AppConstants.playStoreUrl}';

    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'PopVerse World Cinema Passport • @${widget.username}',
      ),
    );
  }

  void _showStampDetails(PassportStamp stamp) {
    final isLight = context.isLight;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isLight
          ? AppColors.lightSurfaceElevated
          : AppColors.surfaceElevated,
      shape: AppBottomSheet.shape,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: PassportStampWidget(
                  stamp: stamp,
                  size: 140,
                ),
              ),
              AppSpacing.gapH16,
              Text(
                '${stamp.flagEmoji} ${stamp.title}',
                style: AppTextStyles.lg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              AppSpacing.gapH4,
              Text(
                stamp.subtitle,
                style: AppTextStyles.xsBold.copyWith(
                  color: stamp.inkColor,
                  letterSpacing: 1.0,
                ),
              ),
              AppSpacing.gapH12,
              Text(
                stamp.description,
                textAlign: TextAlign.center,
                style: AppTextStyles.smMedium.copyWith(
                  color: isLight
                      ? AppColors.lightTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              AppSpacing.gapH16,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: stamp.isUnlocked
                      ? stamp.inkColor.withValues(alpha: 0.12)
                      : (isLight
                          ? AppColors.borderLight
                          : Colors.white.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stamp.isUnlocked
                      ? (stamp.unlockedDate != null
                          ? '✓ STAMPED ON ${stamp.unlockedDate}'
                          : '✓ VERIFIED ENTRY')
                      : 'PROGRESS: ${stamp.currentCount} / ${stamp.requiredCount} TITLES',
                  style: AppTextStyles.xsBold.copyWith(
                    color: stamp.isUnlocked
                        ? stamp.inkColor
                        : (isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textTertiary),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              AppSpacing.gapH16,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final data = widget.data;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isLight
                ? AppColors.lightSurfaceElevated
                : AppColors.surfaceElevated,
            borderRadius: AppBottomSheet.borderRadius,
          ),
          child: Column(
            children: [
              // Top drag bar handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.borderLight
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Passport Header Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLight
                          ? [
                              const Color(0xFFFAF5FF),
                              const Color(0xFFF3E8FF),
                            ]
                          : [
                              const Color(0xFF1E1736),
                              const Color(0xFF140F26),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFFBBF24),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.public_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              AppSpacing.gapW12,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WORLD CINEMA PASSPORT',
                                    style: AppTextStyles.xsBold.copyWith(
                                      color: AppColors.gold,
                                      letterSpacing: 1.2,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                  Text(
                                    '@${widget.username}',
                                    style: AppTextStyles.smBold.copyWith(
                                      color: isLight
                                          ? AppColors.lightTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (widget.rankTitle != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                widget.rankTitle!,
                                style: AppTextStyles.xsBold.copyWith(
                                  color: AppColors.primaryLight,
                                  fontSize: 8.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      AppSpacing.gapH16,
                      // 3 Summary Metrics
                      Row(
                        children: [
                          _buildMetric(
                            icon: Icons.flight_takeoff_rounded,
                            value: '${data.totalCountries}',
                            label: 'Countries',
                            isLight: isLight,
                          ),
                          _buildDivider(isLight),
                          _buildMetric(
                            icon: Icons.approval_rounded,
                            value:
                                '${data.unlockedStampsCount}/${data.totalStampsCount}',
                            label: 'Stamps',
                            isLight: isLight,
                          ),
                          _buildDivider(isLight),
                          _buildMetric(
                            icon: Icons.movie_filter_outlined,
                            value: '${data.totalTitles}',
                            label: 'Titles Logged',
                            isLight: isLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              AppSpacing.gapH8,

              // Tab Bar (Stamps vs Countries)
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
                unselectedLabelColor: isLight
                    ? AppColors.lightTextTertiary
                    : AppColors.textTertiary,
                labelStyle: AppTextStyles.xsBold.copyWith(letterSpacing: 0.5),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: 'STAMPS (${data.unlockedStampsCount}/${data.totalStampsCount})'),
                  Tab(text: 'DESTINATIONS (${data.totalCountries})'),
                ],
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Authentic Stamps Grid
                    _buildStampsView(scrollController, isLight),

                    // Tab 2: Country Leaderboard List
                    _buildCountriesView(isLight),
                  ],
                ),
              ),

              // Bottom Share CTA Button
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _sharePassport,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share_rounded, size: 18),
                        AppSpacing.gapW8,
                        Text(
                          'SHARE MY PASSPORT',
                          style: AppTextStyles.smBold.copyWith(
                            color: Colors.black87,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStampsView(ScrollController scrollController, bool isLight) {
    final stamps = widget.data.stamps;

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.95,
      ),
      itemCount: stamps.length,
      itemBuilder: (context, index) {
        final stamp = stamps[index];
        return Center(
          child: PassportStampWidget(
            stamp: stamp,
            size: 145,
            onTap: () => _showStampDetails(stamp),
          ),
        );
      },
    );
  }

  Widget _buildCountriesView(bool isLight) {
    final countries = widget.data.countries;

    if (countries.isEmpty) {
      return Center(
        child: Text(
          'No countries logged yet. Start watching!',
          style: AppTextStyles.smMedium.copyWith(
            color: isLight
                ? AppColors.lightTextSecondary
                : AppColors.textTertiary,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: countries.length,
      separatorBuilder: (_, _) => AppSpacing.gapH8,
      itemBuilder: (context, index) {
        final visit = countries[index];
        final percent = widget.data.totalTitles > 0
            ? (visit.totalTitles / widget.data.totalTitles)
            : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isLight
                ? AppColors.lightSurface
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLight
                  ? AppColors.borderLight
                  : AppColors.borderDark,
            ),
          ),
          child: Row(
            children: [
              Text(
                visit.flagEmoji,
                style: const TextStyle(fontSize: 24),
              ),
              AppSpacing.gapW12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.name,
                      style: AppTextStyles.smBold.copyWith(
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${visit.movieCount} Movies • ${visit.showCount} Shows',
                      style: AppTextStyles.xsMedium.copyWith(
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${visit.totalTitles}',
                    style: AppTextStyles.mdBold.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                  Text(
                    '${(percent * 100).toStringAsFixed(1)}%',
                    style: AppTextStyles.xsBold.copyWith(
                      color: isLight
                          ? AppColors.lightTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String value,
    required String label,
    required bool isLight,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTextStyles.smBold.copyWith(
              color: isLight
                  ? AppColors.lightTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.xsBold.copyWith(
              color: isLight
                  ? AppColors.lightTextSecondary
                  : AppColors.textTertiary,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isLight) {
    return Container(
      width: 1,
      height: 28,
      color: isLight
          ? AppColors.borderLight
          : Colors.white.withValues(alpha: 0.12),
    );
  }
}
