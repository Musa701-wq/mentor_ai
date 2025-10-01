// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String GEMINI_API_KEY = 'AIzaSyBZE2d4x_-WSFmuR7mkTZuJS3rM--0Dbz8';
  static const String ENDPOINT =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Utility: log request + response
  void _logRequest(String method, Uri url, Map<String, dynamic> body) {
    print('📤 [$method] Request to: $url');
    print('📦 Request body: ${json.encode(body)}');
  }

  void _logResponse(http.Response response) {
    print('📥 Response [${response.statusCode}]: ${response.body}');
  }

  /// Summarize text
  Future<String> summarize(String text) async {
    final url = Uri.parse('$ENDPOINT?key=$GEMINI_API_KEY');
    final body = {
      "contents": [
        {
          "parts": [
            {"text": "Summarize the following text:\n\n$text"}
          ]
        }
      ]
    };

    _logRequest("POST", url, body);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _logResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          "No summary returned.";
    } else {
      throw Exception(
          '❌ Gemini API error: ${response.statusCode} ${response.body}');
    }
  }

  /// Chat with Gemini (Study Assistant mode)
  Future<String> chat(String query) async {
    final url = Uri.parse('$ENDPOINT?key=$GEMINI_API_KEY');

    final body = {
      "contents": [
        {
          "parts": [
            {
              "text":
              "You are a helpful Study Buddy AI. - Answer only study-related questions. - If unrelated, politely decline. - Keep answers concise (max 3–4 lines). - For problem-solving, do not give full solutions — only provide minor hints or guidance. User: $query"
            }
          ]
        }
      ]
    };

    _logRequest("POST", url, body);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _logResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          "Sorry, I don’t have an answer for that.";
    } else {
      throw Exception(
          '❌ Gemini API error: ${response.statusCode} ${response.body}');
    }
  }

  Future<String> chatWithContext(
      String query, List<Map<String, String>> context) async {
    final url = Uri.parse('$ENDPOINT?key=$GEMINI_API_KEY');

    // Ensure roles are always valid
    final contents = context.map((m) {
      final role = (m["role"] == "user" || m["role"] == "model")
          ? m["role"]
          : "user"; // fallback
      return {
        "role": role,
        "parts": [
          {"text": m["text"] ?? ""}
        ]
      };
    }).toList();

    // Add the current user query as the latest message
    contents.add({
      "role": "user",
      "parts": [
        {"text": query}
      ]
    });

    final body = {"contents": contents};

    _logRequest("POST", url, body);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _logResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          "No response.";
    } else {
      throw Exception(
          "❌ Gemini API error: ${response.statusCode} ${response.body}");
    }
  }


  Future<List<Map<String, dynamic>>> generateQuizFromNotes(
      String notes) async {
    final url = Uri.parse('$ENDPOINT?key=$GEMINI_API_KEY');

    final body = {
      "contents": [
        {
          "parts": [
            {
              "text": """
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
"""
            }
          ]
        }
      ]
    };

    _logRequest("POST", url, body);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _logResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      String text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? "[]";

      // 🔧 Clean common issues
      text = text.replaceAll("```json", "").replaceAll("```", "").trim();

      try {
        return List<Map<String, dynamic>>.from(json.decode(text));
      } catch (e) {
        print("❌ JSON parse error: $e\nRaw text: $text");
        return [];
      }
    } else {
      throw Exception(
          "❌ Gemini API error: ${response.statusCode} ${response.body}");
    }
  }

  Future<String> validateCorrectOption(
      String question, List<String> options) async {
    final url = Uri.parse('$ENDPOINT?key=$GEMINI_API_KEY');

    final body = {
      "contents": [
        {
          "parts": [
            {
              "text":
              "Here is a question: \"$question\" with options: ${options.join(", ")}. "
                  "Return only the correct option text."
            }
          ]
        }
      ]
    };

    _logRequest("POST", url, body);

    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body));

    _logResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          "No correct answer found.";
    } else {
      throw Exception(
          "❌ Gemini API error: ${response.statusCode} ${response.body}");
    }
  }

  Future<String> generateStudyPlan({
    required String goal,
    required String examDate,
    required String startDate,
    required List<String> selectedNotes,
    required int studyDaysPerWeek,
    required int hoursPerDay,
  }) async {
    final url = Uri.parse('$ENDPOINT?key=$GEMINI_API_KEY');

    final notesText = selectedNotes.join("\n");

    final body = {
      "contents": [
        {
          "parts": [
            {
              "text": """
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
"""
            }
          ]
        }
      ]
    };

    _logRequest("POST", url, body);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _logResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          "No study plan returned.";
    } else {
      throw Exception(
          '❌ Gemini API error: ${response.statusCode} ${response.body}');
    }
  }
}
