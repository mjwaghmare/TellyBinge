import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final int tvTimeSpentMinutes;
  final int episodesWatched;
  final int moviesWatched;
  final String role;
  final bool hasAdminClaim;
  final List<String> preferredGenres;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.tvTimeSpentMinutes = 0,
    this.episodesWatched = 0,
    this.moviesWatched = 0,
    this.role = 'user',
    this.hasAdminClaim = false,
    this.preferredGenres = const [],
  });

  bool get isAdmin {
    if (hasAdminClaim) return true;
    if (role.trim().toLowerCase() == 'admin') return true;
    final normalized = email.trim().toLowerCase();
    final fallback = AppConstants.fallbackAdminEmail.trim().toLowerCase();
    return fallback.isNotEmpty && normalized == fallback;
  }

  bool get isPro {
    if (isAdmin) return true;
    final r = role.trim().toLowerCase();
    return r == 'pro' || r == 'premium' || r == 'subscriber' || r == 'vip';
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    int? tvTimeSpentMinutes,
    int? episodesWatched,
    int? moviesWatched,
    String? role,
    bool? hasAdminClaim,
    List<String>? preferredGenres,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      tvTimeSpentMinutes: tvTimeSpentMinutes ?? this.tvTimeSpentMinutes,
      episodesWatched: episodesWatched ?? this.episodesWatched,
      moviesWatched: moviesWatched ?? this.moviesWatched,
      role: role ?? this.role,
      hasAdminClaim: hasAdminClaim ?? this.hasAdminClaim,
      preferredGenres: preferredGenres ?? this.preferredGenres,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'preferredGenres': preferredGenres,
      'stats': {
        'tvTimeSpentMinutes': tvTimeSpentMinutes,
        'episodesWatched': episodesWatched,
        'moviesWatched': moviesWatched,
      },
    };
  }

  factory UserModel.fromMap(
    Map<String, dynamic> map, {
    bool hasAdminClaim = false,
  }) {
    final stats = map['stats'] as Map<String, dynamic>? ?? {};
    final email = map['email'] as String? ?? '';
    final normalized = email.trim().toLowerCase();
    final fallback = AppConstants.fallbackAdminEmail.trim().toLowerCase();
    final isFallbackAdmin = fallback.isNotEmpty && normalized == fallback;
    final defaultRole = (hasAdminClaim || isFallbackAdmin) ? 'admin' : 'user';
    final role = map['role'] as String? ?? defaultRole;

    final rawGenres = map['preferredGenres'];
    final preferredGenres = rawGenres is List
        ? rawGenres.map((e) => e.toString()).toList()
        : const <String>[];

    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: email,
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      tvTimeSpentMinutes: (stats['tvTimeSpentMinutes'] as num?)?.toInt() ?? 0,
      episodesWatched: (stats['episodesWatched'] as num?)?.toInt() ?? 0,
      moviesWatched: (stats['moviesWatched'] as num?)?.toInt() ?? 0,
      role: role,
      hasAdminClaim: hasAdminClaim,
      preferredGenres: preferredGenres,
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
    role,
    hasAdminClaim,
    preferredGenres,
  ];
}
