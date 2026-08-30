import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../services/feedback_storage_service.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  final FirebaseFirestore _firestore;
  final FeedbackStorageService _storageService;

  FeedbackRepositoryImpl({
    FirebaseFirestore? firestore,
    FeedbackStorageService? storageService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storageService = storageService ?? FeedbackStorageService();

  CollectionReference<Map<String, dynamic>> get _feedbacksCollection =>
      _firestore.collection('feedbacks');

  @override
  Stream<List<FeedbackItem>> getFeedbacksStream({String? currentUserId}) {
    return _feedbacksCollection.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return FeedbackItem.fromMap(doc.data(), doc.id, currentUserId);
      }).toList();

      // Sort in memory: newest first, items being written (null createdAt) stay at top
      list.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return list;
    });
  }

  @override
  Future<FeedbackItem> submitFeedback({
    required String title,
    required String description,
    required FeedbackCategory category,
    required String? severity,
    required List<String> localMediaPaths,
    required String userId,
    required String userName,
    required String userAvatar,
    required String appVersion,
  }) async {
    // 1. Generate unique Document ID
    final docRef = _feedbacksCollection.doc();
    final feedbackId = docRef.id;

    // 2. Upload media files to Firebase Storage first
    List<String> mediaUrls = [];
    if (localMediaPaths.isNotEmpty) {
      mediaUrls = await _storageService.uploadMedia(
        feedbackId: feedbackId,
        localFilePaths: localMediaPaths,
      );
    }

    final initialUpvotedIds = userId.isNotEmpty ? [userId] : <String>[];

    // 3. Build Firestore payload
    final data = {
      'id': feedbackId,
      'title': title,
      'description': description,
      'category': category.name,
      'status': FeedbackStatus.open.name,
      'votes': 1, // Creator automatically upvotes
      'media': mediaUrls,
      'severity': category == FeedbackCategory.bug ? severity : null,
      'officialResponse': null,
      'comments': <Map<String, dynamic>>[],
      'userId': userId,
      'userName': userName.isNotEmpty ? userName : 'PopVerse Fan',
      'userAvatar': userAvatar,
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
      'upvotedUserIds': initialUpvotedIds,
    };

    await docRef.set(data);

    return FeedbackItem(
      id: feedbackId,
      title: title,
      description: description,
      category: category,
      status: FeedbackStatus.open,
      votes: 1,
      media: mediaUrls
          .map((url) => FeedbackMedia(path: url, isLocal: false))
          .toList(),
      severity: category == FeedbackCategory.bug ? severity : null,
      userId: userId,
      userName: userName.isNotEmpty ? userName : 'PopVerse Fan',
      userAvatar: userAvatar,
      appVersion: appVersion,
      createdAt: DateTime.now(),
      upvotedUserIds: initialUpvotedIds,
      isUpvoted: true,
    );
  }

  @override
  Future<void> toggleVote({
    required String feedbackId,
    required String userId,
  }) async {
    if (userId.isEmpty) return;

    final docRef = _feedbacksCollection.doc(feedbackId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final ownerId = data['userId'] as String? ?? '';
      final upvotedIds = List<String>.from(
        (data['upvotedUserIds'] as List<dynamic>?)?.map((e) => e.toString()) ??
            [],
      );
      int currentVotes = (data['votes'] as num?)?.toInt() ?? 0;

      if (upvotedIds.contains(userId)) {
        // Creator's upvote is permanent baseline
        if (userId == ownerId) {
          return;
        }
        // Cancel upvote (-1)
        upvotedIds.remove(userId);
        currentVotes = (currentVotes - 1).clamp(0, 99999);
      } else {
        // Add upvote (+1)
        upvotedIds.add(userId);
        currentVotes += 1;
      }

      transaction.update(docRef, {
        'votes': currentVotes,
        'upvotedUserIds': upvotedIds,
      });
    });
  }

  @override
  Future<void> addComment({
    required String feedbackId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String text,
    String? commentId,
  }) async {
    final id = commentId ?? '${userId}_${DateTime.now().microsecondsSinceEpoch}';
    final comment = {
      'id': id,
      'userId': userId,
      'name': userName.isNotEmpty ? userName : 'PopVerse Fan',
      'userAvatar': userAvatar,
      'time': DateTime.now().toIso8601String(),
      'text': text,
    };

    await _feedbacksCollection.doc(feedbackId).set({
      'comments': FieldValue.arrayUnion([comment]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateComments({
    required String feedbackId,
    required List<Map<String, dynamic>> comments,
  }) async {
    await _feedbacksCollection.doc(feedbackId).update({'comments': comments});
  }

  @override
  Future<void> deleteFeedback(String feedbackId) async {
    await _storageService.deleteFeedbackMedia(feedbackId);
    await _feedbacksCollection.doc(feedbackId).delete();
  }
}
