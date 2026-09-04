import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    description: 'Received and queued for review',
    icon: Icons.radio_button_unchecked_rounded,
    lightBg: Color(0xFFF3F4F6),
    lightText: Color(0xFF4B5563),
    darkBg: Color(0xFF1F2937),
    darkText: Color(0xFF9CA3AF),
  ),
  underReview(
    label: 'Under Review',
    description: 'Being reviewed by the team',
    icon: Icons.visibility_outlined,
    lightBg: Color(0xFFEDE9FE),
    lightText: Color(0xFF6D28D9),
    darkBg: Color(0xFF231942),
    darkText: Color(0xFFA78BFA),
  ),
  planned(
    label: 'Planned',
    description: 'Scheduled for an upcoming release',
    icon: Icons.event_note_rounded,
    lightBg: Color(0xFFE0F2FE),
    lightText: Color(0xFF0369A1),
    darkBg: Color(0xFF0C334E),
    darkText: Color(0xFF38BDF8),
  ),
  inProgress(
    label: 'In Progress',
    description: 'Currently being actively worked on',
    icon: Icons.timelapse_rounded,
    lightBg: Color(0xFFFEF3C7),
    lightText: Color(0xFFB45309),
    darkBg: Color(0xFF352003),
    darkText: Color(0xFFFBBF24),
  ),
  resolved(
    label: 'Resolved',
    description: 'Fixed and completed in the app',
    icon: Icons.check_circle_outline_rounded,
    lightBg: Color(0xFFDCFCE7),
    lightText: Color(0xFF15803D),
    darkBg: Color(0xFF052E16),
    darkText: Color(0xFF4ADE80),
  ),
  closed(
    label: 'Closed',
    description: 'Closed or marked as won\'t fix',
    icon: Icons.cancel_outlined,
    lightBg: Color(0xFFFEE2E2),
    lightText: Color(0xFFDC2626),
    darkBg: Color(0xFF3B1212),
    darkText: Color(0xFFF87171),
  ),
  declined(
    label: 'Declined',
    description: 'Declined by the team',
    icon: Icons.cancel_outlined,
    lightBg: Color(0xFFFEE2E2),
    lightText: Color(0xFFDC2626),
    darkBg: Color(0xFF3B1212),
    darkText: Color(0xFFF87171),
  );

  final String label;
  final String description;
  final IconData icon;
  final Color lightBg;
  final Color lightText;
  final Color darkBg;
  final Color darkText;

  const FeedbackStatus({
    required this.label,
    required this.description,
    required this.icon,
    required this.lightBg,
    required this.lightText,
    required this.darkBg,
    required this.darkText,
  });

  Color backgroundColor(bool isLight) => isLight ? lightBg : darkBg;
  Color textColor(bool isLight) => isLight ? lightText : darkText;

  /// The 4 generic statuses available for admin selection
  static const List<FeedbackStatus> genericStatuses = [
    FeedbackStatus.open,
    FeedbackStatus.inProgress,
    FeedbackStatus.resolved,
    FeedbackStatus.closed,
  ];
}

enum FeedbackVoteMilestone {
  hot(
    minVotes: 5,
    emoji: '🔥',
    label: 'Hot',
    lightBg: Color(0xFFFFEDD5),
    lightText: Color(0xFFEA580C),
    darkBg: Color(0xFF431407),
    darkText: Color(0xFFFB923C),
  ),
  popular(
    minVotes: 10,
    emoji: '⚡',
    label: 'Popular',
    lightBg: Color(0xFFFEF3C7),
    lightText: Color(0xFFD97706),
    darkBg: Color(0xFF332005),
    darkText: Color(0xFFFBBF24),
  ),
  topVoted(
    minVotes: 15,
    emoji: '🚀',
    label: 'Top Voted',
    lightBg: Color(0xFFEDE9FE),
    lightText: Color(0xFF7C3AED),
    darkBg: Color(0xFF261845),
    darkText: Color(0xFFA78BFA),
  );

  final int minVotes;
  final String emoji;
  final String label;
  final Color lightBg;
  final Color lightText;
  final Color darkBg;
  final Color darkText;

  const FeedbackVoteMilestone({
    required this.minVotes,
    required this.emoji,
    required this.label,
    required this.lightBg,
    required this.lightText,
    required this.darkBg,
    required this.darkText,
  });

  String get displayText => '$emoji $label';

  Color backgroundColor(bool isLight) => isLight ? lightBg : darkBg;
  Color textColor(bool isLight) => isLight ? lightText : darkText;

  static FeedbackVoteMilestone? fromVotes(int votes) {
    if (votes >= 15) return FeedbackVoteMilestone.topVoted;
    if (votes >= 10) return FeedbackVoteMilestone.popular;
    if (votes >= 5) return FeedbackVoteMilestone.hot;
    return null;
  }
}

class FeedbackMedia {
  final String path;
  final bool isLocal;

  const FeedbackMedia({required this.path, this.isLocal = false});

  Map<String, dynamic> toMap() => {'path': path, 'isLocal': isLocal};

  factory FeedbackMedia.fromMap(dynamic map) {
    if (map is String) {
      final isNetwork =
          map.startsWith('http://') || map.startsWith('https://');
      return FeedbackMedia(path: map, isLocal: !isNetwork);
    }
    if (map is Map) {
      final path = (map['path'] as String?) ?? map['path']?.toString() ?? '';
      final isNetwork =
          path.startsWith('http://') || path.startsWith('https://');
      return FeedbackMedia(
        path: path,
        isLocal: (map['isLocal'] as bool?) ?? !isNetwork,
      );
    }
    return const FeedbackMedia(path: '', isLocal: false);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackMedia &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          isLocal == other.isLocal;

  @override
  int get hashCode => path.hashCode ^ isLocal.hashCode;
}

class FeedbackItem {
  final String id;
  final String title;
  final String description;
  final FeedbackCategory category;
  final FeedbackStatus status;
  final int votes;
  final List<FeedbackMedia> media;
  final String? severity;
  final String? officialResponse;
  final List<Map<String, dynamic>> comments;
  final int commentCount;
  final String userId;
  final String userName;
  final String userAvatar;
  final String appVersion;
  final DateTime? createdAt;
  final List<String> upvotedUserIds;
  final bool isUpvoted;

  const FeedbackItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.votes,
    this.media = const [],
    this.severity,
    this.officialResponse,
    this.comments = const [],
    this.commentCount = 0,
    this.userId = '',
    required this.userName,
    required this.userAvatar,
    required this.appVersion,
    this.createdAt,
    this.upvotedUserIds = const [],
    this.isUpvoted = false,
  });

  String get timeAgo {
    if (createdAt == null) return 'Just now';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 7) {
      return '${(diff.inDays / 7).floor()}w ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  FeedbackVoteMilestone? get voteMilestone =>
      FeedbackVoteMilestone.fromVotes(votes);

  String get formattedVotes => NumberFormat.compact().format(votes);

  FeedbackItem copyWith({
    String? id,
    String? title,
    String? description,
    FeedbackCategory? category,
    FeedbackStatus? status,
    int? votes,
    List<FeedbackMedia>? media,
    String? severity,
    String? officialResponse,
    List<Map<String, dynamic>>? comments,
    int? commentCount,
    String? userId,
    String? userName,
    String? userAvatar,
    String? appVersion,
    DateTime? createdAt,
    List<String>? upvotedUserIds,
    bool? isUpvoted,
  }) {
    return FeedbackItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      votes: votes ?? this.votes,
      media: media ?? this.media,
      severity: severity ?? this.severity,
      officialResponse: officialResponse ?? this.officialResponse,
      comments: comments ?? this.comments,
      commentCount: commentCount ?? this.commentCount,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
      upvotedUserIds: upvotedUserIds ?? this.upvotedUserIds,
      isUpvoted: isUpvoted ?? this.isUpvoted,
    );
  }

  FeedbackItem upvoted([String? currentUserId]) {
    final uid = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : '';
    final updatedUpvotes = List<String>.from(upvotedUserIds);

    if (isUpvoted) {
      // Toggle off / cancel upvote (-1)
      if (uid.isNotEmpty) updatedUpvotes.remove(uid);
      return copyWith(
        votes: (votes - 1).clamp(0, 99999),
        isUpvoted: false,
        upvotedUserIds: updatedUpvotes,
      );
    } else {
      // Add upvote (+1)
      if (uid.isNotEmpty && !updatedUpvotes.contains(uid)) {
        updatedUpvotes.add(uid);
      }
      return copyWith(
        votes: votes + 1,
        isUpvoted: true,
        upvotedUserIds: updatedUpvotes,
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
      'votes': votes,
      'media': media.map((m) => m.path).toList(),
      'severity': severity,
      'officialResponse': officialResponse,
      'comments': comments,
      'commentCount': commentCount,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'appVersion': appVersion,
      'createdAt': createdAt?.toIso8601String(),
      'upvotedUserIds': upvotedUserIds,
    };
  }

  factory FeedbackItem.fromMap(
    Map<String, dynamic> map,
    String docId, [
    String? currentUserId,
  ]) {
    final categoryStr = map['category'] as String? ?? 'bug';
    final category = FeedbackCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => FeedbackCategory.bug,
    );

    final statusStr = map['status'] as String? ?? 'open';
    final status = FeedbackStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => FeedbackStatus.open,
    );

    final mediaList =
        (map['media'] as List<dynamic>?)
            ?.map((m) => FeedbackMedia.fromMap(m))
            .where((m) => m.path.trim().isNotEmpty)
            .toList() ??
        [];

    final commentsList =
        (map['comments'] as List<dynamic>?)
            ?.map((c) {
              final commentMap = Map<String, dynamic>.from(c as Map);
              final existingId = commentMap['id']?.toString().trim();
              if (existingId == null || existingId.isEmpty) {
                final userId = commentMap['userId'] ?? 'user';
                final time = commentMap['time'] ?? '';
                final timestamp = DateTime.now().microsecondsSinceEpoch;
                commentMap['id'] =
                    'comment_${userId}_${time.hashCode.abs()}_$timestamp';
              }
              return commentMap;
            })
            .toList() ??
        [];

    final rawCount = (map['commentCount'] as num?)?.toInt();
    final commentCount = rawCount ?? commentsList.length;

    final upvotedIds =
        (map['upvotedUserIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    DateTime? createdAt;
    final createdRaw = map['createdAt'];
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    } else if (createdRaw != null) {
      try {
        createdAt = (createdRaw as dynamic).toDate() as DateTime?;
      } catch (_) {}
    }

    final isUpvoted =
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        upvotedIds.contains(currentUserId);

    return FeedbackItem(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: category,
      status: status,
      votes: (map['votes'] as num?)?.toInt() ?? 0,
      media: mediaList,
      severity: map['severity'] as String?,
      officialResponse: map['officialResponse'] as String?,
      comments: commentsList,
      commentCount: commentCount,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Anonymous',
      userAvatar: map['userAvatar'] as String? ?? '',
      appVersion: map['appVersion'] as String? ?? 'v1.0.0',
      createdAt: createdAt,
      upvotedUserIds: upvotedIds,
      isUpvoted: isUpvoted,
    );
  }
}
