import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;
  StreamSubscription? _userSubscription;

  AuthCubit({required this.authRepository})
      : super(AuthInitial()) {
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
