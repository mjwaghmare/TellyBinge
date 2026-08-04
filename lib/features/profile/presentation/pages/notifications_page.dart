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

  const NotificationItem({
    required this.username,
    required this.actionText,
    this.subtitleDetail,
    required this.avatarUrl,
    required this.time,
  });
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static final List<NotificationItem> _notifications = [
    const NotificationItem(
      username: 'moon',
      actionText: 'followed you back on TV Time',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=80',
      time: '4 days ago',
    ),
    const NotificationItem(
      username: 'Rebeka',
      actionText: 'followed you back on TV Time',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
      time: '25 June 2026',
    ),
    const NotificationItem(
      username: '🍁',
      actionText: 'followed you on TV Time',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
      time: '18 June 2026',
    ),
    const NotificationItem(
      username: 'Ambi',
      actionText: 'followed you on TV Time',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
      time: '14 June 2026',
    ),
    const NotificationItem(
      username: 'Sabrina',
      actionText: 'followed you back on TV Time',
      avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=80',
      time: '31 May 2026',
    ),
    const NotificationItem(
      username: 'Sabrina',
      actionText: 'has accepted your follow request',
      avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=80',
      time: '31 May 2026',
    ),
    const NotificationItem(
      username: 'Chichan ™',
      actionText: 'commented the episode S04 | E04',
      subtitleDetail: 'of FROM',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80',
      time: '16 May 2026',
    ),
    const NotificationItem(
      username: 'S.b1lk6n',
      actionText: 'commented the episode S01 | E06',
      subtitleDetail: 'of Midnight Mass (2021)',
      avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=80',
      time: '11 May 2026',
    ),
    const NotificationItem(
      username: 'Chichan ™',
      actionText: 'commented the episode S02 | E06',
      subtitleDetail: 'of Squid Game: The Challenge',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80',
      time: '11 May 2026',
    ),
    const NotificationItem(
      username: 'Chichan ™',
      actionText: 'commented the episode S02 | E07',
      subtitleDetail: 'of Squid Game: The Challenge',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80',
      time: '11 May 2026',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge?.color),
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
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.bottomTabPadding),
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
            leading: CircleAvatar(
              radius: 20.0,
              backgroundColor: AppColors.surfaceLight,
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
                    text: '${item.username} ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '${item.actionText} '),
                  if (item.subtitleDetail != null)
                    TextSpan(
                      text: item.subtitleDetail,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                item.time,
                style: TextStyle(
                  color: context.adaptiveColor(light: Colors.grey[500]!, dark: AppColors.textTertiary),
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
