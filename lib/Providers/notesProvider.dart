// lib/providers/notes_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/notesModel.dart';
import '../services/Firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotesProvider with ChangeNotifier {
  final FirestoreService firestoreService;

  NotesProvider({required this.firestoreService});

  // ---------------- My Notes ----------------
  List<NoteModel> notes = [];
  bool isLoading = false;
  bool hasMore = true;
  DocumentSnapshot? lastDoc;

  // ---------------- Shared Notes ----------------
  List<NoteModel> sharedNotes = [];
  bool isLoadingShared = false;
  bool hasMoreShared = true;
  DocumentSnapshot? lastSharedDoc;

  Set<String> favoriteNotes = {};

  final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  // Current search query
  String currentQuery = '';

  /// Load OWN notes
  Future<void> loadNotes({bool reset = false, String query = ''}) async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();

    if (reset) {
      notes.clear();
      lastDoc = null;
      hasMore = true;
    }

    currentQuery = query;

    Query baseQuery = firestoreService.notesCollection
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(10);

    if (lastDoc != null) baseQuery = baseQuery.startAfterDocument(lastDoc!);

    final snap = await baseQuery.get();

    if (snap.docs.length < 10) hasMore = false;
    if (snap.docs.isNotEmpty) lastDoc = snap.docs.last;

    List<NoteModel> fetchedNotes = snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return NoteModel.fromMap(data);
    }).toList();

    // Local filter
    if (query.isNotEmpty) {
      fetchedNotes = fetchedNotes.where((n) {
        final titleMatch = n.title.toLowerCase().contains(query.toLowerCase());
        final tagsMatch =
        n.tags.any((t) => t.toLowerCase().contains(query.toLowerCase()));
        return titleMatch || tagsMatch;
      }).toList();
    }

    notes.addAll(fetchedNotes);

    // refresh favorites
    final favs = await firestoreService.fetchFavorites(uid);
    favoriteNotes = favs.toSet();

    isLoading = false;
    notifyListeners();
  }

  /// Load SHARED notes
  Future<void> loadSharedNotes({
    required String uid,
    bool reset = false,
    String query = '',
  })
  async {
    if (isLoadingShared) return;
    isLoadingShared = true;
    notifyListeners();

    if (reset) {
      sharedNotes.clear();
      lastSharedDoc = null;
      hasMoreShared = true;
    }

    Query baseQuery = firestoreService.notesCollection
        .where('withShared', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(10);

    if (lastSharedDoc != null) {
      baseQuery = baseQuery.startAfterDocument(lastSharedDoc!);
    }

    final snap = await baseQuery.get();

    if (snap.docs.length < 10) hasMoreShared = false;
    if (snap.docs.isNotEmpty) lastSharedDoc = snap.docs.last;

    List<NoteModel> fetchedNotes = [];
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;

      // get sharer details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(data['uid'])
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        data['ownerName'] = userData['name'] ?? '';
        data['ownerEmail'] = userData['email'] ?? '';
      }

      fetchedNotes.add(NoteModel.fromMap(data));
    }

    if (query.isNotEmpty) {
      fetchedNotes = fetchedNotes.where((n) {
        final titleMatch = n.title.toLowerCase().contains(query.toLowerCase());
        final tagsMatch = n.tags.any((t) => t.toLowerCase().contains(query.toLowerCase()));
        return titleMatch || tagsMatch;
      }).toList();
    }

    sharedNotes.addAll(fetchedNotes);

    // refresh favorites
    final favs = await firestoreService.fetchFavorites(uid);
    favoriteNotes = favs.toSet();

    isLoadingShared = false;
    notifyListeners();
  }


  // ---------------- Favorites ----------------
  bool isFavorite(NoteModel note) => favoriteNotes.contains(note.id);

  Future<void> toggleFavorite(NoteModel note) async {
    final isFav = isFavorite(note);

    if (isFav) {
      favoriteNotes.remove(note.id);
    } else {
      favoriteNotes.add(note.id);
    }
    notifyListeners();

    await firestoreService.toggleFavorite(note.id, uid, !isFav);

    // ✅ Update local cache (works for both notes & sharedNotes)
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      notes[idx] = notes[idx]; // force rebuild
    }
    final sharedIdx = sharedNotes.indexWhere((n) => n.id == note.id);
    if (sharedIdx != -1) {
      sharedNotes[sharedIdx] = sharedNotes[sharedIdx];
    }
    notifyListeners();
  }


  // ---------------- Edit Notes ----------------
  Future<void> editNote(NoteModel updatedNote) async {
    await firestoreService.updateNote(updatedNote);
    final index = notes.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      notes[index] = updatedNote;
      notifyListeners();
    }
  }

  // ---------------- Delete Notes ----------------
  Future<void> deleteNote(String noteId) async {
    try {
      // Delete from Firestore
      await firestoreService.deleteNote(noteId);
      
      // Remove from local lists
      notes.removeWhere((note) => note.id == noteId);
      sharedNotes.removeWhere((note) => note.id == noteId);
      
      // Remove from favorites if it exists
      favoriteNotes.remove(noteId);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete note: $e');
      rethrow;
    }
  }

  // ---------------- AI Summary ----------------
  Future<String?> generateSummaryForNote(
      NoteModel note, String content) async {
    try {
      final s = await firestoreService.geminiService.summarize(content);
      return s;
    } catch (e) {
      debugPrint('Summary generation failed: $e');
      return null;
    }
  }

  // ---------------- Search Users ----------------
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final searchTerm = query.trim().toLowerCase();
    if (searchTerm.isEmpty) {
      debugPrint("[searchUsers] Query is empty → returning []");
      return [];
    }

    debugPrint("[searchUsers] Searching for: '$searchTerm'");

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('keywords', arrayContains: searchTerm)
          .limit(20)
          .get();

      debugPrint("[searchUsers] Firestore returned ${snap.docs.length} docs");

      final users = snap.docs.map((doc) {
        final data = doc.data();
        debugPrint(
            "[searchUsers] Candidate: ${data['name']} (${data['email']}) uid=${data['uid']}");
        if (data['uid'] == uid) {
          debugPrint("[searchUsers] Skipping self: ${data['uid']}");
          return null;
        }
        return {
          'uid': data['uid'] ?? doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'profilePic': data['profilePic'] ?? '',
        };
      }).whereType<Map<String, dynamic>>().toList();

      debugPrint("[searchUsers] Final filtered users = ${users.length}");
      return users;
    } catch (e) {
      debugPrint("[searchUsers] Error: $e");
      return [];
    }
  }

  // ---------------- Share Notes ----------------
  Future<(List<String>, List<String>)> shareNoteWithUsers({
    required NoteModel note,
    required List<String> targetUids,
  })
  async {
    final docRef = firestoreService.notesCollection.doc(note.id);
    final current = note.withShared.toSet();
    final toAdd = targetUids.where((u) => !current.contains(u)).toList();
    final already = targetUids.where((u) => current.contains(u)).toList();

    if (toAdd.isNotEmpty) {
      await docRef.update({
        'withShared': FieldValue.arrayUnion(toAdd),
      });

      final idx = notes.indexWhere((n) => n.id == note.id);
      if (idx != -1) {
        notes[idx] = notes[idx]
            .copyWith(withShared: [...notes[idx].withShared, ...toAdd]);
        notifyListeners();
      }
    }

    return (toAdd, already);
  }
}
