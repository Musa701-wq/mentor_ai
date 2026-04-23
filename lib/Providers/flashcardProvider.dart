import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flashcardModel.dart';

class FlashcardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<FlashcardDeckModel> _decks = [];
  bool _isLoading = false;

  List<FlashcardDeckModel> get decks => _decks;
  bool get isLoading => _isLoading;

  Future<void> loadDecks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('flashcardDecks')
          .orderBy('createdAt', descending: true)
          .get();

      _decks = snapshot.docs.map((doc) => FlashcardDeckModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error loading decks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createDeckWithCards(String title, String description, List<Map<String, String>> cards) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final deckId = _firestore.collection('users').doc(uid).collection('flashcardDecks').doc().id;
    final now = DateTime.now();

    final deck = FlashcardDeckModel(
      id: deckId,
      uid: uid,
      title: title,
      description: description,
      createdAt: now,
      cardCount: cards.length,
    );

    final batch = _firestore.batch();
    
    // Add deck
    batch.set(
      _firestore.collection('users').doc(uid).collection('flashcardDecks').doc(deckId),
      deck.toMap(),
    );

    // Add cards
    for (var card in cards) {
      final cardId = _firestore.collection('users').doc(uid).collection('flashcards').doc().id;
      final flashcard = FlashcardModel(
        id: cardId,
        uid: uid,
        deckId: deckId,
        question: card['question'] ?? '',
        answer: card['answer'] ?? '',
        nextReviewDate: now,
        createdAt: now,
      );
      batch.set(
        _firestore.collection('users').doc(uid).collection('flashcards').doc(cardId),
        flashcard.toMap(),
      );
    }

    await batch.commit();
    await loadDecks();
  }

  Future<List<FlashcardModel>> loadCardsForDeck(String deckId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('flashcards')
          .where('deckId', isEqualTo: deckId)
          .get();

      return snapshot.docs.map((doc) => FlashcardModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error loading cards: $e');
      return [];
    }
  }
}
