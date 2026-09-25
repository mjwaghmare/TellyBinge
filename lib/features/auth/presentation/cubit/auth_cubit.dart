import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
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
        emit(AuthError(Failure.fromException(error)));
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
        emit(AuthError(Failure.fromException(e), isGuest: true));
        emit(AuthGuest());
      } else {
        emit(AuthError(Failure.fromException(e)));
      }
    }
  }

  Future<void> signOut() async {
    try {
      await authRepository.signOut();
      // The watchlist streams close on sign-out, so nothing would resubmit or
      // cancel what is already scheduled for this account.
      try {
        await NotificationService().clearForSignOut();
      } catch (_) {}
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(Failure.fromException(e)));
    }
  }

  Future<void> deleteAccount() async {
    try {
      await authRepository.deleteAccount();
      try {
        await NotificationService().clearForSignOut();
      } catch (_) {}
      emit(Unauthenticated());
    } catch (e) {
      if (e.toString().contains('Account deletion cancelled.')) {
        // User cancelled re-authentication; remain in current state
        return;
      }
      emit(AuthError(Failure.fromException(e)));
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
