import 'dart:async';
import 'package:flutter/foundation.dart';
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
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            if (user.isAdmin) {
              unawaited(
                NotificationService().scheduleReinstallReminderIfNeeded(
                  isAdmin: true,
                ),
              );
            } else {
              unawaited(NotificationService().cancelReinstallReminders());
            }
          }
        } else {
          emit(Unauthenticated());
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            unawaited(NotificationService().cancelReinstallReminders());
          }
        }
      },
      onError: (error) {
        emit(AuthError(error.toString()));
      },
    );
  }

  void continueAsGuest() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(NotificationService().cancelReinstallReminders());
    }
    emit(AuthGuest());
  }

  Future<void> signInWithGoogle() async {
    final wasGuest =
        state is AuthGuest ||
        (state is AuthLoginLoading && (state as AuthLoginLoading).isGuest);
    emit(AuthLoginLoading(isGuest: wasGuest));
    try {
      final user = await authRepository.signInWithGoogle();
      if (user == null) {
        if (wasGuest) {
          emit(AuthGuest());
        } else {
          emit(Unauthenticated()); // User cancelled login
        }
      } else {
        emit(Authenticated(user));
      }
    } catch (e) {
      if (wasGuest) {
        emit(AuthError(e.toString(), isGuest: true));
        emit(AuthGuest());
      } else {
        emit(AuthError(e.toString()));
      }
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
