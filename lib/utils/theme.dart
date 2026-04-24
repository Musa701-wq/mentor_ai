import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors from the Profile header gradient
  static const Color primaryColor = Color(0xFF6A1B9A); // Rich purple
  static const Color secondaryColor = Color(0xFFF5F5F5); // Light grey/white background
  
  // Custom colors used in the provided screen code
  static const Color tilescolor = Colors.white;
  static const Color stokecolor = Color(0xFFEEEEEE); // Light stroke/border
  
  // AppBar configuration
  static double appBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top + kToolbarHeight;
  }
  
  static TextStyle appBarTitleStyle(BuildContext context) {
    return const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: primaryColor,
    );
  }
  
  // Gradient for background (optional, can be used to match Profile)
  static LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      secondaryColor,
      Colors.white,
    ],
  );
}
