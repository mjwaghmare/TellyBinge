import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/sync/snapshot_data_changes.dart';

// ignore: subtype_of_sealed_class
class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  _Doc(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;
}

class _Change extends Fake implements DocumentChange<Map<String, dynamic>> {
  @override
  final DocumentChangeType type;
  @override
  final _Doc doc;
  @override
  final int oldIndex;
  @override
  final int newIndex;

  _Change(this.type, this.doc, {this.oldIndex = 0, this.newIndex = 0});
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<_Doc> docs;
  @override
  final List<_Change> docChanges;

  _Snapshot(this.docs, this.docChanges);
}

void main() {
  late StreamController<QuerySnapshot<Map<String, dynamic>>> source;
  late List<List<Map<String, dynamic>>> emitted;

  setUp(() {
    source = StreamController();
    emitted = [];
    source.stream.transform(dataChangesOnly()).listen(emitted.add);
  });

  tearDown(() => source.close());

  _Doc show(String id, {bool watched = false}) => _Doc(id, {
        'id': id,
        'watchedEpisodes': watched ? ['S1E1'] : <String>[],
      });

  test('emits the first snapshot, even an empty one', () async {
    source.add(_Snapshot([], []));
    await pumpEventQueue();
    expect(emitted, [<Map<String, dynamic>>[]]);
  });

  test('skips metadata-only snapshots with no document changes', () async {
    final a = show('a');
    source.add(_Snapshot([a], [_Change(DocumentChangeType.added, a)]));
    source.add(_Snapshot([a], [])); // e.g. isFromCache flipped
    await pumpEventQueue();
    expect(emitted, hasLength(1));
  });

  test('skips a pending write being confirmed with identical data', () async {
    source.add(_Snapshot([show('a', watched: true)], [_Change(DocumentChangeType.added, show('a', watched: true))]));
    final confirmed = show('a', watched: true); // new map, same content
    source.add(_Snapshot([confirmed], [_Change(DocumentChangeType.modified, confirmed)]));
    await pumpEventQueue();
    expect(emitted, hasLength(1));
  });

  test('emits when a document really changes', () async {
    source.add(_Snapshot([show('a')], [_Change(DocumentChangeType.added, show('a'))]));
    final watched = show('a', watched: true);
    source.add(_Snapshot([watched], [_Change(DocumentChangeType.modified, watched)]));
    await pumpEventQueue();
    expect(emitted, hasLength(2));
    expect(emitted.last.single['watchedEpisodes'], ['S1E1']);
  });

  test('emits on add, remove and reorder', () async {
    final a = show('a');
    final b = show('b');
    source.add(_Snapshot([a], [_Change(DocumentChangeType.added, a)]));
    source.add(_Snapshot([a, b], [_Change(DocumentChangeType.added, b, newIndex: 1)]));
    source.add(_Snapshot([b, a], [_Change(DocumentChangeType.modified, a, oldIndex: 0, newIndex: 1)]));
    source.add(_Snapshot([b], [_Change(DocumentChangeType.removed, a)]));
    await pumpEventQueue();
    expect(emitted.map((docs) => docs.map((d) => d['id']).toList()), [
      ['a'],
      ['a', 'b'],
      ['b', 'a'],
      ['b'],
    ]);
  });
}
