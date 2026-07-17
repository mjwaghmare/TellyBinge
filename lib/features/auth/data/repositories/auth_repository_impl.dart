import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<UserModel?> get user {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      try {
        return await _getUserFromFirestore(firebaseUser.uid);
      } catch (e) {
        return null;
      }
    });
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;
    return await _getUserFromFirestore(firebaseUser.uid);
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

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
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
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }

  Future<UserModel?> _getUserFromFirestore(String uid) async {
    try {
      // 1. Try to fetch from local offline cache first (Instant startup)
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
    } catch (_) {
      // Cache miss or local database not yet populated
    }

    try {
      // 2. Fallback to server if cache doesn't exist
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user from database: $e');
    }
  }

  Future<UserModel> _syncUserToFirestore(User firebaseUser) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      // New user
      final newUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
      );
      await docRef.set(newUser.toMap());
      return newUser;
    } else {
      // Existing user: check if we should update display name or photo
      final existingUser = UserModel.fromMap(doc.data()!);
      final updatedUser = existingUser.copyWith(
        displayName: firebaseUser.displayName ?? existingUser.displayName,
        photoUrl: firebaseUser.photoURL ?? existingUser.photoUrl,
      );
      await docRef.update({
        'displayName': updatedUser.displayName,
        'photoUrl': updatedUser.photoUrl,
      });
      return updatedUser;
    }
  }
}
