import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class NotificationItem {
  final String username;
  final String actionText;
  final String? subtitleDetail;
  final String avatarUrl;
  final String time;
  final bool isSystemAlert;

  const NotificationItem({
    required this.username,
    required this.actionText,
    this.subtitleDetail,
    required this.avatarUrl,
    required this.time,
    this.isSystemAlert = false,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<NotificationItem> _notifications = [
    const NotificationItem(
      username: '🍿 Cancel your plans: Stranger Things',
      actionText: 'Episode S05E01 drops tomorrow.',
      subtitleDetail: 'Don\'t pretend you had better things to do.',
      avatarUrl: '',
      time: '10m ago',
      isSystemAlert: true,
    ),
    const NotificationItem(
      username: '🎬 Clear your calendar: Dune: Part Three',
      actionText: 'Dune: Part Three premieres in 1 hour.',
      subtitleDetail: 'Grab the remote and lock the door.',
      avatarUrl: '',
      time: '1h ago',
      isSystemAlert: true,
    ),
    const NotificationItem(
      username: 'moon',
      actionText: 'followed you back on TV Time',
      avatarUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=80',
      time: '4 days ago',
    ),
    const NotificationItem(
      username: '🛌 Sleep is overrated: House of the Dragon',
      actionText: 'Episode S03E01 is airing tomorrow.',
      subtitleDetail: 'Your pillow can wait.',
      avatarUrl: '',
      time: '1 day ago',
      isSystemAlert: true,
    ),
    const NotificationItem(
      username: 'Rebeka',
      actionText: 'followed you back on TV Time',
      avatarUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
      time: '25 June 2026',
    ),
    const NotificationItem(
      username: '🍁',
      actionText: 'followed you on TV Time',
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
      time: '18 June 2026',
    ),
    const NotificationItem(
      username: 'Ambi',
      actionText: 'followed you on TV Time',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
      time: '14 June 2026',
    ),
    const NotificationItem(
      username: 'Chichan ™',
      actionText: 'commented the episode S04 | E04',
      subtitleDetail: 'of FROM',
      avatarUrl:
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80',
      time: '16 May 2026',
    ),
  ];

  void _clearAllNotifications() {
    setState(() {
      _notifications.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAllNotifications,
              child: const Text(
                'Clear all',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64.0,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Notifications',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You\'re all caught up! Check back later.',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.sm,
                0,
                AppSpacing.bottomTabPadding,
              ),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => Divider(
                color: Theme.of(context).dividerColor,
                height: 1,
                thickness: 0.5,
              ),
              itemBuilder: (context, index) {
                final item = _notifications[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  leading: item.isSystemAlert
                      ? CircleAvatar(
                          radius: 20.0,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          child: const Icon(
                            Icons.notifications_active,
                            color: AppColors.primary,
                            size: 20.0,
                          ),
                        )
                      : CircleAvatar(
                          radius: 20.0,
                          backgroundColor: isDark
                              ? AppColors.surfaceElevated
                              : AppColors.lightSurfaceElevated,
                          backgroundImage: item.avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(item.avatarUrl)
                              : null,
                        ),
                  title: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14.0,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: '${item.username}\n',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '${item.actionText} '),
                        if (item.subtitleDetail != null)
                          TextSpan(
                            text: item.subtitleDetail,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      item.time,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 12.0,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
