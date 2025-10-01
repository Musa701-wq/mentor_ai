import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String grade;
  final String goal;
  final List<String> subjects;
  final String profilePic;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final bool onboardingCompleted;
  final List<String> keywords; // ✅ NEW
  final int credits;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.grade,
    required this.goal,
    required this.subjects,
    required this.profilePic,
    this.createdAt,
    this.lastLogin,
    this.onboardingCompleted = true,
    this.keywords = const [], // ✅ default empty
    this.credits = 500
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'grade': grade,
      'goal': goal,
      'subjects': subjects,
      'profilePic': profilePic,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'onboardingCompleted': onboardingCompleted,
      'keywords': keywords, // ✅ save keywords
      'credits': credits
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      grade: map['grade'] ?? '',
      goal: map['goal'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
      profilePic: map['profilePic'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      lastLogin: map['lastLogin'] != null ? (map['lastLogin'] as Timestamp).toDate() : null,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      keywords: List<String>.from(map['keywords'] ?? []), // ✅ load keywords
      credits: map['credits']??0
    );
  }
}
