/*
// lib/screens/add_quiz_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_ai/services/adService.dart';

import 'generateQuizScreen.dart';
import 'manualQuizScreen.dart';

class AddQuizScreen extends StatelessWidget {
  const AddQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Add Quiz"),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _OptionCard(
                title: "Create Manually",
                subtitle: "Write your own quiz with correct options",
                icon: Icons.edit,
                colors: [Colors.blue, Colors.lightBlueAccent],
                onTap: () {
                 AdService.showInterstitialAndNavigate(context, ManualQuizScreen());
                },
              ),
              const SizedBox(height: 20),
              _OptionCard(
                title: "Generate from Notes",
                subtitle: "AI will create a quiz from your notes",
                icon: Icons.auto_awesome,
                colors: [Colors.deepPurple, Colors.purpleAccent],
                onTap: () {
                  AdService.showInterstitialAndNavigate(context, GenerateQuizScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _OptionCard(
      {required this.title,
        required this.subtitle,
        required this.icon,
        required this.colors,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14,
                          decoration: TextDecoration.none
                      )),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
*/
// lib/screens/add_quiz_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:student_ai/services/adService.dart';

import '../../google_analytics.dart';
import 'generateQuizScreen.dart';
import 'manualQuizScreen.dart';

class AddQuizScreen extends StatelessWidget {
  const AddQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Add Quiz"),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _OptionCard(
                title: "Create Manually",
                subtitle: "Write your own quiz with correct options",
                icon: Icons.edit,
                colors: [Colors.blue, Colors.lightBlueAccent],
                onTap: () {
                  AnalyticsService.logManualQuizClick();
                  AdService.showInterstitialAndNavigate(context, ManualQuizScreen());
                },
              ),
              const SizedBox(height: 20),
              _OptionCard(
                title: "Generate from Notes",
                subtitle: "AI will create a quiz from your notes",
                icon: Icons.auto_awesome,
                colors: [Colors.deepPurple, Colors.purpleAccent],
                onTap: () {
                  AnalyticsService.logGenerateQuizClick();
                  AdService.showInterstitialAndNavigate(context, GenerateQuizScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}