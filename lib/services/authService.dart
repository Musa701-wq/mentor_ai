// lib/services/auth_service.dart
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get userChanges => _auth.userChanges();
// lib/services/auth_service.dart
  Future<User?> signInWithGoogle() async {
    try {
      // Initialize GoogleSignIn with proper configuration
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        // Add clientId for web support if needed
        // clientId: Platform.isWeb ? 'YOUR_WEB_CLIENT_ID' : null,
      );

      // Sign out first to clear any previous sessions
      await googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("❌ Google sign-in cancelled by user");
        return null;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      debugPrint("✅ Google Sign-In successful: ${userCredential.user?.email}");
      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Google Sign-In error: $e");
      rethrow;
    }
  }
  /// GOOGLE LOGIN
/*
  Future<User?> signInWithGoogle() async {
    try {
      // Sign out first to ensure fresh login
      await _googleSignIn.signOut();

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      debugPrint("✅ Google sign in successful: ${userCredential.user?.email}");
      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Google sign in error: $e");
      return null;
    }
  }
*/

  /// APPLE LOGIN
  Future<User?> signInWithApple() async {
    // Sign in with Apple is only available on Apple platforms
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError('Sign in with Apple is supported only on iOS/macOS');
    }

    try {
      // Check if Apple Sign-In is available
      if (!await SignInWithApple.isAvailable()) {
        throw Exception("Apple Sign-In is not available on this device");
      }

      // Request credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth credential for Apple
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      debugPrint("✅ Apple sign in successful: ${userCredential.user?.email}");
      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Apple sign in error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await _auth.signOut();
      debugPrint("✅ Firebase signOut successful");

      // Sign out from Google
      try {
        await _googleSignIn.signOut();
        debugPrint("✅ Google signOut successful");
      } catch (e) {
        debugPrint("ℹ️ Google signOut: $e");
      }

      // Apple sign-out not required (only Firebase session matters)
      debugPrint("🍏 Apple signOut handled by Firebase (no local session)");
    } catch (e) {
      debugPrint("❌ Error signing out: $e");
      rethrow;
    }
  }
}
