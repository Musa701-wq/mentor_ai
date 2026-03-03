import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../Providers/authProvider.dart';
import '../widgets/SignInButton.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<authProvider1>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String _friendlyErrorMessage(Object e) {
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'account-exists-with-different-credential':
            return 'Use the sign-in method previously used for this email.';
          case 'invalid-credential':
            return 'Invalid sign-in. Please try again.';
          case 'user-disabled':
            return 'Account disabled. Please contact support.';
          case 'operation-not-allowed':
            return 'Sign-in method not enabled. Please contact support.';
          case 'network-request-failed':
            return 'Network error. Check your connection and try again.';
          case 'too-many-requests':
            return 'Too many attempts. Please wait and try again.';
          case 'web-context-canceled':
          case 'popup-closed-by-user':
            return '';
          default:
            return 'Sign in Cancelled. Please try again.';
        }
      }

      if (e is PlatformException) {
        switch (e.code) {
          case 'sign_in_canceled':
          case 'popup_closed_by_user':
            return '';
          case 'network_error':
            return 'Network error. Check your connection and try again.';
          default:
            break;
        }
      }

      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel')) return '';
      if (msg.contains('network') || msg.contains('timeout')) {
        return 'Network error. Check your connection and try again.';
      }
      if (msg.contains('different-credential')) {
        return 'Use the sign-in method previously used for this email.';
      }
      return '';
    }

    Future<void> _handleLogin(Future<void> Function() loginFn) async {
      try {
        await loginFn();

        // Optional: log basic user info for debugging post sign-in
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          debugPrint('✅ Signed in: uid=${user.uid}, email=${user.email}, name=${user.displayName}');
        }
      } on UnsupportedError catch (e, stack) {
        // Provide clearer feedback when Apple sign-in is used on unsupported platforms
        debugPrint("⚠️ Unsupported platform for Apple Sign-In: $e\n$stack");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: const Text('Apple Sign-In is only supported on iOS and macOS.'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e, stack) {
        debugPrint("❌ FirebaseAuth sign in failed: ${e.code} ${e.message}\n$stack");
        if (context.mounted) {
          final message = _friendlyErrorMessage(e).trim();

          if (message.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                content: Text(message),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

        }
      } catch (e, stack) {
        debugPrint("❌ Sign in failed: $e\n$stack");
        if (context.mounted) {
          final message = _friendlyErrorMessage(e).trim();

          if (message.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                content: Text(message),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          ;
        }
      }
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ]
                : [
              Colors.grey[50]!,
              Colors.grey[100]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7E57C2), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Welcome Text
                  const Text(
                    'Welcome to Mentor AI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7E57C2),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Sign in to continue your learning journey',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Sign-in Options Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Sign In With',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[800],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Google Sign-in Button
                        SignInButton(
                          text: 'Continue with Google',
                          color: Colors.white,
                          textColor: Colors.grey[800],
                          icon: FontAwesomeIcons.google,
                          iconColor: Colors.black,
                          onPressed: () => _handleLogin(authProvider.signInWithGoogle),
                        ),

                        const SizedBox(height: 16),

                        // Apple Sign-in Button
                        SignInButton(
                          text: 'Continue with Apple',
                          color: Colors.black,
                          textColor: Colors.white,
                          icon: FontAwesomeIcons.apple,
                          iconColor: Colors.white,
                          onPressed: () => _handleLogin(authProvider.signInWithApple),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer Text
                  Text(
                    'By signing in, you agree to our Terms of Service\nand Privacy Policy',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}