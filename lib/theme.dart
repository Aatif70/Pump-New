import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {

  // Can add petrol pump styled color themes as well
  // Primary Colors
  static const Color primaryBlue = Color(0xFF1D3557);   // Dark blue replacing red
  static const Color primaryYellow = Color(0xFFFFD700);  // Petrol pump yellow
  static const Color primaryOrange = Color(0xFFF9A826); // Orange from the logo

  static const Color primaryBlack = Color(0xFF1A1A1A);   // Deep black
  static const Color secondaryGray = Color(0xFF4A4A4A);  // Dark gray
  static const Color backgroundColor = Colors.white;



  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color textLight = Color(0xFFFFFFFF);

  // App Bar Theme - For consistent styling across the app
  static final AppBarTheme appBarTheme = AppBarTheme(
    backgroundColor: primaryBlue,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white), // Back button and menu icon color
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: textLight,
    ),
  );


  // Button Styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: textLight,
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryOrange,
    foregroundColor: textPrimary,
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );


  // Text Styles
  static final TextStyle headingStyle = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );


  static final TextStyle subheadingStyle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static final TextStyle bodyStyle = GoogleFonts.poppins(
    fontSize: 14,
    color: textSecondary,
  );

  // Input Decoration
  static InputDecoration inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: secondaryGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: secondaryGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      labelStyle: bodyStyle,
      hintStyle: bodyStyle.copyWith(color: Colors.grey),
    );
  }
} 