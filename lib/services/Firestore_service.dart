// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notesModel.dart';
import '../models/usermodel.dart';
import 'geminiService.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeminiService geminiService = GeminiService();

  // Expose notes collection for providers
  CollectionReference get notesCollection => _firestore.collection('notes');

  // ------------------- Users -------------------
  Future<void> saveUserProfile(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> markOnboardingCompleted(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'onboardingCompleted': true,
    });
  }

  // ------------------- Notes -------------------
  Future<void> saveNote(NoteModel note) async {
    await _firestore.collection('notes').doc(note.id).set(note.toMap());
  }

  Future<void> updateNote(NoteModel note) async {
    await _firestore.collection('notes').doc(note.id).update(note.toMap());
  }

  Future<void> deleteNote(String noteId) async {
    await _firestore.collection('notes').doc(noteId).delete();
  }

  Future<String> createNoteId() async {
    return _firestore.collection('notes').doc().id;
  }

  // Paginated notes fetch
  Future<List<NoteModel>> fetchNotes({
    DocumentSnapshot? lastDoc,
    int limit = 10,
  }) async {
    Query query = _firestore
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (lastDoc != null) query = query.startAfterDocument(lastDoc);

    final snap = await query.get();
    return snap.docs
        .map((d) => NoteModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  // ------------------- Favorites -------------------
  Future<void> toggleFavorite(String noteId, String uid, bool isFav) async {
    final docRef = _firestore.collection('favorites').doc('$uid-$noteId');
    if (isFav) {
      await docRef.set({
        'uid': uid,
        'noteId': noteId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.delete();
    }
  }

  Future<bool> isFavorite(String noteId, String uid) async {
    final doc = await _firestore
        .collection('favorites')
        .doc('$uid-$noteId')
        .get();
    return doc.exists;
  }

  Future<List<String>> fetchFavorites(String uid) async {
    final snap = await _firestore
        .collection('favorites')
        .where('uid', isEqualTo: uid)
        .get();
    return snap.docs.map((d) => d['noteId'] as String).toList();
  }

  Future<void> saveStudyPlan(Map<String, dynamic> studyPlanData) async {
    try {
      // You can save it under a "studyPlans" collection
      // Optionally, you can use a generated ID or user's UID
      await _firestore.collection('studyPlans').add(studyPlanData);
    } catch (e) {
      print("❌ Error saving study plan: $e");
      throw Exception("Failed to save study plan: $e");
    }
  }

  /// Optionally, fetch study plans for a user
  Future<List<Map<String, dynamic>>> getStudyPlans(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('studyPlans')
          .where('uid', isEqualTo: uid) // if you store user UID
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("❌ Error fetching study plans: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserPlans() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection("studyPlans")
        .where("uid", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "id": doc.id, // ✅ attach Firestore doc ID
        ...data,
      };
    }).toList();
  }

  Future<void> updatePlanCompletion(String planId, bool isCompleted) async {
    await _firestore.collection("studyPlans").doc(planId).update({
      "completed": isCompleted,
    });
  }

  Future<void> deletePlan(String planId) async {
    await _firestore.collection("studyPlans").doc(planId).delete();
  }

  Future<void> addHomework(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("homeworks")
        .add(data);
  }

  Future<List<Map<String, dynamic>>> fetchHomeworks(String uid) async {
    final snapshot = await _firestore
        .collection("users")
        .doc(uid)
        .collection("homeworks")
        .orderBy("timestamp", descending: true)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> fetchHomeworksPaginated(
    String uid, {
    int limit = 10,
    DocumentSnapshot? startAfterDoc,
    String? searchQuery,
  }) async {
    Query query = _firestore
        .collection("users")
        .doc(uid)
        .collection("homeworks")
        .orderBy("timestamp", descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    // 🔍 Basic search on "title"
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final end = searchQuery + '\uf8ff';
      query = query.orderBy("title").startAt([searchQuery]).endAt([end]);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      return {
        ...doc.data() as Map<String, dynamic>,
        "id": doc.id,
        "snapshot": doc, // 🔑 Keep snapshot for pagination
      };
    }).toList();
  }

  // ------------------- Syllabus -------------------
  Future<void> addSyllabus(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("syllabuses")
        .add(data);
  }

  Future<List<Map<String, dynamic>>> fetchSyllabusesPaginated(
    String uid, {
    int limit = 10,
    DocumentSnapshot? startAfterDoc,
    String? searchQuery,
  }) async {
    Query query = _firestore
        .collection("users")
        .doc(uid)
        .collection("syllabuses")
        .orderBy("timestamp", descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    // 🔍 Basic search on "title"
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final end = searchQuery + '\uf8ff';
      query = query.orderBy("title").startAt([searchQuery]).endAt([end]);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      return {
        ...doc.data() as Map<String, dynamic>,
        "id": doc.id,
        "snapshot": doc,
      };
    }).toList();
  }

  // ------------------- ELI5 (Explain Like I'm 5) -------------------
  Future<String> saveELI5(String uid, Map<String, dynamic> data) async {
    final docRef = await _firestore
        .collection("users")
        .doc(uid)
        .collection("eli5_history")
        .add({
      ...data,
      "timestamp": FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Stream<List<Map<String, dynamic>>> getELI5HistoryStream(String uid) {
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("eli5_history")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> fetchELI5History(String uid) async {
    final snapshot = await _firestore
        .collection("users")
        .doc(uid)
        .collection("eli5_history")
        .orderBy("timestamp", descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        if (data != null) ...data,
        "id": doc.id,
      };
    }).toList();
  }

  Future<void> updateELI5Image(String uid, String docId, String base64Image) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("eli5_history")
        .doc(docId)
        .update({
      'imageData': base64Image,
    });
  }

  // ------------------- INFOGRAPHIC CONVERTER -------------------

  /// Stream of user infographic history
  Stream<QuerySnapshot> getInfographicHistoryStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('infographics')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Initial save of infographic notes (Text-First strategy)
  Future<String> saveInfographic({
    required String userId,
    required String notes,
    required String prompt,
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('infographics')
        .doc();

    await docRef.set({
      'id': docRef.id,
      'notes': notes,
      'prompt': prompt,
      'timestamp': FieldValue.serverTimestamp(),
      'imageData': null, // Will be updated asynchronously
    });

    return docRef.id;
  }

  /// Update infographic record with Base64 image data
  Future<void> updateInfographicImage(String userId, String docId, String base64Image) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('infographics')
        .doc(docId)
        .update({
      'imageData': base64Image,
    });
  }
}

