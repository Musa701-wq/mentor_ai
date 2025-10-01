import 'package:cloud_firestore/cloud_firestore.dart';

class QuizModel {
  final String id;
  final String userId;
  final String title;
  final int totalQuestions;
  final String source;
  final DateTime createdAt;
  final List<String> withShared;

  /// 👇 New fields
  final String ownerName;
  final String ownerEmail;

  QuizModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.totalQuestions,
    required this.source,
    required this.createdAt,
    this.withShared = const [],
    this.ownerName = '',
    this.ownerEmail = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'totalQuestions': totalQuestions,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      'withShared': withShared,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
    };
  }

  factory QuizModel.fromMap(Map<String, dynamic> map) {
    return QuizModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      totalQuestions: map['totalQuestions'] ?? 0,
      source: map['source'] ?? 'manual',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      withShared: List<String>.from(map['withShared'] ?? []),
      ownerName: map['ownerName'] ?? '',
      ownerEmail: map['ownerEmail'] ?? '',
    );
  }

  QuizModel copyWith({
    String? id,
    String? userId,
    String? title,
    int? totalQuestions,
    String? source,
    DateTime? createdAt,
    List<String>? withShared,
    String? ownerName,
    String? ownerEmail,
  }) {
    return QuizModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      withShared: withShared ?? this.withShared,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}
