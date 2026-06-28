import 'package:flutter/material.dart';

/// Shared design tokens for the Car Dashboard app.
///
/// All color, spacing, and typography constants used across pages
/// are centralized here to ensure visual consistency.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Colors
  // ---------------------------------------------------------------------------

  /// Primary background — true dark.
  static const Color bgColor = Color(0xFF0A0A0A);

  /// Elevated surface cards.
  static const Color surfaceColor = Color(0xFF111111);

  /// Slightly lighter surface for nested elements.
  static const Color surfaceLight = Color(0xFF1A1A1A);

  /// Primary accent — neon cyan.
  static const Color accentCyan = Color(0xFF00E5FF);

  /// Secondary accent — deep blue.
  static const Color accentBlue = Color(0xFF0091EA);

  /// Alert / danger — vivid red.
  static const Color alertRed = Color(0xFFFF1744);

  /// Warning — amber.
  static const Color alertAmber = Color(0xFFFFAB00);

  /// Success — green.
  static const Color successGreen = Color(0xFF00E676);

  /// Primary text — white.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text — muted grey.
  static const Color textSecondary = Color(0xFF888888);

  /// Glassmorphism fill (~5% white).
  static const Color glassFill = Color(0x0DFFFFFF);

  /// Glassmorphism border (~10% white).
  static const Color glassBorder = Color(0x1AFFFFFF);

  // ---------------------------------------------------------------------------
  // Spacing
  // ---------------------------------------------------------------------------

  /// Standard page padding.
  static const double pagePadding = 20.0;

  /// Small gap between elements.
  static const double gapSmall = 8.0;

  /// Medium gap between elements.
  static const double gapMedium = 16.0;

  /// Large gap between sections.
  static const double gapLarge = 24.0;

  // ---------------------------------------------------------------------------
  // Border Radii
  // ---------------------------------------------------------------------------

  /// Card border radius.
  static const double radiusCard = 16.0;

  /// Button / pill border radius.
  static const double radiusPill = 24.0;

  /// Small element radius.
  static const double radiusSmall = 8.0;

  // ---------------------------------------------------------------------------
  // Bottom Dock
  // ---------------------------------------------------------------------------

  /// Height of the top Tesla-style status header.
  static const double headerHeight = 48.0;

  /// Height of the custom bottom navigation dock.
  static const double dockHeight = 56.0;
}
