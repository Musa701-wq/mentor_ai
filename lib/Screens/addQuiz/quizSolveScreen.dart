import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Providers/quizProvider.dart';

class QuizSolveScreen extends StatefulWidget {
  final String quizId;
  const QuizSolveScreen({super.key, required this.quizId});

  @override
  State<QuizSolveScreen> createState() => _QuizSolveScreenState();
}

class _QuizSolveScreenState extends State<QuizSolveScreen> {
  bool _loadingQuestions = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final provider = Provider.of<QuizProvider>(context, listen: false);

    final snapshot = await FirebaseFirestore.instance
        .collection("quizzes")
        .doc(widget.quizId)
        .collection("questions")
        .get();

    final questions = snapshot.docs.map((doc) {
      return QuizQuestion(
        question: doc["question"],
        options: List<String>.from(doc["options"]),
        correctAnswer: doc["correctAnswer"],
      );
    }).toList();

    provider
      ..resetQuiz()
      ..questions.clear()
      ..questions.addAll(questions);

    setState(() {
      _loadingQuestions = false;
    });
  }

  void _submitQuiz(BuildContext context) async {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    
    // Check for unanswered questions
    List<int> unansweredQuestions = [];
    for (int i = 0; i < provider.questions.length; i++) {
      if (!provider.selectedAnswers.containsKey(i) || 
          provider.selectedAnswers[i] == null || 
          provider.selectedAnswers[i]!.isEmpty) {
        unansweredQuestions.add(i + 1); // Adding 1 for human-readable numbering
      }
    }
    
    // Show warning if there are unanswered questions
    if (unansweredQuestions.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text("Incomplete Quiz"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("You have ${unansweredQuestions.length} unanswered question(s):"),
              SizedBox(height: 8),
              Text(
                "Question(s): ${unansweredQuestions.join(', ')}",
                style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red),
              ),
              SizedBox(height: 12),
              Text("Do you want to submit anyway?"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Review", style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _proceedWithSubmission(context);
              },
              child: Text("Submit Anyway", style: TextStyle(color: Colors.deepPurple)),
            ),
          ],
        ),
      );
      return;
    }
    
    // If all questions are answered, proceed with submission
    _proceedWithSubmission(context);
  }
  
  void _proceedWithSubmission(BuildContext context) async {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "guest";

    final score = await provider.submitQuiz(userId, widget.quizId);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Quiz Completed 🎉"),
        content: Text("Your Score: $score / ${provider.questions.length}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizProvider>(
      builder: (context, provider, _) {
        if (_loadingQuestions) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Solve Quiz"),
            backgroundColor: Colors.deepPurple,
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.questions.length,
                    itemBuilder: (context, index) {
                      final q = provider.questions[index];
                      final selected = provider.selectedAnswers[index];
                      return QuestionTile(
                        question: q.question,
                        options: q.options,
                        selectedAnswer: selected,
                        correctAnswer:
                        provider.isSubmitted ? q.correctAnswer : null,
                        onSelect: (val) {
                          provider.selectAnswer(index, val);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (!provider.isSubmitted)
                  ElevatedButton(
                    onPressed: () => _submitQuiz(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Submit Quiz"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class QuestionTile extends StatelessWidget {
  final String question;
  final List<String> options;
  final String? selectedAnswer;
  final String? correctAnswer;
  final Function(String) onSelect;

  const QuestionTile({
    super.key,
    required this.question,
    required this.options,
    required this.onSelect,
    this.selectedAnswer,
    this.correctAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question,
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Column(
              children: options.map((option) {
                final isCorrect = correctAnswer == option;
                final isSelected = selectedAnswer == option;

                Color? tileColor;
                IconData? leadingIcon;

                if (correctAnswer != null) {
                  if (isCorrect) {
                    tileColor = Colors.green.withOpacity(0.1);
                    leadingIcon = Icons.check_circle;
                  } else if (isSelected && !isCorrect) {
                    tileColor = Colors.red.withOpacity(0.1);
                    leadingIcon = Icons.cancel;
                  }
                }

                return RadioListTile<String>(
                  value: option,
                  groupValue: selectedAnswer,
                  onChanged: correctAnswer != null ? null : (val) => onSelect(val!),
                  title: Text(option),
                  tileColor: tileColor,
                  secondary: leadingIcon != null
                      ? Icon(leadingIcon,
                      color: isCorrect ? Colors.green : Colors.red)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
