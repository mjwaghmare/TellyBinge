import 'package:equatable/equatable.dart';

class SyncStatusState extends Equatable {
  final bool hasPendingWrites;
  final bool justSynced;

  /// Writes still waiting on the server, across all monitored sources.
  final int pendingCount;

  /// Writes queued since this sync began, including ones already confirmed.
  final int syncTotal;

  /// Whether any source is receiving snapshots from the server.
  final bool isOnline;

  const SyncStatusState({
    this.hasPendingWrites = false,
    this.justSynced = false,
    this.pendingCount = 0,
    this.syncTotal = 0,
    this.isOnline = true,
  });

  bool get shouldShowBanner => hasPendingWrites || justSynced;

  /// Whether the banner shows an upload percentage.
  bool get isSyncing => hasPendingWrites && !justSynced && isOnline;

  /// Fraction of this sync's writes the server has confirmed, 0.0 to 1.0.
  double get progress => syncTotal == 0 ? 0 : (syncTotal - pendingCount) / syncTotal;

  String get bannerText {
    if (justSynced) return 'All changes synced';
    if (isSyncing) return 'Syncing';
    return switch (pendingCount) {
      0 => 'Offline · will sync',
      1 => 'Offline · 1 change waiting',
      _ => 'Offline · $pendingCount changes waiting',
    };
  }

  SyncStatusState copyWith({
    bool? hasPendingWrites,
    bool? justSynced,
    int? pendingCount,
    int? syncTotal,
    bool? isOnline,
  }) {
    return SyncStatusState(
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
      justSynced: justSynced ?? this.justSynced,
      pendingCount: pendingCount ?? this.pendingCount,
      syncTotal: syncTotal ?? this.syncTotal,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [hasPendingWrites, justSynced, pendingCount, syncTotal, isOnline];
}
