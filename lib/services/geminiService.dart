// lib/services/gemini_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/creditService.dart';

class GeminiService {
  // Hosted Backend Configuration
  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  /// Estimated token count from the last API call (prompt + response) / 4
  int _lastEstimatedTokens = 0;
  int get lastEstimatedTokens => _lastEstimatedTokens;

  /// Centralized method to call the hosted Gemini API
  Future<String> _ask(String prompt) async {
    final url = Uri.parse('$_baseUrl/api/gemini');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = _cleanResponse(data['result'] ?? "No result from AI.");

        // Token estimation: 1 token ≈ 4 characters
        final inputTokens  = prompt.length ~/ 4;
        final outputTokens = result.length ~/ 4;
        _lastEstimatedTokens = inputTokens + outputTokens;

        // Credit cost based on total tokens
        final creditCost = _calcCredits(_lastEstimatedTokens);

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 INPUT  tokens  : $inputTokens  (${prompt.length} chars)');
        print('📥 OUTPUT tokens  : $outputTokens  (${result.length} chars)');
        print('🔢 TOTAL  tokens  : $_lastEstimatedTokens');
        print('💳 CREDITS to deduct: $creditCost');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return result;
      } else {
        debugPrint('❌ Hosted API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Error calling hosted model: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Network / API Exception: $e');
      rethrow;
    }
  }

  /// Credit cost tiers (mirrors CreditsService.calcCreditsFromTokens)
  num _calcCredits(int tokens) {
    return CreditsService.calcCreditsFromTokens(tokens);
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

  /// Generate Mindmap data from text
  Future<Map<String, dynamic>> generateMindmap(String text) async {
    final prompt = """
You are a Mindmap AI. Analyze the following text and create a mindmap structure.
Extract the main topic and its subtopics, and define relationships (edges) between them.

Text to analyze:
$text

Return the output STRICTLY as a JSON object, no explanations, no markdown. The JSON must have this exact structure:
{
  "nodes": [
    {"id": "1", "label": "Main Topic"},
    {"id": "2", "label": "Subtopic A"}
  ],
  "edges": [
    {"from": "1", "to": "2"}
  ]
}
Make sure 'id' is a string. Ensure the graph is logically connected like a tree.
""";

    String result = await _ask(prompt);
    
    // Clean JSON formatting if model returns markdown
    result = result.replaceAll("```json", "").replaceAll("```", "").trim();

    try {
      return Map<String, dynamic>.from(json.decode(result));
    } catch (e) {
      debugPrint("❌ JSON parse error in Mindmap generation: $e\nRaw text: $result");
      return {"nodes": [], "edges": []};
    }
  }

  /// Breakdown Syllabus into a Roadmap
  Future<Map<String, dynamic>> breakdownSyllabus(String syllabusText) async {
    // Truncate text if it's too long to avoid payload issues
    final String truncatedText = syllabusText.length > 30000 
        ? "${syllabusText.substring(0, 30000)}... [Truncated for brevity]"
        : syllabusText;

    final prompt = """
You are an Elite Academic Advisor and Curriculum Specialist. Your mission is to decompose the following syllabus into a master-class level study roadmap.

Syllabus Text:
$truncatedText

Requirements:
1. **Strategic Overview**: Professional title, high-level summary, difficulty, and prerequisites.
2. **Day-wise Breakdown**: Organize into clear "Day X" or "Chapter X" milestones.
3. **Structured Content**: For each milestone, provide:
   - A clear **Learning Goal**.
   - **detailedTopics**: A list of objects, each containing:
     - `topicTitle`: Short, punchy name.
     - `explanation`: Clear, sufficient study material.
     - `example`: A real-time, practical example.
     - `formulaOrRule`: Any relevant formula, grammar rule, or key takeaway (optional).
   - **keyTerms**: Essential vocabulary.
   - **estimatedHours**.

Ensure the content is vibrant, easy to read, and formatted specifically for a modern mobile learning app.

STRICT JSON OUTPUT ONLY:
{
  "title": "Master Roadmap Title",
  "description": "Short, professional summary.",
  "difficulty": "Intermediate",
  "prerequisites": ["Prereq 1"],
  "roadmap": [
    {
      "topic": "Day 1: Topic Name",
      "learningGoal": "Goal summary.",
      "estimatedHours": 2,
      "detailedTopics": [
        {
          "topicTitle": "Sub-topic 1",
          "explanation": "Detailed explanation...",
          "example": "Practical example...",
          "formulaOrRule": "Rule or Formula (if applicable)"
        }
      ],
      "keyTerms": ["Term 1"],
    }
  ],
  "studyTip": "A professional tip."
}
""";

    String result = await _ask(prompt);
    
    // Clean JSON formatting if model returns markdown
    result = result.replaceAll("```json", "").replaceAll("```", "").trim();

    try {
      return Map<String, dynamic>.from(json.decode(result));
    } catch (e) {
      debugPrint("❌ JSON parse error in Syllabus Breakdown: $e\nRaw text: $result");
      return {"title": "Error", "roadmap": [], "totalEstimatedHours": 0};
    }
  }

  /// 🧹 Notes Cleaner: Converts messy notes into structured study notes
  Future<String> cleanNotes(String messyNotes) async {
    final prompt = """
You are a Professional Note-Taking Expert. Your task is to transform the following messy, unorganized, or redundant notes into a clean, highly structured, and professional study document.

Messy Notes:
$messyNotes

Guidelines for Transformation:
1. **Clarity & Conciseness**: Remove all redundant words, irrelevant filler, and conversational fluff.
2. **Formatting (Clean View)**: 
   - Do NOT use symbols like #, ##, or * for emphasis or headers.
   - For **Headings**, use UPPERCASE text on a new line followed by a blank line.
   - For **Subheadings**, use Title Case text on a new line followed by a blank line.
   - Use bullet points (•) for lists.
3. **Structure**: 
   - Start with a clear Title in ALL CAPS.
   - Organize logically into sections with clear spacing between them.
   - Include a "KEY CONCEPTS" section at the end if applicable.
4. **Tone**: Maintain a professional, educational tone throughout.

STRICT INSTRUCTION: Do NOT include any introductory or concluding remarks. Provide ONLY the structured notes content.
""";

    String response = await _ask(prompt);
    // Extra safety: remove any stray hashes or asterisks the model might still produce
    return response.replaceAll('#', '').replaceAll('*', '').trim();
  }

  /// ✍️ Handwriting Optimizer: Refines messy OCR from handwritten notes
  Future<String> polishHandwritingOCR(String messyOcrText) async {
    final prompt = """
You are an expert at deciphering and organizing handwritten notes. The following text was extracted using OCR from a photo of handwritten notes. It likely contains many misread characters, spelling errors, and missing logical flow.

Messy OCR Text:
$messyOcrText

Your Mission:
1. **Decode & Correct**: Use the context to fix misread words and spelling errors.
2. **Structure**: Organize the corrected text into a clean, professional format.
3. **Format**: 
   - For **Headings**, use UPPERCASE text.
   - Use bullet points (•) for lists.
   - NO symbols like #, ##, or * should be used.
4. **Style**: If some parts are unintelligible, try to logically bridge them or focus on the clear parts to maintain useful information.

STRICT INSTRUCTION: Provide ONLY the corrected and structured notes. Do not include any meta-comments or introductory text.
""";

    String response = await _ask(prompt);
    return response.replaceAll('#', '').replaceAll('*', '').trim();
  }

  /// 📇 Flashcard Generator: Creates Q&A pairs from content
  Future<List<Map<String, String>>> generateFlashcards(String content, String difficulty) async {
    final prompt = """
You are an expert Educational Content Creator. Your task is to generate high-quality study flashcards from the provided content.

Content:
$content

Difficulty Level: $difficulty

Instructions:
1. **Q&A Pairs**: Create clear, concise question-answer pairs.
2. **Focus**: Target key concepts, definitions, formulas, and historical dates.
3. **Format**: Return ONLY a valid JSON array of objects. Each object must have "question" and "answer" keys.
4. **Quantity**: Aim for 5-10 cards depending on content depth.
5. **No Markup**: Do not include any introductory text or markdown code blocks (like ```json). Just the raw JSON.

Example Output:
[
  {"question": "What is Photosynthesis?", "answer": "The process by which plants use sunlight, water, and CO2 to create oxygen and energy in the form of sugar."},
  {"question": "Who discovered Penicillin?", "answer": "Alexander Fleming in 1928."}
]
""";

    String response = await _ask(prompt);
    
    // Clean potential markdown blocks
    response = response.replaceAll('```json', '').replaceAll('```', '').trim();
    
    try {
      final List<dynamic> decoded = jsonDecode(response);
      return decoded.map((item) => {
        "question": item["question"].toString(),
        "answer": item["answer"].toString(),
      }).toList();
    } catch (e) {
      debugPrint('Flashcard generation parsing error: $e. Raw response: $response');
      throw Exception('Failed to generate flashcards structure.');
    }
  }

  /// 📊 Quiz Analysis: Analyzes quiz performance and provides insights
  Future<Map<String, dynamic>> analyzeQuizPerformance({
    required List<Map<String, dynamic>> questions,
    required List<String> userAnswers,
  }) async {
    final performanceData = questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;
      final userAnswer = userAnswers[idx];
      return {
        "question": q["question"],
        "userAnswer": userAnswer,
        "correctAnswer": q["correctAnswer"],
        "isCorrect": userAnswer == q["correctAnswer"],
      };
    }).toList();

    final prompt = """
You are an Advanced Learning Strategist AI. Analyze the following quiz performance data and provide a concise, high-impact feedback report focused on improvement.

Quiz Data:
${jsonEncode(performanceData)}

Instructions:
1. **Mistake Analysis**: For each wrong answer, explain the core concept missed and provide a brief, helpful explanation.
2. **Key Weaknesses**: Identify the primary areas where the user struggled.
3. **Topics to Re-visit**: Identify 3-5 specific topics or subtopics for immediate review.
4. **Actionable Recommendations**: Provide sharp, actionable steps for improvement.

STRICT JSON OUTPUT ONLY:
{
  "mistakeAnalysis": [
    {"question": "...", "conceptMissed": "...", "explanation": "..."}
  ],
  "weaknesses": ["topicA", "topicB"],
  "topicsToRevisit": ["Detailed topic 1", "Detailed topic 2"],
  "recommendations": ["Action step 1", "Action step 2"]
}
""";

    String result = await _ask(prompt);
    result = result.replaceAll("```json", "").replaceAll("```", "").trim();

    try {
      return Map<String, dynamic>.from(json.decode(result));
    } catch (e) {
      debugPrint("❌ JSON parse error in Quiz Analysis: $e\\nRaw text: \$result");
      return {
        "mistakeAnalysis": [],
        "weaknesses": [],
        "topicsToRevisit": ["Review your primary materials."],
        "recommendations": ["Review your incorrect answers for deeper understanding."]
      };
    }
  }
}

