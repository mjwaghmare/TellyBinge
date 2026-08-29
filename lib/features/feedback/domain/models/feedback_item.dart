import 'package:flutter/material.dart';

enum FeedbackCategory {
  bug(
    label: 'Bug',
    lightBg: Color(0xFFFEF3C7),
    lightText: Color(0xFFD97706),
    darkBg: Color(0xFF332005),
    darkText: Color(0xFFFBBF24),
  ),
  feature(
    label: 'Feature',
    lightBg: Color(0xFFEDE9FE),
    lightText: Color(0xFF7C3AED),
    darkBg: Color(0xFF261845),
    darkText: Color(0xFFA78BFA),
  ),
  improvement(
    label: 'Improvement',
    lightBg: Color(0xFFE0F2FE),
    lightText: Color(0xFF0284C7),
    darkBg: Color(0xFF082F49),
    darkText: Color(0xFF38BDF8),
  );

  final String label;
  final Color lightBg;
  final Color lightText;
  final Color darkBg;
  final Color darkText;

  const FeedbackCategory({
    required this.label,
    required this.lightBg,
    required this.lightText,
    required this.darkBg,
    required this.darkText,
  });

  Color backgroundColor(bool isLight) => isLight ? lightBg : darkBg;
  Color textColor(bool isLight) => isLight ? lightText : darkText;
}

enum FeedbackStatus {
  open(
    label: 'Open',
    lightBg: Color(0xFFF3F4F6),
    lightText: Color(0xFF4B5563),
    darkBg: Color(0xFF1F2937),
    darkText: Color(0xFF9CA3AF),
  ),
  underReview(
    label: 'Under Review',
    lightBg: Color(0xFFEDE9FE),
    lightText: Color(0xFF6D28D9),
    darkBg: Color(0xFF231942),
    darkText: Color(0xFFA78BFA),
  ),
  planned(
    label: 'Planned',
    lightBg: Color(0xFFE0F2FE),
    lightText: Color(0xFF0369A1),
    darkBg: Color(0xFF0C334E),
    darkText: Color(0xFF38BDF8),
  ),
  inProgress(
    label: 'In Progress',
    lightBg: Color(0xFFFEF3C7),
    lightText: Color(0xFFB45309),
    darkBg: Color(0xFF352003),
    darkText: Color(0xFFFBBF24),
  ),
  resolved(
    label: 'Resolved',
    lightBg: Color(0xFFDCFCE7),
    lightText: Color(0xFF15803D),
    darkBg: Color(0xFF052E16),
    darkText: Color(0xFF4ADE80),
  );

  final String label;
  final Color lightBg;
  final Color lightText;
  final Color darkBg;
  final Color darkText;

  const FeedbackStatus({
    required this.label,
    required this.lightBg,
    required this.lightText,
    required this.darkBg,
    required this.darkText,
  });

  Color backgroundColor(bool isLight) => isLight ? lightBg : darkBg;
  Color textColor(bool isLight) => isLight ? lightText : darkText;
}

class FeedbackItem {
  final String id;
  final String title;
  final String description;
  final FeedbackCategory category;
  final FeedbackStatus status;
  final int votes;
  final List<String> mediaUrls;
  final String userName;
  final String userAvatar;
  final String appVersion;
  final String timeAgo;
  final bool isUpvoted;
  final bool isDownvoted;

  const FeedbackItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.votes,
    this.mediaUrls = const [],
    required this.userName,
    required this.userAvatar,
    required this.appVersion,
    required this.timeAgo,
    this.isUpvoted = false,
    this.isDownvoted = false,
  });

  FeedbackItem copyWith({
    String? id,
    String? title,
    String? description,
    FeedbackCategory? category,
    FeedbackStatus? status,
    int? votes,
    List<String>? mediaUrls,
    String? userName,
    String? userAvatar,
    String? appVersion,
    String? timeAgo,
    bool? isUpvoted,
    bool? isDownvoted,
  }) {
    return FeedbackItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      votes: votes ?? this.votes,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      appVersion: appVersion ?? this.appVersion,
      timeAgo: timeAgo ?? this.timeAgo,
      isUpvoted: isUpvoted ?? this.isUpvoted,
      isDownvoted: isDownvoted ?? this.isDownvoted,
    );
  }

  static List<FeedbackItem> get dummyList => const [
        FeedbackItem(
          id: '1',
          title: 'Subtitle sync delay on Season 3',
          description:
              'Season 3 episodes have a noticeable audio-to-subtitle lag of around 2-3 seconds when streaming with hardware decoding.',
          category: FeedbackCategory.bug,
          status: FeedbackStatus.underReview,
          votes: 42,
          mediaUrls: [
            'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=600&auto=format&fit=crop&q=80',
            'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=600&auto=format&fit=crop&q=80',
          ],
          userName: 'uandamata',
          userAvatar: '',
          appVersion: 'v1.0.0',
          timeAgo: '2h ago',
          isUpvoted: true,
        ),
        FeedbackItem(
          id: '2',
          title: 'Trakt.tv 2-way automatic synchronization',
          description:
              'Add seamless 2-way background sync with Trakt.tv so watched episodes, ratings, and custom collection lists stay synchronized across all devices.',
          category: FeedbackCategory.feature,
          status: FeedbackStatus.planned,
          votes: 128,
          mediaUrls: [
            'https://images.unsplash.com/photo-1616469829941-c7200edec809?w=600&auto=format&fit=crop&q=80',
          ],
          userName: 'sarah_m',
          userAvatar: '',
          appVersion: 'v1.0.0',
          timeAgo: '1d ago',
        ),
        FeedbackItem(
          id: '3',
          title: 'Smoother episode countdown animations',
          description:
              'The countdown animation between episodes feels slightly stuttery on 120Hz displays. A subtle fade interpolation would feel more premium.',
          category: FeedbackCategory.improvement,
          status: FeedbackStatus.inProgress,
          votes: 19,
          mediaUrls: [],
          userName: 'david_k',
          userAvatar: '',
          appVersion: 'v1.0.0',
          timeAgo: '3d ago',
        ),
        FeedbackItem(
          id: '4',
          title: 'Search results filter by streaming providers',
          description:
              'Allow filtering discover/search results by streaming subscription (e.g. Netflix, Prime Video, HBO Max, Disney+).',
          category: FeedbackCategory.feature,
          status: FeedbackStatus.open,
          votes: 7,
          mediaUrls: [],
          userName: 'elena_r',
          userAvatar: '',
          appVersion: 'v1.0.0',
          timeAgo: '4d ago',
        ),
        FeedbackItem(
          id: '5',
          title: 'Crash when rotating player in picture-in-picture',
          description:
              'App occasionally crashes if PiP mode is entered while quickly toggling device orientation on Android 14.',
          category: FeedbackCategory.bug,
          status: FeedbackStatus.resolved,
          votes: 0,
          mediaUrls: [],
          userName: 'marcus_dev',
          userAvatar: '',
          appVersion: 'v1.0.0',
          timeAgo: '1w ago',
        ),
      ];
}
