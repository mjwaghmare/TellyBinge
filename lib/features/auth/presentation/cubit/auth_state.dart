import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthLoginLoading extends AuthState {
  final bool isGuest;

  const AuthLoginLoading({this.isGuest = false});

  @override
  List<Object?> get props => [isGuest];
}

class Authenticated extends AuthState {
  final UserModel user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthGuest extends AuthState {}

class AuthError extends AuthState {
  final Failure failure;
  final bool isGuest;
  String get message => failure.message;

  AuthError(Object error, {this.isGuest = false})
      : failure = error is Failure ? error : Failure.fromException(error);

  @override
  List<Object?> get props => [failure, isGuest];
}
