
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Screens/purchaseScreen/creditPurchaseScreen.dart';

class CreditsService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ─── Token-based pricing tiers ────────────────────────────────────────────
  /// Returns credit cost based on token count.
  /// 1000 tokens = 1 credit.
  static num calcCreditsFromTokens(int tokens) {
    return tokens / 1000.0;
  }

  /// Silently deduct credits after a successful AI call (no dialog).
  /// Call this right after getting a response from GeminiService.
  /// Returns true if deduction succeeded, false if insufficient credits.
  Future<bool> deductForAiCall(int estimatedTokens) async {
    final cost = calcCreditsFromTokens(estimatedTokens);
    return deductCredits(cost);
  }

  /// Deduct credits from current user
  Future<bool> deductCredits(num amount) async {
    // ─── Temporarily bypassed for testing ───────────────
    return true;
    /*
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final docRef = _firestore.collection("users").doc(uid);
    return _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return false;

      final currentCredits = snap['credits'] ?? 0;

      // ❌ FIX: don't throw, just return false
      if (currentCredits < amount) {
        return false;
      }

      transaction.update(docRef, {"credits": currentCredits - amount});
      return true;
    });
    */
  }

  /// Show confirmation dialog and deduct credits if confirmed
  static Future<bool> confirmAndDeductCredits({
    required BuildContext context,
    required num cost,
    required String actionName,
    required Future<void> Function() onConfirmedAction,
  }) async {
    // ─── Temporarily bypassed for testing ───────────────
    // Just run the action directly without dialogs or deduction
    await onConfirmedAction();
    return true;
  }
}
