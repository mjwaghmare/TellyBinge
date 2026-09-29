import 'package:equatable/equatable.dart';

/// Local writes a Firestore listener is still waiting on the server to confirm.
class PendingWrites extends Equatable {
  /// Documents with unconfirmed local writes.
  final int count;

  /// Whether the latest snapshot came from the server rather than the cache.
  final bool isOnline;

  const PendingWrites({this.count = 0, this.isOnline = true});

  static const none = PendingWrites();

  @override
  List<Object?> get props => [count, isOnline];
}
