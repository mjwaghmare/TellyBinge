import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'package:flutter/services.dart';
import '../cubit/settings_cubit.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../import/import_tv_time_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        children: [
          _buildSectionHeader(context, 'Appearance'),
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) {
              return Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: Icon(
                      themeState.isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Use dark interface',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    value: themeState.isDarkMode,
                    onChanged: (bool value) {
                      HapticFeedback.lightImpact();
                      context.read<ThemeCubit>().toggleDarkMode(value);
                    },
                  ),
                ],
              );
            },
          ),
          Divider(color: Theme.of(context).dividerColor, height: 32),
          _buildSectionHeader(context, 'Notifications'),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    secondary: Icon(
                      Icons.notifications_active,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    title: Text(
                      'Release Notifications',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Get alerted a day before episodes or movies release',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    value: state.notificationsEnabled,
                    onChanged: (bool value) {
                      HapticFeedback.lightImpact();
                      context.read<SettingsCubit>().toggleNotifications(value);
                    },
                  ),
                  if (state.notificationsEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: SwitchListTile.adaptive(
                        title: Text(
                          'Notify 1 Hour before release',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 14,
                          ),
                        ),
                        value: state.notify1HourBefore,
                        onChanged: (bool value) {
                          HapticFeedback.lightImpact();
                          context.read<SettingsCubit>().toggleNotify1HourBefore(
                            value,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Send Test Notification'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.blue,
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          NotificationService().sendTestNotification();
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Divider(color: Theme.of(context).dividerColor, height: 32),
          _buildSectionHeader(context, 'Data & Import'),
          ListTile(
            leading: Icon(
              Icons.import_export,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            title: Text(
              'Import TV Time',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Import your watch history from a TV Time GDPR export',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportTvTimePage(),
                ),
              );
            },
          ),
          Divider(
            color: Theme.of(context).dividerColor,
            height: AppSpacing.xxl,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '1.0.0';
                final textStyle = TextStyle(
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) ??
                      AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                );
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'v$version',
                        style: textStyle,
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapH4,
                      Text(
                        'Made with ♥️ by MWStudio',
                        style: textStyle,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color:
              Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withValues(alpha: 0.6) ??
              AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
