import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/usermodel.dart';
import '../screens/signin.dart';
import '../services/firestore_service.dart';
import '../splashScreen.dart';
import 'home.dart';
import 'onboarding/onboarding_wrapper.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Stream<User?> _authStream;
  final Map<String, Future<UserModel?>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  Future<UserModel?> _loadUserData(String uid) {
    return _userCache.putIfAbsent(uid, () async {
      final firestoreService = FirestoreService();
      return await firestoreService.getUserProfile(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snap) {
        // 🔹 Splash only on very first load
        if (snap.connectionState == ConnectionState.waiting &&
            !_userCache.containsKey("init")) {
          return MentorAISplashScreen();
        }

        final user = snap.data;

        if (user == null) {
          // Not logged in → Sign In screen
          return const SignInPage();
        }

        // Logged in → load profile & onboarding
        return FutureBuilder<UserModel?>(
          future: _loadUserData(user.uid),
          builder: (context, fs) {
            if (fs.connectionState == ConnectionState.waiting &&
                !_userCache.containsKey(user.uid)) {
              return const Scaffold(); // lightweight loading
            }
            if (fs.hasError || !fs.hasData) {
              return const Scaffold(); // fallback
            }

            final userModel = fs.data;

            if (userModel == null || !userModel.onboardingCompleted) {
              return const OnboardingWrapper();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
