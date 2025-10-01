// lib/screens/homework/homework_detail_screen.dart
import 'package:flutter/material.dart';

class HomeworkDetailScreen extends StatelessWidget {
  final Map<String, dynamic> homework;
  const HomeworkDetailScreen({super.key, required this.homework});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = homework["content"] ?? "";
    final title = homework["title"] ?? "Solution Details";

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.grey[800],
        elevation: 0,
        actions: [

        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }
}