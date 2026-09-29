import 'package:cloud_firestore/cloud_firestore.dart';
import 'pending_writes.dart';

/// Reads the unconfirmed local writes from a listener snapshot (the listener
/// must use `includeMetadataChanges: true`).
///
/// A pending delete removes its document from the snapshot, so the
/// snapshot-level flag still counts as one pending write when no remaining
/// document carries one.
PendingWrites pendingWritesFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
  final pendingDocs = snapshot.docs.where((doc) => doc.metadata.hasPendingWrites).length;
  return PendingWrites(
    count: pendingDocs == 0 && snapshot.metadata.hasPendingWrites ? 1 : pendingDocs,
    isOnline: !snapshot.metadata.isFromCache,
  );
}
