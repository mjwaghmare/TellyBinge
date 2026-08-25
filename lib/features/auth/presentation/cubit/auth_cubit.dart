import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;
  StreamSubscription? _userSubscription;

  AuthCubit({required this.authRepository}) : super(AuthInitial()) {
    _monitorAuthState();
  }

  void _monitorAuthState() {
    emit(AuthLoading());
    _userSubscription?.cancel();
    _userSubscription = authRepository.user.listen(
      (user) {
        if (user != null) {
          emit(Authenticated(user));
        } else {
          emit(Unauthenticated());
        }
      },
      onError: (error) {
        emit(AuthError(error.toString()));
      },
    );
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoginLoading());
    try {
      final user = await authRepository.signInWithGoogle();
      if (user == null) {
        emit(Unauthenticated()); // User cancelled login
      } else {
        emit(Authenticated(user));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await authRepository.signOut();
      // The watchlist streams close on sign-out, so nothing would resubmit or
      // cancel what is already scheduled for this account.
      await NotificationService().clearForSignOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> deleteAccount() async {
    emit(AuthLoading());
    try {
      await authRepository.deleteAccount();
      await NotificationService().clearForSignOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
