import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/usermodel.dart';

class ProfileProvider with ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  final _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Set user manually
  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  // ✅ Update user locally AND in Firestore
  Future<void> updateUser({
    String? name,
    String? grade,
    String? goal,
    List<String>? subjects,
    String? profilePic,
  }) async {
    if (_user == null) return;

    // Update local model
    _user = UserModel(
      uid: _user!.uid,
      email: _user!.email,
      name: name ?? _user!.name,
      grade: grade ?? _user!.grade,
      goal: goal ?? _user!.goal,
      subjects: subjects ?? _user!.subjects,
      profilePic: profilePic ?? _user!.profilePic,
      createdAt: _user!.createdAt,
      lastLogin: _user!.lastLogin,
      onboardingCompleted: _user!.onboardingCompleted,
    );

    notifyListeners(); // UI updates

    // Update Firestore
    try {
      await _firestore
          .collection('users')
          .doc(_user!.uid)
          .update(_user!.toMap());
    } catch (e) {
      debugPrint("Error updating user in Firestore: $e");
      rethrow;
    }
  }

  // ✅ Fetch user from Firestore using uid
  Future<void> fetchUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromMap(doc.data()!);
        notifyListeners();
      } else {
        debugPrint("User not found in Firestore");
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
  }

  // Re-authenticate user before sensitive operations
  Future<void> _reauthenticateUser() async {
    debugPrint("🔐 [REAUTH] Starting re-authentication process");

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("❌ [REAUTH] No current user found");
      throw Exception("No user logged in");
    }

    debugPrint(
      "👤 [REAUTH] Current user: ${currentUser.uid}, Email: ${currentUser.email}",
    );

    // Check which provider the user used to sign in
    final providerData = currentUser.providerData;
    debugPrint(
      "🔍 [REAUTH] User providers: ${providerData.map((p) => p.providerId).toList()}",
    );

    AuthCredential? credential;
// ✅ Update these lines:

// Handle Google Sign-In re-authentication
    if (providerData.any((provider) => provider.providerId == 'google.com')) {
      debugPrint("🔄 [REAUTH] Re-authenticating with Google");
      try {
        // Create GoogleSignIn instance with scopes
        final googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/userinfo.profile',
          ],
        );

        // ✅ FIXED: authenticate() is now signIn() in newer versions
        // Authenticate with Google - use signIn() instead of authenticate()
        final googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          debugPrint("❌ [REAUTH] Google sign-in was cancelled");
          throw Exception("Google sign-in cancelled");
        }

        // ✅ FIXED: No need to check same account - Google SignIn automatically
        // prevents switching accounts when already signed in
        // But still keep validation for safety
        final currentEmail = currentUser.email?.toLowerCase();
        final selectedEmail = googleUser.email.toLowerCase();
        if (currentEmail != null && currentEmail != selectedEmail) {
          debugPrint(
            "❌ [REAUTH] Selected Google account does not match current user. Current: $currentEmail, Selected: $selectedEmail",
          );
          await googleSignIn.disconnect();
          throw Exception(
            "Please sign in with the same Google account ($currentEmail) to continue.",
          );
        }

        // ✅ FIXED: Get authentication from googleUser
        final googleAuth = await googleUser.authentication;

        credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        debugPrint("✅ [REAUTH] Google credentials obtained");
      } catch (e) {
        debugPrint("❌ [REAUTH] Google re-authentication failed: $e");
        rethrow;
      }
    }
    // Re-authenticate with Firebase
    if (credential != null) {
      debugPrint("🔐 [REAUTH] Performing Firebase re-authentication");
      await currentUser.reauthenticateWithCredential(credential);
      debugPrint("✅ [REAUTH] Re-authentication successful");
    } else {
      debugPrint("❌ [REAUTH] No credential available for re-authentication");
      throw Exception("Failed to obtain re-authentication credentials");
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    debugPrint("🔥 [DELETE_ACCOUNT] Starting account deletion process");

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint("❌ [DELETE_ACCOUNT] User is null");
        throw Exception("User is not authenticated");
      }

      debugPrint(
        "👤 [DELETE_ACCOUNT] Current user: ${currentUser.uid}, Email: ${currentUser.email}",
      );

      // Re-authenticate user before deletion
      debugPrint("🔐 [DELETE_ACCOUNT] Attempting re-authentication");
      await _reauthenticateUser();
      debugPrint("✅ [DELETE_ACCOUNT] Re-authentication successful");

      // Delete user data from Firestore
      debugPrint("🗑️ [DELETE_ACCOUNT] Deleting Firestore document");
      await _firestore.collection('users').doc(currentUser.uid).delete();
      debugPrint("✅ [DELETE_ACCOUNT] Firestore document deleted");

      // Delete Firebase Auth account
      debugPrint("🔥 [DELETE_ACCOUNT] Deleting Firebase Auth account");
      await currentUser.delete();
      debugPrint("✅ [DELETE_ACCOUNT] Firebase Auth account deleted");

      // Clear local user data
      debugPrint("🧹 [DELETE_ACCOUNT] Clearing local user data");
      _user = null;
      notifyListeners();
      debugPrint("✅ [DELETE_ACCOUNT] Local user data cleared");

      // ✅ Do not navigate here; let the caller close dialogs and navigate cleanly
      debugPrint(
        "✅ [DELETE_ACCOUNT] Account deletion completed successfully (no navigation from provider)",
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ [DELETE_ACCOUNT] FirebaseAuthException occurred");
      debugPrint("📊 [DELETE_ACCOUNT] Error type: FirebaseAuthException");
      debugPrint("📝 [DELETE_ACCOUNT] Error details: ${e.toString()}");
      debugPrint("🔐 [DELETE_ACCOUNT] Firebase Auth Error Code: ${e.code}");
      debugPrint(
        "🔐 [DELETE_ACCOUNT] Firebase Auth Error Message: ${e.message}",
      );
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint("❌ [DELETE_ACCOUNT] FirebaseException occurred");
      debugPrint("📊 [DELETE_ACCOUNT] Error type: FirebaseException");
      debugPrint("📝 [DELETE_ACCOUNT] Error details: ${e.toString()}");
      debugPrint("🔥 [DELETE_ACCOUNT] Firebase Error Code: ${e.code}");
      debugPrint("🔥 [DELETE_ACCOUNT] Firebase Error Message: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("❌ [DELETE_ACCOUNT] General exception occurred");
      debugPrint("📊 [DELETE_ACCOUNT] Error type: ${e.runtimeType}");
      debugPrint("📝 [DELETE_ACCOUNT] Error details: ${e.toString()}");
      rethrow;
    }
  }
}