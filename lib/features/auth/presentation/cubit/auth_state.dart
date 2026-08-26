import 'package:equatable/equatable.dart';
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
  final String message;
  final bool isGuest;

  const AuthError(this.message, {this.isGuest = false});

  @override
  List<Object?> get props => [message, isGuest];
}
