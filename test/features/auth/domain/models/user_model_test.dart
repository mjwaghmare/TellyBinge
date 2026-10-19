import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/constants/app_constants.dart';
import 'package:popverse/features/auth/domain/models/user_model.dart';

void main() {
  group('UserModel admin and role tests', () {
    test('identifies admin by specific email from AppConstants.fallbackAdminEmail', () {
      const adminUser = UserModel(
        uid: 'admin-1',
        email: AppConstants.fallbackAdminEmail,
        displayName: 'Dev Admin',
        photoUrl: '',
      );

      expect(adminUser.isAdmin, isTrue);
    });

    test('identifies admin by case-insensitive trimmed email', () {
      final adminUser = UserModel(
        uid: 'admin-1',
        email: '  ${AppConstants.fallbackAdminEmail.toUpperCase()}  ',
        displayName: 'Dev Admin',
        photoUrl: '',
      );

      expect(adminUser.isAdmin, isTrue);
    });

    test('identifies admin by role property even if email is different', () {
      const adminUser = UserModel(
        uid: 'admin-2',
        email: 'secondary_admin@example.com',
        displayName: 'Co-Admin',
        photoUrl: '',
        role: 'admin',
      );

      expect(adminUser.isAdmin, isTrue);
    });

    test('regular user is not admin', () {
      const normalUser = UserModel(
        uid: 'user-1',
        email: 'john@example.com',
        displayName: 'John Doe',
        photoUrl: '',
        role: 'user',
      );

      expect(normalUser.isAdmin, isFalse);
    });

    test('fromMap automatically assigns admin role to AppConstants.fallbackAdminEmail', () {
      final user = UserModel.fromMap({
        'uid': 'admin-3',
        'email': AppConstants.fallbackAdminEmail,
        'displayName': 'Admin',
        'photoUrl': '',
      });

      expect(user.role, 'admin');
      expect(user.isAdmin, isTrue);
    });

    test('identifies admin by custom admin claim regardless of email or role', () {
      const claimedAdmin = UserModel(
        uid: 'admin-claim-1',
        email: 'anyone@random.com',
        displayName: 'Claim Admin',
        photoUrl: '',
        role: 'user',
        hasAdminClaim: true,
      );

      expect(claimedAdmin.isAdmin, isTrue);
    });

    test('fromMap preserves hasAdminClaim and sets admin role', () {
      final user = UserModel.fromMap(
        {
          'uid': 'admin-claim-2',
          'email': 'someuser@example.com',
          'displayName': 'Custom Claim User',
          'photoUrl': '',
          'role': 'user',
        },
        hasAdminClaim: true,
      );

      expect(user.hasAdminClaim, isTrue);
      expect(user.isAdmin, isTrue);
    });

    test('fromMap defaults to user role for regular emails', () {
      final user = UserModel.fromMap({
        'uid': 'user-2',
        'email': 'fan@popverse.app',
        'displayName': 'Fan',
        'photoUrl': '',
      });

      expect(user.role, 'user');
      expect(user.isAdmin, isFalse);
    });

    test('serializes and deserializes preferredGenres correctly', () {
      const user = UserModel(
        uid: 'user-genres',
        email: 'user@example.com',
        displayName: 'User',
        photoUrl: '',
        preferredGenres: ['Action', 'Sci-Fi', 'Horror'],
      );

      final map = user.toMap();
      expect(map['preferredGenres'], ['Action', 'Sci-Fi', 'Horror']);

      final restored = UserModel.fromMap(map);
      expect(restored.preferredGenres, ['Action', 'Sci-Fi', 'Horror']);
    });

    test('fromMap defaults preferredGenres to empty list when missing or invalid', () {
      final user1 = UserModel.fromMap({
        'uid': 'user-no-genres',
        'email': 'user@example.com',
        'displayName': 'User',
        'photoUrl': '',
      });
      expect(user1.preferredGenres, isEmpty);

      final user2 = UserModel.fromMap({
        'uid': 'user-null-genres',
        'email': 'user@example.com',
        'displayName': 'User',
        'photoUrl': '',
        'preferredGenres': null,
      });
      expect(user2.preferredGenres, isEmpty);
    });

    test('copyWith updates preferredGenres correctly', () {
      const user = UserModel(
        uid: 'user-copy',
        email: 'user@example.com',
        displayName: 'User',
        photoUrl: '',
        preferredGenres: ['Comedy'],
      );

      final updated = user.copyWith(preferredGenres: ['Drama', 'Thriller']);
      expect(updated.preferredGenres, ['Drama', 'Thriller']);
      expect(user.preferredGenres, ['Comedy']);
    });
  });
}
