import '../models/custom_list_item_model.dart';
import '../models/custom_list_model.dart';

abstract class CustomListsRepository {
  /// Maximum number of items allowed per custom list to ensure documents stay well
  /// within Firestore's 1 MiB document size limit.
  static const int maxItemsPerList = 500;

  Stream<List<CustomListModel>> watchCustomLists(String uid);
  Stream<bool> watchPendingWrites(String uid);

  Future<String> createList({
    required String uid,
    required String name,
    String? description,
  });

  Future<void> updateList({
    required String uid,
    required String listId,
    required String name,
    String? description,
  });

  Future<void> deleteList({
    required String uid,
    required String listId,
  });

  Future<void> toggleItemInList({
    required String uid,
    required String listId,
    required CustomListItemModel item,
  });

  Future<void> removeItemFromList({
    required String uid,
    required String listId,
    required int mediaId,
    required String mediaType,
  });
}
