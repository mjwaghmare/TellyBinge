import 'package:equatable/equatable.dart';
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
  final String message;

  const CustomListsError(this.message);

  @override
  List<Object?> get props => [message];
}
