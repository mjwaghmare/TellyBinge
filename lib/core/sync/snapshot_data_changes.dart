import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps query snapshots to their documents' data, skipping snapshots whose
/// data is unchanged.
///
/// Listeners with `includeMetadataChanges: true` (needed for the sync banner)
/// also fire when a pending write is confirmed or the cache/server source
/// flips. Those snapshots carry identical data, and re-emitting them makes
/// every watchlist consumer compare and rebuild the whole list.
StreamTransformer<QuerySnapshot<Map<String, dynamic>>, List<Map<String, dynamic>>> dataChangesOnly() {
  return StreamTransformer.fromBind((snapshots) {
    // Per-subscription: the data last emitted, by document id.
    Map<String, Map<String, dynamic>>? previous;
    return snapshots.where((snapshot) {
      final last = previous;
      if (last != null && !_hasDataChanges(snapshot, last)) return false;
      previous = {for (final doc in snapshot.docs) doc.id: doc.data()};
      return true;
    }).map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  });
}

bool _hasDataChanges(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  Map<String, Map<String, dynamic>> previous,
) {
  for (final change in snapshot.docChanges) {
    if (change.type != DocumentChangeType.modified || change.oldIndex != change.newIndex) {
      return true;
    }
    final before = previous[change.doc.id];
    if (before == null || !_deepEquals(before, change.doc.data())) return true;
  }
  return false;
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
