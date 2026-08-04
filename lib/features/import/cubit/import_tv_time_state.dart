import 'dart:io';
import 'package:equatable/equatable.dart';

enum ImportTvTimeStatus {
  initial,
  pickingFile,
  fileSelected,
  processing,
  completed,
  failure,
}

class ImportTvTimeState extends Equatable {
  const ImportTvTimeState({
    this.status = ImportTvTimeStatus.initial,
    this.file,
    this.errorMessage,
    this.progress = 0,
    this.statusMessage = '',
  });

  final ImportTvTimeStatus status;
  final File? file;
  final String? errorMessage;
  final double progress;
  final String statusMessage;

  bool get hasFile => file != null;

  String get fileName => file?.path.split('/').last ?? 'No ZIP selected';

  ImportTvTimeState copyWith({
    ImportTvTimeStatus? status,
    File? file,
    bool clearFile = false,
    String? errorMessage,
    double? progress,
    String? statusMessage,
  }) {
    return ImportTvTimeState(
      status: status ?? this.status,
      file: clearFile ? null : file ?? this.file,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        file,
        errorMessage,
        progress,
        statusMessage,
      ];
}

