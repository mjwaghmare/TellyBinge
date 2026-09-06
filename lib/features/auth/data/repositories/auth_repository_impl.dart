import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<UserModel?> get user {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      try {
        return await _getUserFromFirestore(firebaseUser.uid, firebaseUser);
      } catch (e) {
        return null;
      }
    });
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;
    return await _getUserFromFirestore(firebaseUser.uid, firebaseUser);
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) return null;

      // Sync user data to firestore
      return await _syncUserToFirestore(firebaseUser);
    } catch (e) {
      // Clear sign-in state so subsequent clicks are not blocked
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      throw Exception('Google Sign-In failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }

  @override
  Future<void> deleteAccount() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return;
    final uid = firebaseUser.uid;

    // 1. Delete user profile document from Firestore
    try {
      await _firestore.collection(FirestoreCollections.users).doc(uid).delete();
    } catch (e) {
      // Continue even if Firestore doc deletion fails
    }

    // 2. Delete Firebase Auth user
    try {
      await firebaseUser.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'For security, please sign out and sign in again before deleting your account.',
        );
      }
      throw Exception('Account deletion failed: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }

    // 3. Clear Google Sign-In local session
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<UserModel?> _getUserFromFirestore(String uid, [User? firebaseUser]) async {
    final currentFbUser = firebaseUser ?? _firebaseAuth.currentUser;
    bool hasAdminClaim = false;
    if (currentFbUser != null && currentFbUser.uid == uid) {
      try {
        final tokenResult = await currentFbUser.getIdTokenResult();
        hasAdminClaim = tokenResult.claims?['admin'] == true;
      } catch (_) {}
    }

    try {
      // 1. Try to fetch from local offline cache first (Instant startup)
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, hasAdminClaim: hasAdminClaim);
      }
    } catch (_) {
      // Cache miss or local database not yet populated
    }

    try {
      // 2. Fallback to server if cache doesn't exist
      final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, hasAdminClaim: hasAdminClaim);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user from database: $e');
    }
  }

  Future<UserModel> _syncUserToFirestore(User firebaseUser) async {
    bool hasAdminClaim = false;
    try {
      final tokenResult = await firebaseUser.getIdTokenResult();
      hasAdminClaim = tokenResult.claims?['admin'] == true;
    } catch (_) {}

    final docRef = _firestore.collection(FirestoreCollections.users).doc(firebaseUser.uid);
    final doc = await docRef.get();
    final userEmail = (firebaseUser.email ?? '').trim().toLowerCase();
    final fallbackAdmin = AppConstants.fallbackAdminEmail.trim().toLowerCase();
    final isFallbackAdmin = fallbackAdmin.isNotEmpty && userEmail == fallbackAdmin;
    final isAdminUser = hasAdminClaim || isFallbackAdmin;

    if (!doc.exists) {
      // New user
      final newUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        role: isAdminUser ? 'admin' : 'user',
        hasAdminClaim: hasAdminClaim,
      );
      await docRef.set(newUser.toMap());
      return newUser;
    } else {
      // Existing user: check if we should update display name or photo
      final existingUser = UserModel.fromMap(
        doc.data()!,
        hasAdminClaim: hasAdminClaim,
      );
      final assignedRole = isAdminUser ? 'admin' : existingUser.role;
      final updatedUser = existingUser.copyWith(
        displayName: firebaseUser.displayName ?? existingUser.displayName,
        photoUrl: firebaseUser.photoURL ?? existingUser.photoUrl,
        role: assignedRole,
        hasAdminClaim: hasAdminClaim,
      );
      await docRef.update({
        'displayName': updatedUser.displayName,
        'photoUrl': updatedUser.photoUrl,
        if (isAdminUser && existingUser.role != 'admin') 'role': 'admin',
      });
      return updatedUser;
    }
  }
}
