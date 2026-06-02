import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    await GoogleSignIn.instance.initialize();

    _googleInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    UserCredential userCredential;

    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      userCredential = await _auth.signInWithPopup(googleProvider);
    } else {
      await _ensureGoogleInitialized();

      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'],
      );

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      userCredential = await _auth.signInWithCredential(credential);
    }

    await _saveUserIfNeeded(userCredential.user);

    return userCredential;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    }

    await _auth.signOut();
  }

  Future<void> _saveUserIfNeeded(User? user) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      await userRef.set({
        'name': user.displayName ?? snapshot.data()?['name'] ?? '',
        'email': user.email ?? snapshot.data()?['email'] ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'provider': 'google.com',
      }, SetOptions(merge: true));

      return;
    }

    await userRef.set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'provider': 'google.com',
    });
  }
}