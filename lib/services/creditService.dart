// import 'dart:io' show Platform;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// class CreditsService {
//   final _firestore = FirebaseFirestore.instance;
//   final _auth = FirebaseAuth.instance;
//
//   /// Deduct credits from current user
//   Future<bool> deductCredits(int amount) async {
//     final uid = _auth.currentUser?.uid;
//     if (uid == null) return false;
//
//     final docRef = _firestore.collection("users").doc(uid);
//
//     return _firestore.runTransaction((transaction) async {
//       final snap = await transaction.get(docRef);
//       if (!snap.exists) return false;
//
//       final currentCredits = snap['credits'] ?? 0;
//       if (currentCredits < amount) {
//         throw Exception("Not enough credits");
//       }
//
//       transaction.update(docRef, {"credits": currentCredits - amount});
//       return true;
//     });
//   }
//
//   /// Show confirmation dialog and deduct credits if confirmed
//   static Future<bool> confirmAndDeductCredits({
//     required BuildContext context,
//     required int cost,
//     required String actionName,
//     required Future<void> Function() onConfirmedAction,
//   }) async {
//     final bool? confirm = Platform.isIOS
//         ? await showCupertinoDialog<bool>(
//       context: context,
//       builder: (ctx) => CupertinoAlertDialog(
//         title: const Text("Confirm Action"),
//         content: Text(
//           "This action ($actionName) will deduct $cost credits.\nDo you want to continue?",
//         ),
//         actions: [
//           CupertinoDialogAction(
//             isDefaultAction: false,
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text("Cancel"),
//           ),
//           CupertinoDialogAction(
//             isDefaultAction: true,
//             onPressed: () => Navigator.pop(ctx, true),
//             child: const Text("Continue"),
//           ),
//         ],
//       ),
//     )
//         : await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Confirm Action"),
//         content: Text(
//           "This action ($actionName) will deduct $cost credits.\nDo you want to continue?",
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.purple,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text("Continue"),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm == true) {
//       try {
//         final service = CreditsService();
//         final success = await service.deductCredits(cost);
//         if (!success) {
//           throw Exception("Failed to deduct credits.");
//         }
//         await onConfirmedAction();
//         return true;
//       } catch (e) {
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text("Error: $e"),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }
//     return false;
//   }
// }



import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ✅ Replace this import with your actual BuyCreditsScreen page
// import '../../Screens/buyCredits/buyCreditsScreen.dart';

class CreditsService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Deduct credits from current user
  Future<bool> deductCredits(int amount) async {
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
    required int cost,
    required String actionName,
    required Future<void> Function() onConfirmedAction,
  }) async {
    final bool? confirm = Platform.isIOS
        ? await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Confirm Action"),
        content: Text(
          "This action ($actionName) will deduct $cost credits.\nDo you want to continue?",
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
          "This action ($actionName) will deduct $cost credits.\nDo you want to continue?",
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
        // 🚨 Not enough credits → Show Buy dialog
        if (context.mounted) {
          Platform.isIOS
              ? await showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text("Not enough credits"),
              content: const Text(
                  "You don’t have enough credits. Would you like to buy more?"),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    // ✅ Navigate to Buy Credits Page
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //       builder: (_) => const BuyCreditsScreen()),
                    // );
                  },
                  child: const Text("Buy"),
                ),
              ],
            ),
          )
              : await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Not enough credits"),
              content: const Text(
                  "You don’t have enough credits. Would you like to buy more?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // ✅ Navigate to Buy Credits Page
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //       builder: (_) => const BuyCreditsScreen()),
                    // );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Buy"),
                ),
              ],
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
