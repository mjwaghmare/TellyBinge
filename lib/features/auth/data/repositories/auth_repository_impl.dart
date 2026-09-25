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

  bool _isGoogleSignInCanceled(Object e) {
    return e is GoogleSignInException &&
        e.code == GoogleSignInExceptionCode.canceled;
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Catch cancellation specifically at the authenticate() call site so
      // errors from later steps (_syncUserToFirestore) are never misclassified.
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return null;
        }
        rethrow;
      }
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

  Future<void> _reauthenticateWithGoogle(User user) async {
    final googleUser = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: null,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> deleteAccount() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return;
    final uid = firebaseUser.uid;

    // Snapshot the profile before deletion so we can restore it exactly if
    // Auth deletion fails (avoids regenerating from User fields which would
    // lose user-customized data).
    final profileRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(uid);
    final profileSnapshot = await profileRef.get();
    final profileData = profileSnapshot.data();

    // Restore helper: writes the original profile back, or falls back to
    // _syncUserToFirestore if no profile existed before deletion.
    Future<void> restoreProfile() async {
      try {
        if (profileData != null) {
          await profileRef.set(profileData);
        } else {
          await _syncUserToFirestore(firebaseUser);
        }
      } catch (_) {}
    }

    // Delete Firestore profile while still authenticated as owner (required by
    // security rules), then delete the Firebase Auth user.
    await profileRef.delete();

    try {
      await firebaseUser.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        try {
          await _reauthenticateWithGoogle(firebaseUser);
        } catch (reauthErr) {
          // Re-auth failed or cancelled — restore the profile so the user is
          // not left with an Auth account but no profile document.
          await restoreProfile();
          if (_isGoogleSignInCanceled(reauthErr)) {
            throw Exception('Account deletion cancelled.');
          }
          throw Exception('Account deletion failed: $reauthErr');
        }

        // Credentials are now fresh — retry Auth deletion.
        try {
          await firebaseUser.delete();
        } on FirebaseAuthException catch (deleteErr) {
          // Auth deletion failed after re-auth — restore the profile.
          await restoreProfile();
          throw Exception(
            'Account deletion failed: ${deleteErr.message ?? deleteErr.code}',
          );
        }
      } else {
        // Non-recoverable Auth error — restore the profile.
        await restoreProfile();
        throw Exception('Account deletion failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      // Unexpected error — restore the profile.
      await restoreProfile();
      throw Exception('Account deletion failed: $e');
    }

    // Clear Google Sign-In local session
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
