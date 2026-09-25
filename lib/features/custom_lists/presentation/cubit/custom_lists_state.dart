import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/custom_list_model.dart';

abstract class CustomListsState extends Equatable {
  const CustomListsState();

  @override
  List<Object?> get props => [];
}

class CustomListsInitial extends CustomListsState {}

class CustomListsLoading extends CustomListsState {}

class CustomListsSuccess extends CustomListsState {
  final List<CustomListModel> lists;

  const CustomListsSuccess(this.lists);

  @override
  List<Object?> get props => [lists];
}

class CustomListsError extends CustomListsState {
  final Failure failure;
  String get message => failure.message;

  CustomListsError(Object error)
      : failure = error is Failure ? error : Failure.fromException(error);

  @override
  List<Object?> get props => [failure];
}
