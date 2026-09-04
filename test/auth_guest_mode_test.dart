import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:popverse/features/auth/domain/models/user_model.dart';
import 'package:popverse/features/auth/domain/repositories/auth_repository.dart';
import 'package:popverse/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:popverse/features/auth/presentation/cubit/auth_state.dart';
import 'package:popverse/features/auth/presentation/widgets/auth_required_view.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Stream<UserModel?> get user => Stream.value(null);

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<UserModel?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  group('Guest Mode Tests', () {
    test('AuthCubit continueAsGuest emits AuthGuest state', () async {
      final repo = MockAuthRepository();
      final cubit = AuthCubit(authRepository: repo);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      cubit.continueAsGuest();
      expect(cubit.state, isA<AuthGuest>());
      await cubit.close();
    });

    test(
      'AuthCubit preserves AuthGuest if Google sign-in is cancelled',
      () async {
        final repo = MockAuthRepository();
        final cubit = AuthCubit(authRepository: repo);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        cubit.continueAsGuest();
        expect(cubit.state, isA<AuthGuest>());

        await cubit.signInWithGoogle();
        expect(cubit.state, isA<AuthGuest>());
        await cubit.close();
      },
    );

    testWidgets(
      'AuthRequiredView renders title, features, and sign in button',
      (tester) async {
        final repo = MockAuthRepository();
        final cubit = AuthCubit(authRepository: repo);

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<AuthCubit>.value(
              value: cubit,
              child: const Scaffold(
                body: AuthRequiredView(
                  icon: Icons.tv_rounded,
                  title: 'Track TV Shows',
                  subtitle: 'Never miss an episode.',
                  features: ['Feature 1', 'Feature 2'],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Track TV Shows'), findsOneWidget);
        expect(find.text('Never miss an episode.'), findsOneWidget);
        expect(find.text('Feature 1'), findsOneWidget);
        expect(find.text('Feature 2'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets('AuthRequiredBottomSheet renders modal and sign in button', (
      tester,
    ) async {
      final repo = MockAuthRepository();
      final cubit = AuthCubit(authRepository: repo);

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    AuthRequiredBottomSheet.show(
                      context,
                      title: 'Sign in to Track',
                      subtitle: 'Sign in to add items to your watchlist.',
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Track'), findsOneWidget);
      expect(
        find.text('Sign in to add items to your watchlist.'),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);

      await cubit.close();
    });
  });
}
