import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/sync/pending_writes.dart';
import '../../../../core/sync/pending_writes_firestore.dart';
import '../../domain/models/custom_list_item_model.dart';
import '../../domain/models/custom_list_model.dart';
import '../../domain/repositories/custom_lists_repository.dart';

class CustomListsRepositoryImpl implements CustomListsRepository {
  final FirebaseFirestore _firestore;

  CustomListsRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _listsCollection(String uid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.customLists);

  /// Shared Firestore listener and controller that replays the latest snapshot
  /// to new listeners without canceling the underlying Firestore subscription.
  StreamController<QuerySnapshot<Map<String, dynamic>>>? _snapshotController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  QuerySnapshot<Map<String, dynamic>>? _latestSnapshot;
  String? _snapshotUid;
  final Set<StreamController<QuerySnapshot<Map<String, dynamic>>>> _activeWrappers = {};

  void _cleanupSharedListener() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    if (_snapshotController != null && !_snapshotController!.isClosed) {
      _snapshotController!.close();
    }
    _snapshotController = null;
    _latestSnapshot = null;
    _snapshotUid = null;
  }

  void _ensureSharedListener(String uid) {
    if (_snapshotUid != uid) {
      _cleanupSharedListener();
      _snapshotUid = uid;
      for (final wrapper in _activeWrappers.toList()) {
        if (!wrapper.isClosed) {
          wrapper.close();
        }
      }
      _activeWrappers.clear();
    }

    if (_snapshotController == null || _snapshotController!.isClosed) {
      _snapshotController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      _firestoreSub = _listsCollection(uid)
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) {
              _latestSnapshot = snapshot;
              if (_snapshotController != null && !_snapshotController!.isClosed) {
                _snapshotController!.add(snapshot);
              }
            },
            onError: (error, stack) {
              if (_snapshotController != null && !_snapshotController!.isClosed) {
                _snapshotController!.addError(error, stack);
              }
            },
            onDone: () {
              final controller = _snapshotController;
              _cleanupSharedListener();
              if (controller != null && !controller.isClosed) {
                controller.close();
              }
            },
          );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _snapshotStream(String uid) {
    late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? broadcastSub;

    controller = StreamController<QuerySnapshot<Map<String, dynamic>>>(
      onListen: () {
        if (_snapshotUid != null && _snapshotUid != uid) {
          if (!controller.isClosed) {
            controller.close();
          }
          return;
        }

        _ensureSharedListener(uid);
        _activeWrappers.add(controller);

        QuerySnapshot<Map<String, dynamic>>? lastEmitted;
        final currentLatest = _latestSnapshot;
        if (currentLatest != null) {
          lastEmitted = currentLatest;
          controller.add(currentLatest);
        }
        broadcastSub = _snapshotController?.stream.listen(
          (snapshot) {
            if (snapshot != lastEmitted) {
              lastEmitted = snapshot;
              controller.add(snapshot);
            }
          },
          onError: controller.addError,
          onDone: () {
            _activeWrappers.remove(controller);
            if (!controller.isClosed) {
              controller.close();
            }
          },
        );
      },
      onCancel: () {
        broadcastSub?.cancel();
        _activeWrappers.remove(controller);
        if (!controller.isClosed) {
          controller.close();
        }
        if (_activeWrappers.isEmpty) {
          _cleanupSharedListener();
        }
      },
    );

    return controller.stream;
  }

  @override
  Stream<List<CustomListModel>> watchCustomLists(String uid) {
    return _snapshotStream(uid).map((snapshot) {
      return snapshot.docs.map((doc) {
        return CustomListModel.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<PendingWrites> watchPendingWrites(String uid) {
    return _snapshotStream(uid).map(pendingWritesFromSnapshot).distinct();
  }

  @override
  Future<String> createList({
    required String uid,
    required String name,
    String? description,
  }) async {
    final now = DateTime.now().toIso8601String();
    final docRef = await _listsCollection(uid).add({
      'name': name.trim(),
      'description': description?.trim() ?? '',
      'createdAt': now,
      'updatedAt': now,
      'items': <Map<String, dynamic>>[],
    });
    return docRef.id;
  }

  @override
  Future<void> updateList({
    required String uid,
    required String listId,
    required String name,
    String? description,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _listsCollection(uid).doc(listId).update({
      'name': name.trim(),
      if (description != null) 'description': description.trim(),
      'updatedAt': now,
    });
  }

  @override
  Future<void> deleteList({
    required String uid,
    required String listId,
  }) async {
    await _listsCollection(uid).doc(listId).delete();
  }

  @override
  Future<void> toggleItemInList({
    required String uid,
    required String listId,
    required CustomListItemModel item,
  }) async {
    final docRef = _listsCollection(uid).doc(listId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final existingIndex = items.indexWhere(
        (i) => i['id'] == item.id && i['mediaType'] == item.mediaType,
      );

      if (existingIndex >= 0) {
        items.removeAt(existingIndex);
      } else {
        if (items.length >= CustomListsRepository.maxItemsPerList) {
          throw StateError(
            'List has reached the maximum limit of ${CustomListsRepository.maxItemsPerList} items.',
          );
        }
        items.insert(0, item.toJson());
      }

      transaction.update(docRef, {
        'items': items,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Future<void> removeItemFromList({
    required String uid,
    required String listId,
    required int mediaId,
    required String mediaType,
  }) async {
    final docRef = _listsCollection(uid).doc(listId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final existingIndex = items.indexWhere(
        (i) => i['id'] == mediaId && i['mediaType'] == mediaType,
      );

      if (existingIndex >= 0) {
        items.removeAt(existingIndex);
        transaction.update(docRef, {
          'items': items,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }
}
