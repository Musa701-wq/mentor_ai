import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardModel {
  final String id;
  final String uid;
  final String deckId;
  final String question;
  final String answer;
  final String difficulty; // easy, medium, hard
  final int interval; // in days for spaced repetition
  final double easeFactor;
  final DateTime nextReviewDate;
  final List<String> tags;
  final DateTime createdAt;

  FlashcardModel({
    required this.id,
    required this.uid,
    required this.deckId,
    required this.question,
    required this.answer,
    this.difficulty = 'medium',
    this.interval = 0,
    this.easeFactor = 2.5,
    required this.nextReviewDate,
    this.tags = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'deckId': deckId,
      'question': question,
      'answer': answer,
      'difficulty': difficulty,
      'interval': interval,
      'easeFactor': easeFactor,
      'nextReviewDate': Timestamp.fromDate(nextReviewDate),
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FlashcardModel.fromMap(Map<String, dynamic> map) {
    return FlashcardModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      deckId: map['deckId'] ?? '',
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
      difficulty: map['difficulty'] ?? 'medium',
      interval: map['interval'] ?? 0,
      easeFactor: (map['easeFactor'] ?? 2.5).toDouble(),
      nextReviewDate: (map['nextReviewDate'] as Timestamp).toDate(),
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class FlashcardDeckModel {
  final String id;
  final String uid;
  final String title;
  final String description;
  final DateTime createdAt;
  final int cardCount;

  FlashcardDeckModel({
    required this.id,
    required this.uid,
    required this.title,
    this.description = '',
    required this.createdAt,
    this.cardCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'cardCount': cardCount,
    };
  }

  factory FlashcardDeckModel.fromMap(Map<String, dynamic> map) {
    return FlashcardDeckModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      cardCount: map['cardCount'] ?? 0,
    );
  }
}
