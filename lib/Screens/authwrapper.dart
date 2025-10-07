import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_ai/Providers/homeStatsProvider.dart';

import '../models/usermodel.dart';
import '../screens/signin.dart';
import '../services/firestore_service.dart';
import '../splashScreen.dart';
import 'home.dart';
import 'onboarding/onboarding_wrapper.dart';

class AuthWrapper extends StatefulWidget {
  final bool isHome;
  const AuthWrapper({super.key, this.isHome = false});

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
    final provider = Provider.of<HomeStatsProvider>(context, listen: false);
    provider.loadDashboard();
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
          return widget.isHome ? const SignInPage():HomeScreen();
        }

        // Logged in → load profile & onboarding
        return FutureBuilder<UserModel?>(
          future: _loadUserData(user.uid),
          builder: (context, fs) {
            if (fs.connectionState == ConnectionState.waiting &&
                !_userCache.containsKey(user.uid)) {
              return const Scaffold(); // lightweight loading
            }
            if (fs.hasError) {
              // If there's an error loading profile, allow onboarding path
              return const OnboardingWrapper();
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
