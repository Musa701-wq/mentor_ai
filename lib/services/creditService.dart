
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
  }

  /// Show confirmation dialog and deduct credits if confirmed
  static Future<bool> confirmAndDeductCredits({
    required BuildContext context,
    required num cost,
    required String actionName,
    required Future<void> Function() onConfirmedAction,
  }) async {
    final bool? confirm = Platform.isIOS
        ? await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Confirm Action"),
        content: Text(
          "This action ($actionName) will deduct ${cost.toStringAsFixed(2)} credits.\nDo you want to continue?",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Continue"),
          ),
        ],
      ),
    )
        : await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Action"),
        content: Text(
          "This action ($actionName) will deduct ${cost.toStringAsFixed(2)} credits.\nDo you want to continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final service = CreditsService();
      final success = await service.deductCredits(cost);

      if (!success) {
        // 🚨 Not enough credits → Show Premium Custom Dialog
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20.0,
                      offset: Offset(0.0, 10.0),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 60,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Insufficient Credits",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D2B4E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "You've run out of AI fuel! Refill your credits now to continue experiencing the power of AI in your studies.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Maybe Later",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreditsStoreScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Get Credits",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return false;
      }

      // ✅ Deduction success → run the action
      await onConfirmedAction();
      return true;
    }
    return false;
  }
}
