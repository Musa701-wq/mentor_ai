import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_ai/Providers/homeStatsProvider.dart';

import '../models/usermodel.dart';
import '../screens/signin.dart';
import '../services/firestore_service.dart';
import '../splashScreen.dart';
import '../splashWrapper.dart';
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

  Future<UserModel?> _loadUserData(String uid) async {
    final provider = Provider.of<HomeStatsProvider>(context, listen: false);
    await provider.loadDashboard();
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
          return SplashWrapper();
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
              return const Scaffold(
                body: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E35B1)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Loading",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (fs.hasError) {
              // If there's an error loading profile, allow onboarding path
              return const OnboardingWrapper();
            }

            final userModel = fs.data;

            if (userModel == null || !userModel.onboardingCompleted) {
              return const OnboardingWrapper();
            }

            final provider = Provider.of<HomeStatsProvider>(context, listen: false);

            // Second FutureBuilder to await dashboard load
            return FutureBuilder<void>(
              future: provider.loadDashboard(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E35B1)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Preparing dashboard",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  // Handle dashboard loading errors gracefully
                  return const OnboardingWrapper();
                }

                return const HomeScreen();
              },
            );
          },
        );

      },
    );
  }
}
