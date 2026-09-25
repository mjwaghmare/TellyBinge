import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/auth/domain/models/user_model.dart';
import 'package:popverse/features/auth/domain/repositories/auth_repository.dart';
import 'package:popverse/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:popverse/features/auth/presentation/cubit/auth_state.dart';

class MockAuthRepository implements AuthRepository {
  final _userController = StreamController<UserModel?>.broadcast();
  UserModel? mockUser;
  bool shouldThrowGoogleSignIn = false;
  bool shouldCancelGoogleSignIn = false;
  bool shouldCancelDeleteAccount = false;
  bool shouldThrowDeleteAccount = false;
  int signOutCallCount = 0;
  int deleteAccountCallCount = 0;

  void emitUser(UserModel? user) {
    mockUser = user;
    _userController.add(user);
  }

  @override
  Stream<UserModel?> get user => _userController.stream;

  @override
  Future<UserModel?> getCurrentUser() async => mockUser;

  @override
  Future<UserModel?> signInWithGoogle() async {
    if (shouldCancelGoogleSignIn) {
      return null;
    }
    if (shouldThrowGoogleSignIn) {
      throw Exception('Network connection failed');
    }
    return mockUser;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    if (shouldCancelDeleteAccount) {
      throw Exception('Account deletion cancelled.');
    }
    if (shouldThrowDeleteAccount) {
      throw Exception('Account deletion failed');
    }
  }

  void dispose() {
    _userController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository repository;
  late AuthCubit cubit;

  final testUser = UserModel(
    uid: 'user_123',
    email: 'test@example.com',
    displayName: 'Test User',
    photoUrl: 'https://example.com/avatar.png',
  );

  setUp(() {
    repository = MockAuthRepository();
    cubit = AuthCubit(authRepository: repository);
  });

  tearDown(() async {
    await cubit.close();
    repository.dispose();
  });

  group('AuthCubit account operations and security trust flows', () {
    test('Google sign-in cancellation is a silent no-op for unauthenticated user', () async {
      repository.emitUser(null);
      await pumpEventQueue();

      expect(cubit.state, isA<Unauthenticated>());

      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      repository.shouldCancelGoogleSignIn = true;
      await cubit.signInWithGoogle();
      await pumpEventQueue();

      // Should transition through loading to Unauthenticated, never AuthError
      expect(states, [
        isA<AuthLoginLoading>(),
        isA<Unauthenticated>(),
      ]);
      expect(cubit.state, isA<Unauthenticated>());

      await sub.cancel();
    });

    test('Google sign-in cancellation is a silent no-op for guest user', () async {
      cubit.continueAsGuest();
      expect(cubit.state, isA<AuthGuest>());

      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      repository.shouldCancelGoogleSignIn = true;
      await cubit.signInWithGoogle();
      await pumpEventQueue();

      // Should return back to AuthGuest silently without AuthError
      expect(states, [
        predicate<AuthState>((s) => s is AuthLoginLoading && s.isGuest),
        isA<AuthGuest>(),
      ]);
      expect(cubit.state, isA<AuthGuest>());

      await sub.cancel();
    });

    test('signOut transitions directly to Unauthenticated without emitting AuthLoading', () async {
      repository.emitUser(testUser);
      await pumpEventQueue();

      expect(cubit.state, isA<Authenticated>());

      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.signOut();
      await pumpEventQueue();

      // Must be visually instant: only Unauthenticated emitted, no AuthLoading
      expect(states, [isA<Unauthenticated>()]);
      expect(repository.signOutCallCount, equals(1));

      await sub.cancel();
    });

    test('deleteAccount cancellation silently preserves authenticated state', () async {
      repository.emitUser(testUser);
      await pumpEventQueue();

      expect(cubit.state, isA<Authenticated>());

      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      repository.shouldCancelDeleteAccount = true;
      await cubit.deleteAccount();
      await pumpEventQueue();

      // Did not emit Unauthenticated or AuthError
      expect(states, isEmpty);
      expect(cubit.state, isA<Authenticated>());
      expect(repository.deleteAccountCallCount, equals(1));

      await sub.cancel();
    });

    test('deleteAccount success emits Unauthenticated without decorative AuthLoading', () async {
      repository.emitUser(testUser);
      await pumpEventQueue();

      expect(cubit.state, isA<Authenticated>());

      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.deleteAccount();
      await pumpEventQueue();

      expect(states, [isA<Unauthenticated>()]);
      expect(repository.deleteAccountCallCount, equals(1));

      await sub.cancel();
    });
  });
}
