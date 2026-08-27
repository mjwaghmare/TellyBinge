import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Regex matching a single leading emoji (including compound sequences with
/// ZWJ, skin-tone modifiers, variation selectors, and keycap sequences).
final RegExp _leadingEmojiRegex = RegExp(
  r'^('
  r'[\u{1F1E6}-\u{1F1FF}]{2}' // Regional indicator (flags)
  r'|[\u{1F3FB}-\u{1F3FF}]' // Skin tone modifiers
  r'|[\u{1F300}-\u{1F5FF}]' // Misc Symbols & Pictographs
  r'|[\u{1F600}-\u{1F64F}]' // Emoticons
  r'|[\u{1F680}-\u{1F6FF}]' // Transport & Map
  r'|[\u{1F900}-\u{1F9FF}]' // Supplemental Symbols
  r'|[\u{1FA00}-\u{1FA6F}]' // Chess Symbols
  r'|[\u{1FA70}-\u{1FAFF}]' // Symbols Extended-A
  r'|[\u{2600}-\u{26FF}]' // Misc symbols
  r'|[\u{2700}-\u{27BF}]' // Dingbats
  r'|[\u{FE00}-\u{FE0F}]' // Variation Selectors
  r'|[\u{231A}-\u{231B}]' // Watch, Hourglass
  r'|[\u{23E9}-\u{23F3}]' // Media controls
  r'|[\u{23F8}-\u{23FA}]' // Media controls 2
  r'|[\u{200D}]' // ZWJ
  r'|[0-9#*]\u{FE0F}?\u{20E3}' // Keycap sequences
  r'|[\u{E0020}-\u{E007F}]' // Tags
  r')+',
  unicode: true,
);

/// Extracts the leading emoji character(s) from [text], or returns `null`.
String? _extractLeadingEmoji(String text) {
  final match = _leadingEmojiRegex.firstMatch(text);
  return match?.group(0);
}

class SarcasticEmptyState {
  final String emoji;
  final String title;
  final String subtitle;

  const SarcasticEmptyState({required this.emoji, required this.title, required this.subtitle});
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<ReceivedNotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  late SarcasticEmptyState _emptyState;

  static const List<SarcasticEmptyState> _emptyStates = [
    SarcasticEmptyState(
      emoji: '🦗',
      title: 'Crickets in here...',
      subtitle: 'No notifications yet. Either all your shows are on hiatus or you need to touch some grass.',
    ),
    SarcasticEmptyState(
      emoji: '🍿',
      title: 'Your notifications are empty!',
      subtitle: 'Empty like your popcorn bucket 5 minutes into the movie. Add some shows to your watchlist!',
    ),
    SarcasticEmptyState(
      emoji: '😴',
      title: 'Total radio silence',
      subtitle: 'No pushed episodes, no movie premieres, zero drama. Go rewatch The Office for the 14th time.',
    ),
    SarcasticEmptyState(
      emoji: '🛋️',
      title: 'Suspiciously peaceful...',
      subtitle: 'No cliffhangers waiting to ruin your sleep tonight. Enjoy the quiet while it lasts!',
    ),
    SarcasticEmptyState(
      emoji: '😱',
      title: 'Nothing to report! Go outside?',
      subtitle: 'Your notification tray is clear. You could actually do something productive... or find new shows.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _emptyState = _emptyStates[Random().nextInt(_emptyStates.length)];
    _fetchReceivedNotifications();
  }

  Future<void> _fetchReceivedNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await NotificationService().getReceivedNotifications();
      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
          _errorMessage = null;
        });
      }
      try {
        await NotificationService().markNotificationsAsRead();
      } catch (e) {
        debugPrint('Failed to mark notifications as read: $e');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load notifications. Please try again.';
        });
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    setState(() {
      _notifications.clear();
      _errorMessage = null;
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
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAllNotifications,
              child: const Text(
                'Clear all',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
          : RefreshIndicator(
              onRefresh: _fetchReceivedNotifications,
              color: AppColors.primary,
              child: _errorMessage != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 54.0, color: AppColors.error),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Could not load notifications',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              ElevatedButton.icon(
                                onPressed: _fetchReceivedNotifications,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.textOnPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_emptyState.emoji, style: const TextStyle(fontSize: 64.0)),
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
                                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.bottomTabPadding,
                      ),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        final hasPayload = item.payload != null && item.payload!.isNotEmpty;
                        final formattedTime = _formatTimestamp(item.timestamp);
                        final emoji = _extractLeadingEmoji(item.title);

                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Dismissible(
                            key: Key('notification_${item.id}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _removeNotification(item.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: AppSpacing.md),
                              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                            ),
                            child: Material(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: hasPayload ? () => _onNotificationTap(item.payload) : null,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: emoji != null
                                            ? Text(emoji, style: const TextStyle(fontSize: 22.0))
                                            : const Icon(
                                                Icons.notifications_active_rounded,
                                                color: AppColors.primary,
                                                size: 22.0,
                                              ),
                                      ),
                                      AppSpacing.gapW12,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    style: TextStyle(
                                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                                      fontSize: 14.0,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (formattedTime.isNotEmpty) ...[
                                                  AppSpacing.gapW8,
                                                  Text(
                                                    formattedTime,
                                                    style: TextStyle(
                                                      color: isDark ? AppColors.textTertiary : AppColors.lightTextSecondary,
                                                      fontSize: 11.0,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4.0),
                                            Text(
                                              item.body,
                                              style: TextStyle(
                                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                                fontSize: 13.0,
                                                height: 1.35,
                                              ),
                                            ),
                                            if (hasPayload) ...[
                                              const SizedBox(height: 8.0),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    'Tap to view',
                                                    style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 11.0,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4.0),
                                                  const Icon(
                                                    Icons.arrow_forward_ios_rounded,
                                                    size: 10.0,
                                                    color: AppColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.isNegative) {
        return '${dateTime.day}/${dateTime.month}';
      }
      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (_) {
      return '';
    }
  }
}
