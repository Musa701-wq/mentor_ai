import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class QuizSuccessScreen extends StatefulWidget {
  final int score;
  final int total;

  const QuizSuccessScreen({super.key, required this.score, required this.total});

  @override
  State<QuizSuccessScreen> createState() => _QuizSuccessScreenState();
}

class _QuizSuccessScreenState extends State<QuizSuccessScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();

    // Auto-close after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double accuracy = (widget.total == 0)
        ? 0
        : (widget.score / widget.total).clamp(0, 1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient background with decorative circles
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF5F5FF),
                  Color(0xFFE6E6FF),
                ],
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6584).withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 500),
                        scale: 1.0,
                        child: const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF6C63FF),
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Well Done!",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2B4E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Quiz Completed",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Animated score ring
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: accuracy),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final percent = (value * 100).round();
                          return Center(
                            child: SizedBox(
                              width: 170,
                              height: 170,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 10,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "$percent%",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D2B4E),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Marks: ${widget.score}/${widget.total}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _pill(label: "Accuracy", value: "${(accuracy * 100).round()}%"),
                          _pill(label: "Correct", value: "${widget.score}"),
                          _pill(label: "Total", value: "${widget.total}"),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6C63FF), width: 1.2),
                        ),
                        child: const Text(
                          "Great job! Redirecting...",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF6C63FF),
                Color(0xFFFF6584),
                Color(0xFFFFCE5C),
                Color(0xFF4CAF50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _pill({required String label, required String value}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.12),
          blurRadius: 12,
          offset: const Offset(0, 6),
        )
      ],
      border: Border.all(color: Colors.grey.shade200, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF2D2B4E),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}