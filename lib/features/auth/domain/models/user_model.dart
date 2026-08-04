import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final int tvTimeSpentMinutes;
  final int episodesWatched;
  final int moviesWatched;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.tvTimeSpentMinutes = 0,
    this.episodesWatched = 0,
    this.moviesWatched = 0,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    int? tvTimeSpentMinutes,
    int? episodesWatched,
    int? moviesWatched,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      tvTimeSpentMinutes: tvTimeSpentMinutes ?? this.tvTimeSpentMinutes,
      episodesWatched: episodesWatched ?? this.episodesWatched,
      moviesWatched: moviesWatched ?? this.moviesWatched,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'stats': {
        'tvTimeSpentMinutes': tvTimeSpentMinutes,
        'episodesWatched': episodesWatched,
        'moviesWatched': moviesWatched,
      },
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final stats = map['stats'] as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      tvTimeSpentMinutes: (stats['tvTimeSpentMinutes'] as num?)?.toInt() ?? 0,
      episodesWatched: (stats['episodesWatched'] as num?)?.toInt() ?? 0,
      moviesWatched: (stats['moviesWatched'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    displayName,
    photoUrl,
    tvTimeSpentMinutes,
    episodesWatched,
    moviesWatched,
  ];
}
