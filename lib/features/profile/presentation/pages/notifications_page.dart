import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class SarcasticEmptyState {
  final String emoji;
  final String title;
  final String subtitle;

  const SarcasticEmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<ReceivedNotificationItem> _notifications = [];
  bool _isLoading = true;
  late SarcasticEmptyState _emptyState;

  static const List<SarcasticEmptyState> _emptyStates = [
    SarcasticEmptyState(
      emoji: '🦗',
      title: 'Crickets in here...',
      subtitle:
          'No notifications yet. Either all your shows are on hiatus or you need to touch some grass.',
    ),
    SarcasticEmptyState(
      emoji: '🍿',
      title: 'Your notifications are empty!',
      subtitle:
          'Empty like your popcorn bucket 5 minutes into the movie. Add some shows to your watchlist!',
    ),
    SarcasticEmptyState(
      emoji: '😴',
      title: 'Total radio silence',
      subtitle:
          'No pushed episodes, no movie premieres, zero drama. Go rewatch The Office for the 14th time.',
    ),
    SarcasticEmptyState(
      emoji: '🛋️',
      title: 'Suspiciously peaceful...',
      subtitle:
          'No cliffhangers waiting to ruin your sleep tonight. Enjoy the quiet while it lasts!',
    ),
    SarcasticEmptyState(
      emoji: '😱',
      title: 'Nothing to report! Go outside?',
      subtitle:
          'Your notification tray is clear. You could actually do something productive... or find new shows.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _emptyState = _emptyStates[Random().nextInt(_emptyStates.length)];
    NotificationService().markNotificationsAsRead();
    _fetchReceivedNotifications();
  }

  Future<void> _fetchReceivedNotifications() async {
    setState(() {
      _isLoading = true;
    });
    final items = await NotificationService().getReceivedNotifications();
    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllNotifications() async {
    setState(() {
      _notifications.clear();
    });
    await NotificationService().clearAllUserNotifications();
  }

  Future<void> _removeNotification(String id) async {
    setState(() {
      _notifications.removeWhere((item) => item.id == id);
    });
    await NotificationService().removeReceivedNotification(id);
    final intId = int.tryParse(id);
    if (intId != null) {
      await NotificationService().cancelNotificationById(intId);
    }
  }

  void _onNotificationTap(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      NotificationService().onNotificationTap?.call(payload);
    }
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _emptyState.emoji,
                          style: const TextStyle(fontSize: 64.0),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _emptyState.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _emptyState.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
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
                    return Dismissible(
                      key: Key('notification_${item.id}'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _removeNotification(item.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        color: AppColors.error,
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xs,
                        ),
                        onTap: item.payload != null
                            ? () => _onNotificationTap(item.payload)
                            : null,
                        leading: CircleAvatar(
                          radius: 20.0,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            color: AppColors.primary,
                            size: 20.0,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            item.body,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 13.0,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18.0),
                          color: isDark
                              ? AppColors.textTertiary
                              : AppColors.lightTextTertiary,
                          onPressed: () => _removeNotification(item.id),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
