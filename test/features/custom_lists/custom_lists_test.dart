import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/custom_lists/domain/models/custom_list_item_model.dart';
import 'package:popverse/features/custom_lists/domain/models/custom_list_model.dart';
import 'package:popverse/features/custom_lists/domain/repositories/custom_lists_repository.dart';
import 'package:popverse/features/custom_lists/presentation/cubit/custom_lists_cubit.dart';
import 'package:popverse/features/custom_lists/presentation/cubit/custom_lists_state.dart';

class MockCustomListsRepository implements CustomListsRepository {
  final _controller = StreamController<List<CustomListModel>>.broadcast();
  List<CustomListModel> _lists = [];

  @override
  Stream<List<CustomListModel>> watchCustomLists(String uid) => _controller.stream;

  @override
  Future<String> createList({
    required String uid,
    required String name,
    String? description,
  }) async {
    final newList = CustomListModel(
      id: 'list_123',
      name: name,
      description: description ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: const [],
    );
    _lists = [..._lists, newList];
    _controller.add(_lists);
    return 'list_123';
  }

  @override
  Future<void> updateList({
    required String uid,
    required String listId,
    required String name,
    String? description,
  }) async {
    _lists = _lists.map((l) {
      if (l.id == listId) {
        return l.copyWith(name: name, description: description);
      }
      return l;
    }).toList();
    _controller.add(_lists);
  }

  @override
  Future<void> deleteList({
    required String uid,
    required String listId,
  }) async {
    _lists = _lists.where((l) => l.id != listId).toList();
    _controller.add(_lists);
  }

  @override
  Future<void> toggleItemInList({
    required String uid,
    required String listId,
    required CustomListItemModel item,
  }) async {
    _lists = _lists.map((l) {
      if (l.id == listId) {
        final items = List<CustomListItemModel>.from(l.items);
        final idx = items.indexWhere((i) => i.id == item.id && i.mediaType == item.mediaType);
        if (idx >= 0) {
          items.removeAt(idx);
        } else {
          items.insert(0, item);
        }
        return l.copyWith(items: items);
      }
      return l;
    }).toList();
    _controller.add(_lists);
  }

  @override
  Future<void> removeItemFromList({
    required String uid,
    required String listId,
    required int mediaId,
    required String mediaType,
  }) async {
    _lists = _lists.map((l) {
      if (l.id == listId) {
        final items = l.items.where((i) => !(i.id == mediaId && i.mediaType == mediaType)).toList();
        return l.copyWith(items: items);
      }
      return l;
    }).toList();
    _controller.add(_lists);
  }
}

class _FailingCustomListsRepository implements CustomListsRepository {
  @override
  Stream<List<CustomListModel>> watchCustomLists(String uid) {
    return Stream.error(Exception('Firestore watch failed'));
  }

  @override
  Future<String> createList({required String uid, required String name, String? description}) async {
    throw Exception('Firestore write failed');
  }

  @override
  Future<void> updateList({required String uid, required String listId, required String name, String? description}) async {
    throw Exception('Firestore write failed');
  }

  @override
  Future<void> deleteList({required String uid, required String listId}) async {
    throw Exception('Firestore write failed');
  }

  @override
  Future<void> toggleItemInList({required String uid, required String listId, required CustomListItemModel item}) async {
    throw Exception('Firestore write failed');
  }

  @override
  Future<void> removeItemFromList({required String uid, required String listId, required int mediaId, required String mediaType}) async {
    throw Exception('Firestore write failed');
  }
}

void main() {
  group('CustomListItemModel', () {
    test('serialization & deserialization', () {
      final now = DateTime(2026, 9, 21);
      final item = CustomListItemModel(
        id: 101,
        mediaType: 'movie',
        title: 'Inception',
        posterPath: '/path.jpg',
        backdropPath: '/bg.jpg',
        voteAverage: 8.8,
        releaseDate: '2010-07-16',
        addedAt: now,
      );

      final json = item.toJson();
      expect(json['id'], 101);
      expect(json['mediaType'], 'movie');
      expect(json['title'], 'Inception');

      final parsed = CustomListItemModel.fromJson(json);
      expect(parsed.id, item.id);
      expect(parsed.mediaType, item.mediaType);
      expect(parsed.title, item.title);
      expect(parsed.isMovie, true);
      expect(parsed.isTvShow, false);
    });
  });

  group('CustomListModel', () {
    test('containsItem checks membership correctly', () {
      final item = CustomListItemModel(
        id: 42,
        mediaType: 'tv',
        title: 'Severance',
        addedAt: DateTime.now(),
      );

      final list = CustomListModel(
        id: 'list_1',
        name: 'Mind-bending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [item],
      );

      expect(list.containsItem(42, 'tv'), true);
      expect(list.containsItem(42, 'movie'), false);
      expect(list.containsItem(99, 'tv'), false);
      expect(list.itemCount, 1);
    });
  });

  group('CustomListsCubit', () {
    late MockCustomListsRepository repository;
    late CustomListsCubit cubit;

    setUp(() {
      repository = MockCustomListsRepository();
      cubit = CustomListsCubit(customListsRepository: repository);
    });

    tearDown(() {
      cubit.close();
    });

    test('watchCustomLists emits CustomListsLoading then CustomListsSuccess', () async {
      expect(cubit.state, isA<CustomListsInitial>());

      cubit.watchCustomLists('user_1');
      expect(cubit.state, isA<CustomListsLoading>());

      final expectation = expectLater(
        cubit.stream,
        emits(isA<CustomListsSuccess>().having(
          (s) => s.lists.first.name,
          'list name',
          'My List',
        )),
      );

      await repository.createList(uid: 'user_1', name: 'My List');
      await expectation;
    });

    test('createList, toggleItem, and deleteList work properly', () async {
      cubit.watchCustomLists('user_1');
      final listId = await cubit.createList(uid: 'user_1', name: 'Horror Marathon');
      expect(listId, 'list_123');

      final item = CustomListItemModel(
        id: 666,
        mediaType: 'movie',
        title: 'The Shining',
        addedAt: DateTime.now(),
      );

      final toggled = await cubit.toggleItemInList(uid: 'user_1', listId: listId!, item: item);
      expect(toggled, true);

      final removed = await cubit.removeItemFromList(
        uid: 'user_1',
        listId: listId,
        mediaId: 666,
        mediaType: 'movie',
      );
      expect(removed, true);

      final success = await cubit.deleteList(uid: 'user_1', listId: listId);
      expect(success, true);
    });

    test('CustomListsRepository.maxItemsPerList constant is 500', () {
      expect(CustomListsRepository.maxItemsPerList, 500);
    });

    test('cubit mutation methods return false/null when repository throws', () async {
      final failingRepo = _FailingCustomListsRepository();
      final failingCubit = CustomListsCubit(customListsRepository: failingRepo);

      final item = CustomListItemModel(
        id: 1,
        mediaType: 'movie',
        title: 'Test',
        addedAt: DateTime.now(),
      );

      expect(await failingCubit.createList(uid: 'u', name: 'n'), isNull);
      expect(await failingCubit.updateList(uid: 'u', listId: 'l', name: 'n'), false);
      expect(await failingCubit.deleteList(uid: 'u', listId: 'l'), false);
      expect(await failingCubit.toggleItemInList(uid: 'u', listId: 'l', item: item), false);
      expect(await failingCubit.removeItemFromList(uid: 'u', listId: 'l', mediaId: 1, mediaType: 'movie'), false);

      await failingCubit.close();
    });
  });
}
