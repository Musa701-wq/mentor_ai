import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/usermodel.dart';
import '../services/authService.dart';
import '../services/Firestore_service.dart';
import 'profileProvider.dart';

class authProvider1 with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? firebaseUser;
  UserModel? userModel;

  final ProfileProvider _profileProvider;

  authProvider1(this._profileProvider) {
    // Listen to Firebase Auth changes
    _authService.userChanges.listen((user) async {
      firebaseUser = user;

      if (user != null) {
        // Fetch user profile from Firestore
        userModel = await _firestoreService.getUserProfile(user.uid);

        // If no profile exists (new account), create and persist a default profile
        if (userModel == null) {
          final created = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? '',
            grade: '',
            goal: '',
            subjects: const [],
            profilePic: user.photoURL ?? '',
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
            onboardingCompleted: false,
            keywords: const [],
            credits: 15,
          );
          await _firestoreService.saveUserProfile(created);
          userModel = created;
        }

        // Update ProfileProvider safely
        _profileProvider.setUser(userModel!);
      } else {
        userModel = null;

        // Reset ProfileProvider
        _profileProvider.setUser(UserModel(
          uid: '',
          email: '',
          name: '',
          grade: '',
          goal: '',
          subjects: [],
          profilePic: '',
        ));
      }

      notifyListeners();
    });

    // Listen to ProfileProvider updates and propagate
    _profileProvider.addListener(() {
      if (_profileProvider.user != null) {
        userModel = _profileProvider.user;
        notifyListeners();
      }
    });
  }

  Stream<User?> get userChanges => _authService.userChanges;

  Future<void> signInWithGoogle() async {
    await _authService.signInWithGoogle();
    // ProfileProvider will be updated automatically by the listener
  }

  Future<void> signInWithApple() async {
    await _authService.signInWithApple();
    // ProfileProvider will be updated automatically by the listener
  }

  Future<void> signOut() async {
    await _authService.signOut();
    firebaseUser = null;
    userModel = null;

    // Clear ProfileProvider as well
    _profileProvider.setUser(UserModel(
      uid: '',
      email: '',
      name: '',
      grade: '',
      goal: '',
      subjects: [],
      profilePic: '',
    ));

    notifyListeners();
  }


}
