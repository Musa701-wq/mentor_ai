// lib/services/gemini_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // Hosted Backend Configuration
  String get _baseUrl {
    // 🚀 Automatically detect environment to avoid SocketException
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000'; // Special IP for Android Emulator
    return 'http://localhost:3000'; // iOS Simulator or Desktop
  }

  /// Centralized method to call the hosted Gemini API
  Future<String> _ask(String prompt) async {
    final url = Uri.parse('$_baseUrl/api/gemini');
    
    debugPrint('📤 Calling Hosted AI: $url');
    // debugPrint('📦 Prompt: $prompt'); // Uncomment for deep debugging

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _cleanResponse(data['result'] ?? "No result from AI.");
      } else {
        debugPrint('❌ Hosted API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Error calling hosted model: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Network / API Exception: $e');
      rethrow;
    }
  }

  /// Removes unwanted formatting like asterisks and extra spaces
  String _cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r'\*+'), '') // Remove any number of asterisks
        .replaceAll(RegExp(r'\s{2,}'), ' ') // Normalize spaces
        .trim();
  }

  /// Summarize text
  Future<String> summarize(String text) async {
    final prompt = """
Summarize the following text professionally and concisely. 
Focus on key takeaways and main arguments. 
Ensure the output is easy to read and structured logically.

Text to summarize:
$text

Guidelines:
1. Do NOT use asterisks (*) for bullet points or emphasis.
2. Use clear, concise language.
3. If using bullets, use a dash (-) or a bullet point (•).
4. Keep the structure clean and readable.
""";
    return await _ask(prompt);
  }

  /// Chat with Gemini (Study Assistant mode)
  Future<String> chat(String query) async {
    final prompt = """
You are a helpful Study Buddy AI. 
- Use the following STRICT format for your response:

Question: [Specific part of the user's query/image being addressed]
Answer: [Correct Option/Final Answer]
Explanation: [Clear and detailed reasoning]

- IMPORTANT: Do NOT use '*' (asterisks) for bullet points or lists.
- You can use '**' (bold) for headers like **Question:**, **Answer:**, and **Explanation:**.
- If multiple questions are present, repeat this block for each.
- Maintain a highly professional and clean layout.
- If the question is unrelated to studies, politely decline.

User: $query
""";
    return await _ask(prompt);
  }

  /// Chat with context (Study Assistant mode)
  Future<String> chatWithContext(String query, List<Map<String, String>> context) async {
    final conversation = context.map((m) {
      final role = (m["role"] == "user") ? "user" : "model";
      return "$role: ${m["text"]}";
    }).join("\n");

    final prompt = """
You are a helpful Study Buddy AI.
Use a clean and professional layout using ONLY the headers below:

**Question:** [Text]
**Answer:** [Text]
**Explanation:** [Text]

- Strictly avoid all '*' (asterisks) for bullets.
- Separate each section clearly.

$conversation
user: $query
""";
    return await _ask(prompt);
  }

  /// Generate MCQs from notes
  Future<List<Map<String, dynamic>>> generateQuizFromNotes(String notes) async {
    final prompt = """
Generate exactly 5 multiple-choice quiz questions (MCQs) from the following notes:
$notes

Return the output STRICTLY as a JSON array, no explanations, no markdown.
Each object must look like this:
{
  "question": "string",
  "options": [
    {"text": "option A", "correct": false},
    {"text": "option B", "correct": true},
    {"text": "option C", "correct": false},
    {"text": "option D", "correct": false}
  ]
}
""";
    
    String result = await _ask(prompt);
    
    // Clean JSON formatting if model returns markdown
    result = result.replaceAll("```json", "").replaceAll("```", "").trim();

    try {
      return List<Map<String, dynamic>>.from(json.decode(result));
    } catch (e) {
      debugPrint("❌ JSON parse error in Quiz generation: $e\nRaw text: $result");
      return [];
    }
  }

  /// Validate correct option text
  Future<String> validateCorrectOption(String question, List<String> options) async {
    final prompt = "Here is a question: \"$question\" with options: ${options.join(", ")}. Return only the correct option text.";
    return await _ask(prompt);
  }

  /// Generate complex Study Plan
  Future<String> generateStudyPlan({
    required String goal,
    required String examDate,
    required String startDate,
    required List<String> selectedNotes,
    required int studyDaysPerWeek,
    required int hoursPerDay,
  }) async {
    final notesText = selectedNotes.join("\n");
    final prompt = """
You are a Study Planner AI. Create a detailed study plan based on the following inputs:

- Goal: $goal
- Exam Date: $examDate (YYYY-MM-DD)
- Start Date: $startDate (YYYY-MM-DD)
- Study Days Per Week: $studyDaysPerWeek
- Study Hours Per Day: $hoursPerDay
- Selected Notes: $notesText

Return the study plan **strictly in valid JSON only**, with no explanations, comments, or extra text. The JSON must have this exact structure:

{
  "goal": "<goal>",
  "examDate": "<examDate>",
  "startDate": "<startDate>",
  "studyDaysPerWeek": <int>,
  "studyHoursPerDay": <int>,
  "topics": [
    {
      "name": "<topic name>",
      "description": "<short description of topic>",
      "estimatedTime": <hours as number>,
      "assignedDays": ["YYYY-MM-DD", "YYYY-MM-DD", ...]
    }
  ],
  "studySchedule": [
    {
      "day": "YYYY-MM-DD",
      "topics": ["topic1", "topic2", ...],
      "hours": <total hours for the day>
    }
  ],
  "reminders": ["<reminder1>", "<reminder2>", ...]
}
""";

    return await _ask(prompt);
  }
}

