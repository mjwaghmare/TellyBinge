import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_icon_option.dart';
import '../../../../core/network/tmdb_cache_manager.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/services/app_icon_service.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../../core/utils/username_helper.dart';
import '../../../../core/widgets/app_confirm_sheet.dart';
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
import '../../domain/services/cinema_passport_service.dart';
import '../widgets/cinema_passport_modal.dart';
import 'terms_and_conditions_page.dart';
import 'privacy_policy_page.dart';
import '../../../feedback/presentation/pages/feedback_board_page.dart';
import '../widgets/app_icon_selection_bottom_sheet.dart';
import '../widgets/mw_studio_footer.dart';
import '../widgets/theme_selection_bottom_sheet.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PackageInfo? _packageInfo;
  int? _cacheSizeBytes;
  bool _isClearingCache = false;
  AppIconOption _selectedAppIcon = AppIconOption.defaultIcon;

  /// Set to true once the app is published and store IDs are configured.
  bool get _isAppRatingEnabled => false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadCacheSize();
    _loadAppIcon();
  }

  Future<void> _loadAppIcon() async {
    final icon = await AppIconService().getCurrentIcon();
    if (mounted) {
      setState(() {
        _selectedAppIcon = icon;
      });
    }
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  Future<void> _loadCacheSize() async {
    try {
      int totalBytes = 0;

      // 1. TMDB metadata cache
      totalBytes += await TmdbCacheManager.instance.getCacheSizeBytes();

      // 2. DefaultCacheManager image cache (libCachedImageData)
      final tempDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (await imageCacheDir.exists()) {
        await for (final entity in imageCacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      if (mounted) {
        setState(() {
          _cacheSizeBytes = totalBytes;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cacheSizeBytes = 0;
        });
      }
    }
  }

  String _formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                  color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Settings',
          style: AppTextStyles.xl.copyWith(
            color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        children: [
          // 1. APPEARANCE SECTION
          _buildSectionHeader('APPEARANCE & INTERACTION'),
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
                          style: AppTextStyles.smMedium.copyWith(
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.primaryLight, size: 20),
                      ],
                    ),
                    onTap: () => ThemeSelectionBottomSheet.show(context),
                  );
                },
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.app_shortcut_rounded,
                title: 'App Icon',
                subtitle: 'Personalize your home screen icon',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isLight ? AppColors.borderLight : AppColors.borderDark,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          _selectedAppIcon.previewAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.crop_square_rounded,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _selectedAppIcon.title,
                      style: AppTextStyles.smMedium.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primaryLight, size: 20),
                  ],
                ),
                onTap: () async {
                  await AppIconSelectionBottomSheet.show(context);
                  await _loadAppIcon();
                },
              ),
              _buildDivider(),
              BlocBuilder<SettingsCubit, SettingsState>(
                buildWhen: (previous, current) =>
                    previous.hapticsEnabled != current.hapticsEnabled,
                builder: (context, settingsState) {
                  return _SettingsTile(
                    icon: Icons.vibration_rounded,
                    title: 'Haptic Feedback',
                    subtitle: 'Vibrate on taps and gestures',
                    trailing: Switch.adaptive(
                      value: settingsState.hapticsEnabled,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: AppColors.textOnPrimary,
                      onChanged: (value) {
                        AppHaptics.lightImpact();
                        context.read<SettingsCubit>().toggleHaptics(value);
                      },
                    ),
                  );
                },
              ),
              _buildDivider(),
              BlocBuilder<SettingsCubit, SettingsState>(
                buildWhen: (previous, current) =>
                    previous.reducedMotion != current.reducedMotion,
                builder: (context, settingsState) {
                  return _SettingsTile(
                    icon: Icons.motion_photos_off_outlined,
                    title: 'Reduce Motion',
                    subtitle: 'Reduce motion and micro-animations',
                    trailing: Switch.adaptive(
                      value: settingsState.reducedMotion,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: AppColors.textOnPrimary,
                      onChanged: (value) {
                        AppHaptics.lightImpact();
                        context.read<SettingsCubit>().toggleReducedMotion(value);
                      },
                    ),
                  );
                },
              ),
            ],
          ),

          // 2. NOTIFICATIONS SECTION
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
                          activeThumbColor: AppColors.textOnPrimary,
                          onChanged: (value) {
                            AppHaptics.lightImpact();
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
                            activeThumbColor: AppColors.textOnPrimary,
                            onChanged: (value) {
                              AppHaptics.lightImpact();
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

          // 3. ACHIEVEMENTS & PASSPORT SECTION
          _buildSectionHeader('ACHIEVEMENTS & PASSPORT'),
          _buildSectionCard(
            children: [
              Builder(
                builder: (context) {
                  final movieState = context.watch<MovieWatchlistCubit>().state;
                  final showState = context.watch<TvShowWatchlistCubit>().state;
                  final movies = movieState is MovieWatchlistSuccess ? movieState.movies : <Map<String, dynamic>>[];
                  final shows = showState is TvShowWatchlistSuccess ? showState.shows : <Map<String, dynamic>>[];
                  final achievements = AchievementsService.evaluate(movies: movies, shows: shows);
                  final unlocked = achievements.where((a) => a.isUnlocked).length;
                  final total = achievements.length;

                  return _SettingsTile(
                    icon: Icons.emoji_events_rounded,
                    iconColor: AppColors.gold,
                    iconBgColor: AppColors.gold.withValues(alpha: 0.14),
                    title: 'Achievements',
                    subtitle: 'Track your milestones and badges',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.micro),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unlocked / $total',
                            style: AppTextStyles.xsMedium.copyWith(color: AppColors.primaryLight),
                          ),
                        ),
                        AppSpacing.gapW4,
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.isLight
                              ? AppColors.lightTextTertiary
                              : AppColors.textTertiary.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () {
                      AppHaptics.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsPage()));
                    },
                  );
                },
              ),
              _buildDivider(),
              Builder(
                builder: (context) {
                  final movieState = context.watch<MovieWatchlistCubit>().state;
                  final showState = context.watch<TvShowWatchlistCubit>().state;
                  final movies = movieState is MovieWatchlistSuccess ? movieState.movies : <Map<String, dynamic>>[];
                  final shows = showState is TvShowWatchlistSuccess ? showState.shows : <Map<String, dynamic>>[];
                  final passport = CinemaPassportService.evaluate(movies: movies, shows: shows);
                  final authState = context.watch<AuthCubit>().state;
                  final user = authState is Authenticated ? authState.user : null;
                  final username = generateUsername(user?.displayName, fallback: 'cinephile');

                  return _SettingsTile(
                    icon: Icons.public_rounded,
                    iconColor: AppColors.gold,
                    iconBgColor: AppColors.gold.withValues(alpha: 0.14),
                    title: 'World Cinema Passport',
                    subtitle: 'Your international film journey & stamps',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.micro),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${passport.totalCountries} ${passport.totalCountries == 1 ? 'Country' : 'Countries'}',
                            style: AppTextStyles.xsMedium.copyWith(
                              color: isLight ? const Color(0xFFB45309) : AppColors.gold,
                            ),
                          ),
                        ),
                        AppSpacing.gapW4,
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isLight
                              ? AppColors.lightTextTertiary
                              : AppColors.textTertiary.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () {
                      AppHaptics.lightImpact();
                      CinemaPassportModal.show(
                        context,
                        data: passport,
                        username: username,
                      );
                    },
                  );
                },
              ),
            ],
          ),

          // 4. DATA & STORAGE SECTION
          _buildSectionHeader('DATA & STORAGE'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                icon: Icons.storage_rounded,
                iconColor: AppColors.skyBlue,
                iconBgColor: AppColors.skyBlue.withValues(alpha: 0.14),
                title: 'Clear Cache',
                subtitle: _isClearingCache
                    ? 'Clearing cache...'
                    : _cacheSizeBytes != null
                    ? 'Images & metadata — ${_formatCacheSize(_cacheSizeBytes!)}'
                    : 'Calculating...',
                trailing: _isClearingCache
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2.0))
                    : _cacheSizeBytes != null && _cacheSizeBytes! > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Clear', style: AppTextStyles.xsMedium.copyWith(color: AppColors.primaryLight)),
                      )
                    : Icon(
                        Icons.check_circle_outline_rounded,
                        color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                onTap: _cacheSizeBytes != null && _cacheSizeBytes! > 0 && !_isClearingCache
                    ? () => _clearCache(context)
                    : null,
              ),
            ],
          ),

          // 5. HELP & SUPPORT SECTION
          _buildSectionHeader('HELP & SUPPORT'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                icon: Icons.forum_outlined,
                title: 'Feedback & Requests',
                subtitle: 'Report bugs, suggest features & upvote ideas',
                onTap: () {
                  AppHaptics.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackBoardPage()));
                },
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.headphones_outlined,
                title: 'Contact Support',
                subtitle: 'Get help from our support team',
                onTap: () => _launchSupportEmail(context),
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.system_update_rounded,
                title: 'Check for Updates',
                subtitle: 'Check for latest features and enhancements',
                onTap: () => AppUpdateService.instance.checkForUpdatesManual(context),
              ),
              // Hidden for now until app is published on stores; flip to true when ready
              if (_isAppRatingEnabled) ...[
                _buildDivider(),
                _SettingsTile(
                  icon: Icons.star_outline_rounded,
                  title: 'Rate Popverse',
                  subtitle: defaultTargetPlatform == TargetPlatform.iOS
                      ? 'Enjoying Popverse? Rate us on the App Store'
                      : 'Enjoying Popverse? Rate us on Google Play',
                  trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.primaryLight, size: 18),
                  onTap: () => _launchAppRating(context),
                ),
              ],
            ],
          ),

          // 6. LEGAL & PRIVACY SECTION
          _buildSectionHeader('LEGAL & PRIVACY'),
          _buildSectionCard(
            children: [
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Read our terms and conditions',
                onTap: () {
                  AppHaptics.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsAndConditionsPage(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () {
                  AppHaptics.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _SettingsTile(
                customIcon: _buildTmdbBadge(),
                title: 'TMDB',
                subtitle: 'Movie & TV information powered by TMDB',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Attribution',
                      style: AppTextStyles.xsMedium.copyWith(color: AppColors.primaryLight, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primaryLight, size: 20),
                  ],
                ),
                onTap: () => _showTmdbAttributionSheet(context),
              ),
              _buildDivider(),
              _SettingsTile(
                icon: Icons.code_rounded,
                title: 'Open Source Licenses',
                subtitle: 'Third-party licenses and attributions',
                onTap: () {
                  AppHaptics.lightImpact();
                  showLicensePage(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: _packageInfo?.version ?? AppConstants.defaultAppVersion,
                    applicationLegalese: AppConstants.appLegalese,
                  );
                },
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

          const SizedBox(height: AppSpacing.lg),
          MWStudioFooter(
            appVersion: _packageInfo?.version,
            buildNumber: _packageInfo?.buildNumber,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs, top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Text(
        title,
        style: AppTextStyles.xsMedium.copyWith(
          color: color ?? (context.isLight ? AppColors.lightTextSecondary : AppColors.textTertiary),
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
        color: isLight ? AppColors.lightSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: isLight ? AppColors.borderLight : AppColors.borderDark, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildDivider() {
    final isLight = context.isLight;
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 64,
      endIndent: 16,
      color: isLight ? AppColors.borderLight : AppColors.borderDark,
    );
  }

  Widget _buildTmdbBadge() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: AppColors.tmdbDarkBlue, borderRadius: BorderRadius.circular(10.0)),
      child: Center(
        child: Text(
          'TM\nDB',
          textAlign: TextAlign.center,
          style: AppTextStyles.xsBold.copyWith(
            color: AppColors.tmdbLightBlue,
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

  Future<void> _clearCache(BuildContext context) async {
    if (_isClearingCache) return;
    unawaited(AppHaptics.mediumImpact());
    setState(() {
      _isClearingCache = true;
    });

    try {
      await Future.wait([
        DefaultCacheManager().emptyCache(),
        TmdbCacheManager.instance.clearAll(),
        Future.delayed(const Duration(milliseconds: 500)),
      ]);

      // Also clear Flutter's in-memory image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Recalculate remaining cache size
      await _loadCacheSize();

      if (context.mounted) {
        AppSnackbar.showSuccess(context, 'Cache cleared successfully');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Failed to clear cache');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  void _showDeleteAccountSheet(BuildContext context) {
    AppHaptics.mediumImpact();
    AppConfirmSheet.show(
      context,
      icon: Icons.delete_forever_rounded,
      title: 'Delete Account?',
      message:
          'Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be erased.',
    ).then((confirmed) {
      if (!confirmed || !context.mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      context.read<AuthCubit>().deleteAccount();
    });
  }

  void _showTmdbAttributionSheet(BuildContext context) {
    AppHaptics.lightImpact();
    final isLight = context.isLight;

    AppBottomSheet.show(
      context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AppSheetHandle(),
                AppSpacing.gapH24,
                _buildTmdbBadge(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The Movie Database (TMDb)',
                  style: AppTextStyles.lg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This product uses the TMDB API but is not endorsed or certified by TMDB. All movie, TV show, episode, and cast metadata and imagery are provided courtesy of TMDB.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sm.copyWith(
                    color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
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
                      backgroundColor: AppColors.tmdbLightBlue,
                      foregroundColor: AppColors.textOnPrimary,
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final url = Uri.parse(AppConstants.tmdbWebsiteUrl);
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


  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _launchSupportEmail(BuildContext context) async {
    unawaited(AppHaptics.lightImpact());
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: _encodeQueryParameters(<String, String>{
        'subject': '${AppConstants.supportEmailSubjectPrefix} ($_appVersionString)',
      }),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        final bool launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          _showNoMailAppSheet(context);
        }
      } else {
        if (context.mounted) {
          _showNoMailAppSheet(context);
        }
      }
    } catch (_) {
      if (context.mounted) {
        _showNoMailAppSheet(context);
      }
    }
  }

  void _showNoMailAppSheet(BuildContext context) {
    AppHaptics.mediumImpact();
    final isLight = context.isLight;

    AppBottomSheet.show(
      context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AppSheetHandle(),
                AppSpacing.gapH24,
                const AppSheetIcon(icon: Icons.mail_outline_rounded),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No Mail App Found',
                  style: AppTextStyles.lg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'We could not open an email app on this device. You can copy our support email address to contact us directly:',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sm.copyWith(
                    color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightBackground
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLight ? AppColors.borderLight : AppColors.borderDark,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.alternate_email_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          AppConstants.supportEmail,
                          style: AppTextStyles.smBold.copyWith(
                            color: isLight
                                ? AppColors.lightTextPrimary
                                : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      unawaited(AppHaptics.lightImpact());
                      await Clipboard.setData(
                        const ClipboardData(text: AppConstants.supportEmail),
                      );
                      if (bottomSheetContext.mounted) {
                        Navigator.pop(bottomSheetContext);
                      }
                      if (context.mounted) {
                        AppSnackbar.showSuccess(
                          context,
                          'Support email copied to clipboard!',
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Email Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.smMedium.copyWith(
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchAppRating(BuildContext context) async {
    unawaited(AppHaptics.lightImpact());

    // Set with Apple App ID from App Store Connect once live (e.g. '6740000000')
    const String appleAppId = AppConstants.appleAppId;
    final String packageName = _packageInfo?.packageName ?? AppConstants.defaultPackageName;

    final Uri primaryUri;
    final Uri fallbackUri;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      primaryUri = Uri.parse('${AppConstants.appStoreReviewScheme}$appleAppId?action=write-review');
      fallbackUri = Uri.parse('${AppConstants.appStoreBaseUrl}$appleAppId?action=write-review');
    } else {
      primaryUri = Uri.parse('${AppConstants.playStoreMarketScheme}$packageName');
      fallbackUri = Uri.parse('${AppConstants.playStoreBaseUrl}$packageName');
    }

    try {
      if (await canLaunchUrl(primaryUri)) {
        await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch store review: $e');
    }
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              customIcon ??
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                          iconBgColor ??
                          (isLight
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.14)),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Center(child: Icon(icon, color: iconColor ?? AppColors.primaryLight, size: 20)),
                  ),
              AppSpacing.gapW12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.smMedium.copyWith(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: AppTextStyles.xs.copyWith(
                        fontSize: 12.5,
                        color: isLight ? AppColors.lightTextSecondary : AppColors.textTertiary,
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
                    color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary.withValues(alpha: 0.7),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
