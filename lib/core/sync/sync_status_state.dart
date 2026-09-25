import 'package:equatable/equatable.dart';

class SyncStatusState extends Equatable {
  final bool hasPendingWrites;
  final bool justSynced;

  const SyncStatusState({
    this.hasPendingWrites = false,
    this.justSynced = false,
  });

  bool get shouldShowBanner => hasPendingWrites || justSynced;

  String get bannerText =>
      justSynced ? 'All changes synced' : 'Offline · will sync';

  SyncStatusState copyWith({
    bool? hasPendingWrites,
    bool? justSynced,
  }) {
    return SyncStatusState(
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
      justSynced: justSynced ?? this.justSynced,
    );
  }

  @override
  List<Object?> get props => [hasPendingWrites, justSynced];
}
