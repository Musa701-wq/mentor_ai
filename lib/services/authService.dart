// lib/services/auth_service.dart
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get userChanges => _auth.userChanges();

  Future<User?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<User?> signInWithApple() async {
    // Sign in with Apple is only available on Apple platforms
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError('Sign in with Apple is supported only on iOS/macOS');
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);
    return userCredential.user;
  }



  Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await _auth.signOut();
      debugPrint("✅ Firebase signOut successful");

      // If the user logged in with Google, sign out from GoogleSignIn as well
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
        debugPrint("✅ Google signOut successful");
      } else {
        debugPrint("ℹ️ No active Google session found");
      }

      // Apple sign-out not required (only Firebase session matters)
      debugPrint("🍏 Apple signOut handled by Firebase (no local session)");
    } catch (e) {
      debugPrint("❌ Error signing out: $e");
      rethrow;
    }
  }
}
