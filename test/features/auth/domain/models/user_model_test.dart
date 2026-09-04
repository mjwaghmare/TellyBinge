import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/auth/domain/models/user_model.dart';

void main() {
  group('UserModel admin and role tests', () {
    test('identifies admin by specific email mjwaghmare.mtw@gmail.com', () {
      const adminUser = UserModel(
        uid: 'admin-1',
        email: 'mjwaghmare.mtw@gmail.com',
        displayName: 'Dev Admin',
        photoUrl: '',
      );

      expect(adminUser.isAdmin, isTrue);
    });

    test('identifies admin by case-insensitive trimmed email', () {
      const adminUser = UserModel(
        uid: 'admin-1',
        email: '  MJWAGHMARE.MTW@GMAIL.COM  ',
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

    test('fromMap automatically assigns admin role to mjwaghmare.mtw@gmail.com', () {
      final user = UserModel.fromMap({
        'uid': 'admin-3',
        'email': 'mjwaghmare.mtw@gmail.com',
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
  });
}
