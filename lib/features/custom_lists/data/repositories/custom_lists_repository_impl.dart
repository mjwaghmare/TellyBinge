import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
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

  @override
  Stream<List<CustomListModel>> watchCustomLists(String uid) {
    return _listsCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CustomListModel.fromJson(doc.data(), doc.id);
      }).toList();
    });
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
