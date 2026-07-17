import '../models/user_model.dart';

abstract class AuthRepository {
  Stream<UserModel?> get user;
  Future<UserModel?> signInWithGoogle();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
}
