import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../domain/services/achievements_service.dart';
import '../cubit/settings_cubit.dart';
import 'achievements_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  String get _appVersionString {
    if (_packageInfo == null) return 'Version 1.0.0 (100)';
    return 'Version ${_packageInfo!.version} (${_packageInfo!.buildNumber.isNotEmpty ? _packageInfo!.buildNumber : '1'})';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final authState = context.watch<AuthCubit>().state;
    final isAuthenticated = authState is Authenticated;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Settings',
          style: AppTextStyles.xl.copyWith(
            color: isLight
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        children: [
          // 0. ACCOUNT SECTION
          _buildSectionHeader('ACCOUNT'),
          _buildSectionCard(
            children: [
              Builder(
                builder: (context) {
                  final movieState = context.watch<MovieWatchlistCubit>().state;
                  final showState = context.watch<TvShowWatchlistCubit>().state;
                  final movies = movieState is MovieWatchlistSuccess
                      ? movieState.movies
                      : <Map<String, dynamic>>[];
                  final shows = showState is TvShowWatchlistSuccess
                      ? showState.shows
                      : <Map<String, dynamic>>[];
                  final achievements = AchievementsService.evaluate(
                    movies: movies,
                    shows: shows,
                  );
                  final unlocked =
                      achievements.where((a) => a.isUnlocked).length;
                  final total = achievements.length;

                  return _SettingsTile(
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFFFFD700),
                    iconBgColor: const Color(0xFFFFD700).withValues(alpha: 0.14),
                    title: 'Achievements',
                    subtitle: 'Track your milestones and badges',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unlocked / $total',
                            style: AppTextStyles.xsMedium.copyWith(
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.isLight
                              ? AppColors.lightTextTertiary
                              : const Color(0xFF8E8E93).withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AchievementsPage(),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),

          // 1. NOTIFICATIONS SECTION
          _buildSectionHeader('NOTIFICATIONS'),
          _buildSectionCard(
            children: [
              BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, settingsState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Push Notifications',
                        subtitle: 'Get alerted 1 hour before releases',
                        trailing: Switch.adaptive(
                          value: settingsState.notificationsEnabled,
                          activeTrackColor: AppColors.primary,
                          activeThumbColor: Colors.white,
                          onChanged: (value) {
                            HapticFeedback.lightImpact();
                            context.read<SettingsCubit>().toggleNotifications(value);
                          },
                        ),
                      ),
                      if (settingsState.notificationsEnabled) ...[
                        _buildDivider(),
                        _SettingsTile(
                          icon: Icons.calendar_today_outlined,
                          title: '1 Day Before Release',
                          subtitle: 'Get an extra reminder 24 hours in advance',
                          trailing: Switch.adaptive(
                            value: settingsState.notify1DayBefore,
                            activeTrackColor: AppColors.primary,
                            activeThumbColor: Colors.white,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              context.read<SettingsCubit>().toggleNotify1DayBefore(value);
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),

          // 2. APPEARANCE SECTION
          _buildSectionHeader('APPEARANCE'),
          _buildSectionCard(
            children: [
              BlocBuilder<ThemeCubit, ThemeState>(
                builder: (context, themeState) {
                  final themeText = switch (themeState.themeMode) {
                    ThemeMode.system => 'System',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.light => 'Light',
                  };

                  return _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'Choose light, dark or system theme',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          themeText,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () => _showThemeSelectionSheet(
                      context,
                      themeState.themeMode,
                    ),
                  );
                },
              ),
            ],
          ),

          // 3. PRIVACY SECTION
          _buildSectionHeader('PRIVACY'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () => _showPrivacyPolicySheet(context),
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Data & Privacy',
                subtitle: 'Manage your data and privacy preferences',
                onTap: () => _showDataPrivacySheet(context),
              ),
            ],
          ),

          // 4. DATA SOURCES SECTION
          _buildSectionHeader('DATA SOURCES'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                customIcon: _buildTmdbBadge(),
                title: 'TMDB',
                subtitle: 'Movie & TV information powered by TMDB',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'View Attribution',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                  ],
                ),
                onTap: () => _showTmdbAttributionSheet(context),
              ),
            ],
          ),

          // 5. LEGAL SECTION
          _buildSectionHeader('LEGAL'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Read our terms and conditions',
                onTap: () => _showTermsSheet(context),
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.code_rounded,
                title: 'Open Source Licenses',
                subtitle: 'Third-party licenses and attributions',
                onTap: () {
                  HapticFeedback.lightImpact();
                  showLicensePage(
                    context: context,
                    applicationName: 'PopVerse',
                    applicationVersion: _packageInfo?.version ?? '1.0.0',
                    applicationLegalese: '© 2026 PopVerse. All rights reserved.',
                  );
                },
              ),
            ],
          ),

          // 6. HELP & SUPPORT SECTION
          _buildSectionHeader('HELP & SUPPORT'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                icon: Icons.headphones_outlined,
                title: 'Contact Support',
                subtitle: 'Get help from our support team',
                onTap: () => _launchSupportEmail(context),
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.warning_amber_rounded,
                title: 'Report a Problem',
                subtitle: 'Let us know if something isn\'t working',
                onTap: () => _showReportProblemSheet(context),
              ),
            ],
          ),

          // 7. ABOUT SECTION
          _buildSectionHeader('ABOUT'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About Popverse',
                subtitle: _appVersionString,
                onTap: () => _showAboutSheet(context),
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.system_update_rounded,
                title: 'Check for Updates',
                subtitle: 'Check for latest features and enhancements',
                onTap: () => AppUpdateService.instance.checkForUpdatesManual(context),
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.star_outline_rounded,
                title: 'Rate Popverse',
                subtitle: 'Enjoying Popverse? Rate us on the App Store',
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  color: AppColors.primaryLight,
                  size: 18,
                ),
                onTap: () => _launchAppRating(context),
              ),
            ],
          ),

          // 8. DANGER ZONE SECTION
          if (isAuthenticated) ...[
            _buildSectionHeader('DANGER ZONE', color: AppColors.error),
            _buildSectionCard(
              children: [
                _SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppColors.error,
                  iconBgColor: AppColors.error.withValues(alpha: 0.12),
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data',
                  onTap: () => _showDeleteAccountSheet(context),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4.0,
        top: 20.0,
        bottom: 8.0,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: color ??
              (context.isLight
                  ? AppColors.lightTextSecondary
                  : const Color(0xFF8E8E93)),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    final isLight = context.isLight;
    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isLight
              ? AppColors.borderLight
              : Colors.white.withValues(alpha: 0.04),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    final isLight = context.isLight;
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 64,
      endIndent: 16,
      color: isLight
          ? AppColors.borderLight
          : Colors.white.withValues(alpha: 0.05),
    );
  }

  Widget _buildTmdbBadge() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF032541),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: const Center(
        child: Text(
          'TM\nDB',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF01B4E4),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            height: 0.95,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // --- ACTIONS & SHEETS ---

  void _showThemeSelectionSheet(BuildContext context, ThemeMode currentMode) {
    HapticFeedback.lightImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.grey[300] : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Appearance',
                  style: AppTextStyles.lg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how Popverse looks on your device',
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildThemeOption(
                  context: context,
                  title: 'System',
                  subtitle: 'Match your device light / dark setting',
                  icon: Icons.brightness_auto_outlined,
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<ThemeCubit>().setThemeMode(ThemeMode.system);
                    Navigator.pop(sheetContext);
                  },
                ),
                _buildThemeOption(
                  context: context,
                  title: 'Dark Theme',
                  subtitle: 'Always use dark interface',
                  icon: Icons.dark_mode_outlined,
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<ThemeCubit>().setThemeMode(ThemeMode.dark);
                    Navigator.pop(sheetContext);
                  },
                ),
                _buildThemeOption(
                  context: context,
                  title: 'Light Theme',
                  subtitle: 'Always use light interface',
                  icon: Icons.light_mode_outlined,
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<ThemeCubit>().setThemeMode(ThemeMode.light);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isLight = context.isLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : (isLight ? Colors.grey[100] : Colors.white.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isLight ? AppColors.borderLight : Colors.white.withValues(alpha: 0.06)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : (isLight ? AppColors.lightTextPrimary : AppColors.textPrimary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : (isLight ? AppColors.lightTextPrimary : AppColors.textPrimary),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          isSelected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: isSelected
              ? AppColors.primary
              : (isLight ? Colors.grey[400] : Colors.white24),
          size: 22,
        ),
        onTap: onTap,
      ),
    );
  }



  void _showDeleteAccountSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppColors.error,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Delete Account?',
                  style: AppTextStyles.lg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be erased.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isLight
                                ? AppColors.borderLight
                                : Colors.white24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isLight
                                ? AppColors.lightTextPrimary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                          context.read<AuthCubit>().deleteAccount();
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrivacyPolicySheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isLight ? Colors.grey[300] : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Privacy Policy',
                      style: AppTextStyles.xl.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Last updated: August 2026',
                      style: AppTextStyles.xs.copyWith(
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildTextParagraph(
                      'PopVerse respects your privacy and is committed to protecting your personal data.',
                    ),
                    _buildSubheading('1. Information We Collect'),
                    _buildTextParagraph(
                      '• Account Information: When you create an account, we store your email address and display name.\n• Watchlist & History: Shows and movies you add, mark as watched, or rate are securely stored in your personal profile.\n• Preferences: Your theme, notification, and app settings are stored locally on your device.',
                    ),
                    _buildSubheading('2. How We Use Information'),
                    _buildTextParagraph(
                      'We use your data strictly to provide, synchronize, and improve your tracking experience, deliver release notifications, and compute watch statistics.',
                    ),
                    _buildSubheading('3. Third-Party Services'),
                    _buildTextParagraph(
                      'We use TMDB for metadata and Firebase for secure authentication and cloud synchronization. We do not sell your personal data or track you across third-party apps.',
                    ),
                    _buildSubheading('4. Contact Us'),
                    _buildTextParagraph(
                      'If you have questions about this Privacy Policy, please contact us at support@popverse.app.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDataPrivacySheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.grey[300] : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Data & Privacy',
                      style: AppTextStyles.lg.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your watch history and library items are stored securely and encrypted in Google Cloud Firestore.',
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInfoBullet('Zero tracking cookies or cross-app identifiers'),
                _buildInfoBullet('Watchlist data is never sold or shared with advertisers'),
                _buildInfoBullet('Instant and permanent data deletion upon request'),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got It'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTmdbAttributionSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTmdbBadge(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The Movie Database (TMDb)',
                  style: AppTextStyles.lg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This product uses the TMDB API but is not endorsed or certified by TMDB. All movie, TV show, episode, and cast metadata and imagery are provided courtesy of TMDB.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Visit TMDb Website'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF01B4E4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final url = Uri.parse('https://www.themoviedb.org');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTermsSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isLight ? Colors.grey[300] : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Terms & Conditions',
                      style: AppTextStyles.xl.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Effective Date: August 2026',
                      style: AppTextStyles.xs.copyWith(
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSubheading('1. Acceptance of Terms'),
                    _buildTextParagraph(
                      'By using PopVerse, you agree to these Terms and Conditions. If you disagree with any part of these terms, please discontinue using the application.',
                    ),
                    _buildSubheading('2. Use of Service'),
                    _buildTextParagraph(
                      'PopVerse is an entertainment tracking application designed to organize watchlists, receive release reminders, and view statistics.',
                    ),
                    _buildSubheading('3. Content Attribution'),
                    _buildTextParagraph(
                      'All titles, artwork, posters, and summaries are copyrighted by their respective studio owners and supplied via the TMDb API.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReportProblemSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.grey[300] : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Report a Problem',
                  style: AppTextStyles.lg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Let us know if something isn\'t working as expected',
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email Support (support@popverse.app)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _launchSupportEmail(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAboutSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final isLight = context.isLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1D2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.movie_filter_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'PopVerse',
                  style: AppTextStyles.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _appVersionString,
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your premier destination for movie and TV show tracking, episode countdowns, and watch habits analysis.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Made with ♥️ by MWStudio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchSupportEmail(BuildContext context) async {
    HapticFeedback.lightImpact();
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@popverse.app',
      query: 'subject=PopVerse Support ($_appVersionString)',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (context.mounted) {
          AppSnackbar.showInfo(
            context,
            'Support email: support@popverse.app',
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showInfo(
          context,
          'Support email: support@popverse.app',
        );
      }
    }
  }

  Future<void> _launchAppRating(BuildContext context) async {
    HapticFeedback.lightImpact();
    final Uri ratingUri = Uri.parse(
      'https://apps.apple.com',
    );
    try {
      if (await canLaunchUrl(ratingUri)) {
        await launchUrl(ratingUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildSubheading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildTextParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: context.isLight
              ? AppColors.lightTextSecondary
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: context.isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    this.icon,
    this.customIcon,
    this.iconColor,
    this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          child: Row(
            children: [
              customIcon ??
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor ??
                          (isLight
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.14)),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: iconColor ?? AppColors.primaryLight,
                        size: 20,
                      ),
                    ),
                  ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : const Color(0xFF8E8E93),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isLight
                        ? AppColors.lightTextTertiary
                        : const Color(0xFF8E8E93).withValues(alpha: 0.7),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
