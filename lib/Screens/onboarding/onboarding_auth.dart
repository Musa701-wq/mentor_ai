// lib/screens/onboarding/onboarding_auth.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/authProvider.dart';
import '../../Providers/homeStatsProvider.dart';
import '../../models/usermodel.dart';
import '../../services/Firestore_service.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/SignInButton.dart';
import '../home.dart';

class OnboardingAuth extends StatelessWidget {
  final String name;
  final String grade;
  final String goal;
  final List<String> subjects;

  const OnboardingAuth({
    super.key,
    required this.name,
    required this.grade,
    required this.goal,
    required this.subjects,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<authProvider1>(context, listen: false);
    final firestoreService = FirestoreService();

    final user = FirebaseAuth.instance.currentUser;

    // If user is already signed in, check Firestore profile
    if (user != null) {
      return FutureBuilder<UserModel?>(
        future: firestoreService.getUserProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final existingUser = snapshot.data;

          if (existingUser != null) {
            if (existingUser.onboardingCompleted) {
              // Existing profile completed → go home
              Future.microtask(() async {
                final provider = Provider.of<HomeStatsProvider>(context, listen: false);
                await provider.loadDashboard();
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()));
              });
              return const Scaffold();
            } else {
              // Existing profile incomplete → update with onboarding data
              Future.microtask(() async {
                final updatedUser = UserModel(
                  uid: user.uid,
                  email: user.email ?? existingUser.email,
                  name: name.isNotEmpty ? name : existingUser.name,
                  grade: grade.isNotEmpty ? grade : existingUser.grade,
                  goal: goal.isNotEmpty ? goal : existingUser.goal,
                  subjects: subjects.isNotEmpty ? subjects : existingUser.subjects,
                  profilePic: user.photoURL ?? existingUser.profilePic,
                  createdAt: existingUser.createdAt ?? DateTime.now(),
                  lastLogin: DateTime.now(),
                  onboardingCompleted: true,
                  keywords: generateKeywords(name.isNotEmpty ? name : existingUser.name, user.email ?? existingUser.email),
                  credits: existingUser.credits,
                );
                await firestoreService.saveUserProfile(updatedUser);
                final provider = Provider.of<HomeStatsProvider>(context, listen: false);
                await provider.loadDashboard();
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()));
              });
              return const Scaffold();
            }
          }

          // Firebase user exists but Firestore profile missing → create profile
          Future.microtask(() async {
            final effectiveName = name.isNotEmpty ? name : (user.displayName ?? '');
            final newUser = UserModel(
              uid: user.uid,
              email: user.email ?? '',
              name: effectiveName,
              grade: grade,
              goal: goal,
              subjects: subjects,
              profilePic: user.photoURL ?? '',
              createdAt: DateTime.now(),
              lastLogin: DateTime.now(),
              onboardingCompleted: true,
              keywords: generateKeywords(effectiveName, user.email ?? ''),
            );
            await firestoreService.saveUserProfile(newUser);
            final provider = Provider.of<HomeStatsProvider>(context, listen: false);
            await provider.loadDashboard();
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()));
          });

          return const Scaffold(); // placeholder while creating/updating profile
        },
      );
    }

    // User not signed in → show sign-in buttons
    Future<void> _handleLogin(Future<void> Function() loginFn) async {
      try {
        await loginFn();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 100, color: Colors.white),
              const SizedBox(height: 30),
              const Text(
                '🔐 Sign in to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 50),
              SignInButton(
                text: 'Sign in with Google',
                color: Colors.white,
                textColor: Colors.red,
                icon: FontAwesomeIcons.google,
                onPressed: () => _handleLogin(authProvider.signInWithGoogle),
              ),
              const SizedBox(height: 20),
              SignInButton(
                text: 'Sign in with Apple',
                color: Colors.black,
                textColor: Colors.white,
                icon: FontAwesomeIcons.apple,
                onPressed: () => _handleLogin(authProvider.signInWithApple),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
List<String> generateKeywords(String name, String email) {
  final List<String> keywords = [];
  final nameParts = name.toLowerCase().split(" ");
  final emailLower = email.toLowerCase();

  // add full name + each part
  keywords.add(name.toLowerCase());
  keywords.addAll(nameParts);

  // add progressive prefixes for autocomplete (e.g. "j", "jo", "joh", "john")
  for (int i = 1; i <= name.length; i++) {
    keywords.add(name.substring(0, i).toLowerCase());
  }
  for (int i = 1; i <= emailLower.length; i++) {
    keywords.add(emailLower.substring(0, i));
  }

  return keywords.toSet().toList(); // unique
}
