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
  Stream<List<Map<String, dynamic>>> getCommentsStream(String feedbackId) {
    return _feedbacksCollection
        .doc(feedbackId)
        .collection('comments')
        .snapshots()
        .asyncMap((subSnapshot) async {
      if (subSnapshot.docs.isNotEmpty) {
        final comments = subSnapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return data;
        }).toList();

        comments.sort((a, b) {
          final aTime = a['time'] as String? ?? '';
          final bTime = b['time'] as String? ?? '';
          return bTime.compareTo(aTime);
        });
        return comments;
      }

      // Backward-compatibility: Check if parent doc has legacy comments array
      try {
        final parentDoc = await _feedbacksCollection.doc(feedbackId).get();
        final rawComments = parentDoc.data()?['comments'] as List<dynamic>?;
        if (rawComments != null && rawComments.isNotEmpty) {
          final legacyList = rawComments
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          legacyList.sort((a, b) {
            final aTime = a['time'] as String? ?? '';
            final bTime = b['time'] as String? ?? '';
            return bTime.compareTo(aTime);
          });
          return legacyList;
        }
      } catch (_) {}

      return <Map<String, dynamic>>[];
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

    await _feedbacksCollection
        .doc(feedbackId)
        .collection('comments')
        .doc(id)
        .set(comment);
  }

  @override
  Future<void> editComment({
    required String feedbackId,
    required String commentId,
    required String text,
  }) async {
    await _feedbacksCollection
        .doc(feedbackId)
        .collection('comments')
        .doc(commentId)
        .update({
      'text': text,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteComment({
    required String feedbackId,
    required String commentId,
  }) async {
    await _feedbacksCollection
        .doc(feedbackId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  @override
  Future<void> updateComments({
    required String feedbackId,
    required List<Map<String, dynamic>> comments,
  }) async {
    try {
      await _feedbacksCollection.doc(feedbackId).update({'comments': comments});
    } catch (_) {}
  }

  @override
  Future<void> deleteFeedback(String feedbackId) async {
    await _storageService.deleteFeedbackMedia(feedbackId);
    try {
      final commentsSnapshot = await _feedbacksCollection
          .doc(feedbackId)
          .collection('comments')
          .get();
      for (final doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
    await _feedbacksCollection.doc(feedbackId).delete();
  }
}
