import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Service for In-App Purchases (credits, Firestore integration)
class IAPService extends ChangeNotifier {
  // Product IDs
  static const List<String> creditIds = [
    "com.vectorlabs.mentorai.50credits",
    "com.vectorlabs.mentorai100credits",
    "com.vectorlabs.mentorai500credits",
  ];

  // Subscription ID
  static const String subscriptionId = "com.vectorlabs.monthlyplan";

  // All product IDs combined
  static Set<String> get allProductIds => {...creditIds, subscriptionId};

  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _sub;

  List<ProductDetails> products = [];
  bool _initialized = false;
  bool _isLoading = false;
  bool _isBuying = false;
  bool _isPro = false;
  String? _errorMessage;

  /// Track only purchases that the user initiated in this session
  final Set<String> _pendingProductIds = {};

  bool get isLoading => _isLoading;
  bool get isBuying => _isBuying;
  bool get isPro => _isPro;
  String? get errorMessage => _errorMessage;

  final void Function(Object error)? onError;

  IAPService({this.onError});

  Future<void> init() async {
    if (_initialized) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) {
        debugPrint("❌ Purchase stream error: $e");
        onError?.call(e);
      },
    );

    _initialized = true;

    final available = await _iap.isAvailable();
    if (!available) {
      _errorMessage = "In-App Purchases not available.";
      _isLoading = false;
      notifyListeners();
      return;
    }

    final response = await _iap.queryProductDetails(allProductIds);
    if (response.error != null) {
      _errorMessage = response.error!.message;
      _isLoading = false;
      notifyListeners();
      return;
    }

    products = response.productDetails;
    _isLoading = false;

    // Check subscription status on startup
    await checkSubscriptionStatus();

    notifyListeners();
  }

  Future<void> restore() async {
    debugPrint("🔹 Restoring purchases...");

    bool restoredSomething = false;
    final completer = Completer<void>();

    final sub = _iap.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.restored) {
          restoredSomething = true;
        }
        _onPurchaseUpdated([purchase]);
      }
      completer.complete(); // signal that at least one response arrived
    });

    await _iap.restorePurchases();

    // Wait for the restore flow to complete
    await completer.future;
    await sub.cancel();

    if (!restoredSomething) {
      onError?.call("No past purchases found to restore.");
      debugPrint("⚠️ No purchases were restored");
    } else {
      debugPrint("Purchase Restored");
      // _showMessage("Purchases restored successfully ✅", success: true);
    }
  }

  /// Buy credits (only marks as pending for this session)
  Future<void> buyCredits(String creditId) async {
    try {
      _isBuying = true;
      notifyListeners();

      final product = products.firstWhere((p) => p.id == creditId);
      final param = PurchaseParam(productDetails: product);

      _pendingProductIds.add(product.id); // mark as "user initiated"

      await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
      debugPrint("🔹 Purchase requested: ${product.id}");
    } catch (e, stack) {
      debugPrint("❌ Error initiating credits purchase: $e\n$stack");
      onError?.call(e);
      _isBuying = false;
      notifyListeners();
    }
  }

  /// Buy subscription
  Future<void> buySubscription() async {
    try {
      _isBuying = true;
      notifyListeners();

      final product = products.firstWhere((p) => p.id == subscriptionId);
      final param = PurchaseParam(productDetails: product);

      _pendingProductIds.add(product.id); // mark as "user initiated"

      await _iap.buyNonConsumable(purchaseParam: param);
      debugPrint("🔹 Subscription purchase requested: ${product.id}");
    } catch (e, stack) {
      debugPrint("❌ Error initiating subscription purchase: $e\n$stack");
      onError?.call(e);
      _isBuying = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (final p in purchases) {
      try {
        switch (p.status) {
          case PurchaseStatus.pending:
            debugPrint("⏳ Pending: ${p.productID}");
            break;

          case PurchaseStatus.purchased:
            // Handle subscription purchase
            if (p.productID == subscriptionId) {
              await _updateSubscriptionStatus(user.uid, true);
              debugPrint("✅ Subscription activated for user: ${user.uid}");
            }
            // Handle credit purchase
            else if (creditIds.contains(p.productID)) {
              // Only credit if user initiated AND not already processed
              if (_pendingProductIds.contains(p.productID) &&
                  p.verificationData.localVerificationData.isNotEmpty) {
                await _addCreditsToFirestore(user.uid, p.productID);
                debugPrint("✅ Credits added for ${p.productID}");
                _pendingProductIds.remove(p.productID);
              } else {
                debugPrint(
                  "ℹ️ Ignoring duplicate/replayed purchase: ${p.productID}",
                );
              }
            }

            if (p.pendingCompletePurchase) {
              await _iap.completePurchase(p);
            }
            break;

          case PurchaseStatus.restored:
            // Handle subscription restoration
            if (p.productID == subscriptionId) {
              await _updateSubscriptionStatus(user.uid, true);
              debugPrint("✅ Subscription restored for user: ${user.uid}");
            } else {
              // Ignore restored for consumables
              debugPrint("ℹ️ Ignoring restored (consumable): ${p.productID}");
            }

            if (p.pendingCompletePurchase) {
              await _iap.completePurchase(p);
            }
            break;

          case PurchaseStatus.error:
            debugPrint("❌ Purchase error: ${p.error}");
            onError?.call(p.error ?? "Unknown error");
            break;

          case PurchaseStatus.canceled:
            debugPrint("⚠️ Purchase canceled: ${p.productID}");
            break;
        }
      } finally {
        _isBuying = false;
        notifyListeners();
      }
    }
  }

  /// Get credits amount for a product ID
  static int getCreditsForProduct(String productId) {
    return switch (productId) {
      "com.vectorlabs.mentorai.50credits" => 50,
      "com.vectorlabs.mentorai100credits" => 100,
      "com.vectorlabs.mentorai500credits" => 500,
      _ => 0,
    };
  }

  Future<void> _addCreditsToFirestore(String uid, String productId) async {
    int creditsToAdd = getCreditsForProduct(productId);

    if (creditsToAdd == 0) return;

    final docRef = FirebaseFirestore.instance.collection("users").doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final num currentCredits = snapshot.data()?['credits'] ?? 0;
      tx.update(docRef, {
        "credits": currentCredits + creditsToAdd,
        "isPro": true, // ✅ Becomes Premium on purchase
      });
    });

    _isPro = true;
    notifyListeners();

    debugPrint("✅ Firestore updated with $creditsToAdd credits for $uid");
  }

  /// Update subscription status in Firestore and local state
  Future<void> _updateSubscriptionStatus(String uid, bool isSubscribed) async {
    try {
      final docRef = FirebaseFirestore.instance.collection("users").doc(uid);

      await docRef.update({"isPro": isSubscribed});

      _isPro = isSubscribed;
      notifyListeners();

      debugPrint("✅ Subscription status updated in Firestore: $isSubscribed");
    } catch (e) {
      debugPrint("❌ Error updating subscription status: $e");
      // Still update local state even if Firestore update fails
      _isPro = isSubscribed;
      notifyListeners();
    }
  }

  /// Check current subscription status from Firestore
  Future<void> checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid);
      final doc = await docRef.get();

      if (doc.exists) {
        final isPro = doc.data()?['isPro'] ?? false;
        if (_isPro != isPro) {
          _isPro = isPro;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("❌ Error checking subscription status: $e");
    }
  }

  Future<void> verifyMonthlySubscription() async {
    debugPrint("👉 verifyMonthlySubscription() called");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("⚠️ No user logged in → skipping subscription verification");
      return;
    }

    debugPrint("🔹 Verifying monthly subscription for user: ${user.uid}");

    final pastPurchases = <PurchaseDetails>[];
    final completer = Completer<void>();
    late final StreamSubscription<List<PurchaseDetails>> sub;

    debugPrint("⏳ Setting up purchase stream listener...");
    sub = _iap.purchaseStream.listen(
      (purchases) {
        debugPrint("📦 Purchase stream event: ${purchases.length} purchase(s)");
        for (final p in purchases) {
          debugPrint("   • ProductID=${p.productID}, status=${p.status}");
        }
        pastPurchases.addAll(purchases);

        if (!completer.isCompleted) {
          debugPrint("✅ Completing the completer from stream");
          completer.complete();
        }

        debugPrint("🔌 Canceling purchase stream listener");
        sub.cancel();
      },
      onError: (err) {
        debugPrint("❌ Error in purchase stream: $err");
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      },
    );

    debugPrint("🔄 Calling restorePurchases()...");
    await _iap.restorePurchases();

    debugPrint("⏳ Waiting for purchase stream events (timeout 10s)...");
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint("⏱️ Timeout reached. No purchases received from stream.");
        if (!completer.isCompleted) completer.complete();
        return;
      },
    );

    debugPrint(
      "✅ Restore completed. Past purchases count: ${pastPurchases.length}",
    );

    bool hasActiveSub = false;

    for (final purchase in pastPurchases) {
      debugPrint(
        "🔍 Checking purchase: ${purchase.productID}, status=${purchase.status}",
      );
      if (purchase.productID != subscriptionId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final rawReceipt = purchase.verificationData.localVerificationData;
        debugPrint("📜 Raw receipt: $rawReceipt");

        try {
          Map<String, dynamic> decoded;

          if (rawReceipt.trim().startsWith("{")) {
            decoded = jsonDecode(rawReceipt); // Sandbox JSON
          } else {
            decoded = jsonDecode(
              utf8.decode(base64Decode(rawReceipt)),
            ); // App Store JSON
          }

          DateTime? expiryDate;

          if (decoded['expiresDate'] != null) {
            final expiresMs =
                int.tryParse(decoded['expiresDate'].toString()) ?? 0;
            expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresMs);
            debugPrint("📅 iOS expiresDate found: $expiryDate");
          } else if (decoded['latest_receipt_info'] != null) {
            final latest = decoded['latest_receipt_info'] as List;
            if (latest.isNotEmpty) {
              final last = latest.last as Map;
              final expiresMs =
                  int.tryParse(last['expires_date_ms'] ?? '0') ?? 0;
              expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresMs);
              debugPrint("📅 latest_receipt_info expiresDate: $expiryDate");
            }
          } else {
            debugPrint("⚠️ No expiration info found in receipt JSON");
          }

          if (expiryDate != null) {
            if (expiryDate.isAfter(DateTime.now())) {
              debugPrint("✅ Subscription is ACTIVE");
              hasActiveSub = true;
            } else {
              debugPrint("⚠️ Subscription expired on $expiryDate");
              hasActiveSub = false;
            }
          }
        } catch (e, st) {
          debugPrint("❌ Error decoding receipt: $e\n$st");
        }
      }
    }

    // Update Firestore instead of Realtime Database
    final docRef = FirebaseFirestore.instance.collection("users").doc(user.uid);
    debugPrint("📡 Updating Firestore: isPro=$hasActiveSub");
    await docRef.update({"isPro": hasActiveSub});
    debugPrint(
      hasActiveSub
          ? "✅ Firestore updated: isPro=true"
          : "⚠️ Firestore updated: isPro=false",
    );

    // Update local state
    _isPro = hasActiveSub;
    notifyListeners();

    debugPrint("🏁 verifyMonthlySubscription() finished");
  }

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    super.dispose();
  }
}

