import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/custom_list_item_model.dart';
import '../../domain/models/custom_list_model.dart';
import '../../domain/repositories/custom_lists_repository.dart';
import 'custom_lists_state.dart';

class CustomListsCubit extends Cubit<CustomListsState> {
  final CustomListsRepository customListsRepository;
  StreamSubscription<List<CustomListModel>>? _subscription;

  final _failureController = StreamController<Failure>.broadcast();
  Stream<Failure> get failureStream => _failureController.stream;

  CustomListsCubit({required this.customListsRepository})
      : super(CustomListsInitial());

  void watchCustomLists(String uid) {
    emit(CustomListsLoading());
    _subscription?.cancel();

    _subscription = customListsRepository
        .watchCustomLists(uid)
        .listen(
          (lists) {
            emit(CustomListsSuccess(lists));
          },
          onError: (error) {
            debugPrint('Error in CustomListsCubit.watchCustomLists: $error');
            final failure = Failure.fromException(error);
            emit(CustomListsError(failure));
          },
        );
  }

  void clearLists() {
    _subscription?.cancel();
    emit(CustomListsInitial());
  }

  Future<String?> createList({
    required String uid,
    required String name,
    String? description,
  }) async {
    try {
      final listId = await customListsRepository.createList(
        uid: uid,
        name: name,
        description: description,
      );
      return listId;
    } catch (e) {
      debugPrint('Error in CustomListsCubit.createList: $e');
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      return null;
    }
  }

  Future<bool> updateList({
    required String uid,
    required String listId,
    required String name,
    String? description,
  }) async {
    try {
      await customListsRepository.updateList(
        uid: uid,
        listId: listId,
        name: name,
        description: description,
      );
      return true;
    } catch (e) {
      debugPrint('Error in CustomListsCubit.updateList: $e');
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      return false;
    }
  }

  Future<bool> deleteList({
    required String uid,
    required String listId,
  }) async {
    try {
      await customListsRepository.deleteList(
        uid: uid,
        listId: listId,
      );
      return true;
    } catch (e) {
      debugPrint('Error in CustomListsCubit.deleteList: $e');
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      return false;
    }
  }

  Future<bool> toggleItemInList({
    required String uid,
    required String listId,
    required CustomListItemModel item,
  }) async {
    try {
      await customListsRepository.toggleItemInList(
        uid: uid,
        listId: listId,
        item: item,
      );
      return true;
    } catch (e) {
      debugPrint('Error in CustomListsCubit.toggleItemInList: $e');
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      return false;
    }
  }

  Future<bool> removeItemFromList({
    required String uid,
    required String listId,
    required int mediaId,
    required String mediaType,
  }) async {
    try {
      await customListsRepository.removeItemFromList(
        uid: uid,
        listId: listId,
        mediaId: mediaId,
        mediaType: mediaType,
      );
      return true;
    } catch (e) {
      debugPrint('Error in CustomListsCubit.removeItemFromList: $e');
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      return false;
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _failureController.close();
    return super.close();
  }
}
