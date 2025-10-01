// lib/models/notesModel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String uid;
  final String title;
  final String content;
  final String? summary;
  final DateTime createdAt;
  final List<String> tags;

  // ✅ Shared with users
  final List<String> withShared;

  // ✅ Extra for displaying who shared it
  final String? ownerName;
  final String? ownerEmail;

  NoteModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    this.summary,
    DateTime? createdAt,
    this.tags = const [],
    this.withShared = const [],
    this.ownerName,
    this.ownerEmail,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'summary': summary,
      'tags': tags,
      'withShared': withShared,
      'createdAt': Timestamp.fromDate(createdAt),
      // ✅ optional, only store if available
      if (ownerName != null) 'ownerName': ownerName,
      if (ownerEmail != null) 'ownerEmail': ownerEmail,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      summary: map['summary'],
      tags: List<String>.from(map['tags'] ?? []),
      withShared: List<String>.from(map['withShared'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerName: map['ownerName'],  // ✅ may not exist
      ownerEmail: map['ownerEmail'],
    );
  }

  NoteModel copyWith({
    String? title,
    String? content,
    String? summary,
    List<String>? tags,
    List<String>? withShared,
    String? ownerName,
    String? ownerEmail,
  }) {
    return NoteModel(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      withShared: withShared ?? this.withShared,
      createdAt: createdAt,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}
