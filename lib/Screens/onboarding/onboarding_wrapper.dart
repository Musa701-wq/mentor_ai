import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'onboarding_welcome.dart';
import 'onboarding_profile.dart';
import 'onboarding_goals.dart';
import 'onboarding_auth.dart';

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});
  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  final PageController _controller = PageController();
  String? _name;
  String? _grade;
  String? _goal;
  List<String> _subjects = [];

  void _nextPage() {
    _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              OnboardingWelcome(onNext: _nextPage),
              OnboardingProfile(onNext: (name, grade, subjects) {
                setState(() {
                  _name = name;
                  _grade = grade;
                  _subjects = subjects;
                });
                _nextPage();
              }),
              OnboardingGoals(onNext: (goal) {
                setState(() => _goal = goal);
                _nextPage();
              }),
              OnboardingAuth(
                name: _name ?? '',
                grade: _grade ?? '',
                goal: _goal ?? '',
                subjects: _subjects,
              ),
            ],
          ),

          // Custom Page Indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: 4,
                  effect: ExpandingDotsEffect(
                    activeDotColor: const Color(0xFF7E57C2),
                    dotColor: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                    spacing: 6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}