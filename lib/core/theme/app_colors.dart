import 'package:flutter/material.dart';

/// AppColors defines the color palette for the Study Library App.
class AppColors {
  AppColors._(); // Private constructor

  // Base Light Theme Colors
  static const Color primaryLight = Color(0xFF5D4037); // Deep Brown
  static const Color accentLight = Color(0xFFFF8F00); // Amber
  static const Color backgroundLight = Color(0xFFFFF8E1); // Cream
  static const Color surfaceLight = Colors.white;

  // Base Dark Theme Colors
  static const Color primaryDark = Color(0xFFFFB74D); // Warm Amber (high contrast against dark surface)
  static const Color accentDark = Color(0xFFFFCA28); // Light Amber
  static const Color backgroundDark = Color(0xFF121212); // Dark background
  static const Color surfaceDark = Color(0xFF1E1E1E); // Dark surface

  // Shared semantic colors
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  // Seat Status Colors
  static const Color seatAvailable = Color(0xFF4CAF50); // Green
  static const Color seatOccupied = Color(0xFFF44336); // Red
  static const Color seatReserved = Color(0xFFFFEB3B); // Yellow
  static const Color seatMaintenance = Color(0xFF9E9E9E); // Grey

  // Gender Colors
  static const Color genderMale = Color(0xFFE3F2FD); // Blue tint
  static const Color genderFemale = Color(0xFFFCE4EC); // Pink tint
  static const Color genderAny = Color(0xFFF5F5F5); // Neutral

  // Membership Status Colors
  static const Color membershipActive = Color(0xFF4CAF50); // Green
  static const Color membershipExpired = Color(0xFFF44336); // Red
  static const Color membershipGrace = Color(0xFFFF9800); // Orange
  static const Color membershipPending = Color(0xFFFFEB3B); // Yellow
  static const Color membershipArchived = Color(0xFF9E9E9E); // Grey
}
