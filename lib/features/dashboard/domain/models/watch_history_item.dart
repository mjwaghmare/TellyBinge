import 'package:equatable/equatable.dart';

class WatchHistoryItem extends Equatable {
  final String id;
  final int showId;
  final String showName;
  final String? showPoster;
  final String episodeKey;
  final String episodeTitle;
  final String watchedAt;

  const WatchHistoryItem({
    required this.id,
    required this.showId,
    required this.showName,
    this.showPoster,
    required this.episodeKey,
    required this.episodeTitle,
    required this.watchedAt,
  });

  String get displayCode {
    if (!episodeKey.contains('-')) return episodeKey;
    final parts = episodeKey.split('-');
    if (parts.length != 2) return episodeKey;
    final s = int.tryParse(parts[0])?.toString().padLeft(2, '0') ?? parts[0];
    final e = int.tryParse(parts[1])?.toString().padLeft(2, '0') ?? parts[1];
    return 'S$s | E$e';
  }

  factory WatchHistoryItem.fromMap(Map<String, dynamic> map) {
    return WatchHistoryItem(
      id: map['id']?.toString() ?? '',
      showId: (map['showId'] as num?)?.toInt() ?? 0,
      showName: map['showName']?.toString() ?? '',
      showPoster: map['showPoster'] as String?,
      episodeKey: map['episodeKey']?.toString() ?? '',
      episodeTitle: map['episodeTitle']?.toString() ?? '',
      watchedAt: map['watchedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'showId': showId,
      'showName': showName,
      'showPoster': showPoster,
      'episodeKey': episodeKey,
      'episodeTitle': episodeTitle,
      'watchedAt': watchedAt,
    };
  }

  @override
  List<Object?> get props => [
    id,
    showId,
    showName,
    showPoster,
    episodeKey,
    episodeTitle,
    watchedAt,
  ];
}
