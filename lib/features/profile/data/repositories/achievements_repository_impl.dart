import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../domain/models/achievement.dart';
import '../../domain/repositories/achievements_repository.dart';

class AchievementsRepositoryImpl implements AchievementsRepository {
  final FirebaseFirestore _firestore;

  AchievementsRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _achievementsCollection(
    String uid,
  ) => _firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.achievements);

  @override
  Future<Map<String, DateTime>> getUnlockedAchievements(String uid) async {
    final snapshot = await _achievementsCollection(uid).get();
    final result = <String, DateTime>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      result[doc.id] = _parseTimestamp(data['unlockedAt']);
    }
    return result;
  }

  @override
  Future<void> saveUnlockedAchievements(
    String uid,
    List<Achievement> achievements,
  ) async {
    if (achievements.isEmpty) return;

    final batch = _firestore.batch();
    for (final a in achievements) {
      final key = '${a.id}_${a.tier.name}';
      final docRef = _achievementsCollection(uid).doc(key);
      batch.set(docRef, {
        'id': a.id,
        'tier': a.tier.name,
        'title': a.title,
        'unlockedAt': a.unlockedAt != null
            ? Timestamp.fromDate(a.unlockedAt!)
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Stream<Map<String, DateTime>> watchUnlockedAchievements(String uid) {
    return _achievementsCollection(uid)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final result = <String, DateTime>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            result[doc.id] = _parseTimestamp(data['unlockedAt']);
          }
          return result;
        });
  }

  DateTime _parseTimestamp(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    } else if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
