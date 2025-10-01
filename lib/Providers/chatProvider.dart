import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/geminiService.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      "text": text,
      "isUser": isUser,
      "timestamp": timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map["text"] ?? "",
      isUser: map["isUser"] ?? false,
      timestamp: DateTime.parse(map["timestamp"]),
    );
  }
}

class ChatProvider with ChangeNotifier {
  final GeminiService geminiService;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  ChatProvider({required this.geminiService}) {
    _loadMessages();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  /// Load messages from Firestore when provider initializes
  Future<void> _loadMessages() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("chats")
        .orderBy("timestamp", descending: false)
        .get();

    _messages.clear();
    _messages.addAll(
      snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList(),
    );
    notifyListeners();
  }

  /// Send a new message
  Future<void> sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Add user message
    final userMsg = ChatMessage(
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    await _saveMessage(userMsg, user.uid);

    _isLoading = true;
    notifyListeners();

    try {
      // 2. Prepare context (last 10 messages)
      final context = _messages.takeLast(10).map((m) {
        return {"role": m.isUser ? "user" : "assistant", "text": m.text};
      }).toList();

      // 3. Get AI reply
      final replyText = await geminiService.chatWithContext(query, context);

      final aiMsg = ChatMessage(
        text: replyText,
        isUser: false,
        timestamp: DateTime.now(),
      );

      _messages.add(aiMsg);
      await _saveMessage(aiMsg, user.uid);
    } catch (e) {
      final errorMsg = ChatMessage(
        text: "⚠️ Sorry, something went wrong. Please try again later.",
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(errorMsg);
      await _saveMessage(errorMsg, user.uid);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save message in Firestore
  Future<void> _saveMessage(ChatMessage msg, String uid) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("chats")
        .add(msg.toMap());
  }
}

extension TakeLast<T> on List<T> {
  Iterable<T> takeLast(int n) => skip(length - (length < n ? length : n));
}
