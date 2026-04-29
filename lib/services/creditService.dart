import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';


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

      if (currentCredits < amount) {
        return false;
      }

      transaction.update(docRef, {"credits": currentCredits - amount});
      return true;
    });
  }

  /// Check if user has a minimum balance to start a feature
  Future<bool> hasMinimumBalance(num minAmount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final doc = await _firestore.collection("users").doc(uid).get();
    if (!doc.exists) return false;

    final credits = doc.data()?['credits'] ?? 0;
    return credits >= minAmount;
  }

  /// Deduct credits based on token usage after an AI call
  Future<bool> deductUsage({required int tokens, required String actionName}) async {
    final cost = calcCreditsFromTokens(tokens);
    debugPrint('💳 Usage-based deduction for $actionName: $cost credits ($tokens tokens)');
    return deductCredits(cost);
  }

  /// Dynamic token-based confirmation: Checks min balance, confirms usage, then executes.
  static Future<bool> confirmUsageAndCheckBalance({
    required BuildContext context,
    required String actionName,
    num minBalance = 0.5,
    required Future<void> Function() onConfirmedAction,
    VoidCallback? onCancel,
  }) async {
    final service = CreditsService();
    
    // 1. Initial Balance Check
    final hasMin = await service.hasMinimumBalance(minBalance);
    if (!hasMin) {
      if (context.mounted) {
        showInsufficientCreditsDialog(context);
      }
      onCancel?.call();
      return false;
    }

    // 2. Usage Confirmation
    final bool? confirm = Platform.isIOS
        ? await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text("Confirm $actionName"),
        content: const Text(
          "This feature uses credits based on generation length.\n(1000 tokens ≈ 1 credit)\nDo you want to continue?",
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
        title: Text("Confirm $actionName"),
        content: const Text(
          "This feature uses credits based on generation length.\n(1000 tokens ≈ 1 credit)\nDo you want to continue?",
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
      await onConfirmedAction();
      return true;
    }
    onCancel?.call();
    return false;
  }

  /// Standardized confirmation for fixed-cost actions.
  static Future<bool> confirmAndDeductCredits({
    required BuildContext context,
    required num cost,
    required String actionName,
    required Future<void> Function() onConfirmedAction,
  }) async {
    final service = CreditsService();

    // 1. Check Balance
    final hasMin = await service.hasMinimumBalance(cost);
    if (!hasMin) {
      if (context.mounted) {
        showInsufficientCreditsDialog(context);
      }
      return false;
    }

    // 2. Usage Confirmation
    final bool? confirm = Platform.isIOS
        ? await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text("Confirm $actionName"),
        content: Text(
          "This action costs $cost credits.\nDo you want to continue?",
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
        title: Text("Confirm $actionName"),
        content: Text(
          "This action costs $cost credits.\nDo you want to continue?",
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
      await service.deductCredits(cost);
      await onConfirmedAction();
      return true;
    }
    return false;
  }

  /// Show the premium insufficient credits dialog
  static void showInsufficientCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const PremiumCreditsDialog(),
    );
  }
}

class PremiumCreditsDialog extends StatelessWidget {
  const PremiumCreditsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900]!.withOpacity(0.9) : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Image / Header Section
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 160,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF8E24AA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                  ),
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Icon(
                      Icons.stars_rounded,
                      size: 140,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Out of Credits",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    Text(
                      "Elevate Your Learning",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You've run out of AI credits. Unlock personalized tutoring, instant solutions, and premium study roadmaps with a credit top-up.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Special Offer Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "SPECIAL OFFER: +25% Extra",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                Text(
                                  "On all credit packs today only!",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF4A47A3)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreditsStoreScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            "Get Credits Now",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Maybe Later",
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
