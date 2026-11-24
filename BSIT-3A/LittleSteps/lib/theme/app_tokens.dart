import 'package:flutter/material.dart';

/// Color palette tokens for the application.
abstract final class AppColors {
  /// Primary forest green brand color.
  static const forest = Color(0xFF1F634D);

  /// Dark forest accent used for artwork and branding illustrations.
  static const artworkForest = Color(0xFF286B58);

  /// Warm cream background tint.
  static const cream = Color(0xFFF4F2E8);

  /// Soft sage accent color.
  static const sage = Color(0xFF8DAF98);

  /// Warm orange accent color.
  static const orange = Color(0xFFEC6A2C);

  /// Warning and advisory accent color.
  static const warning = Color(0xFFEC6A2C);

  /// Card and container background surface.
  static const surfaceCard = Color(0xFFFFFFFF);

  /// Scaffold and page canvas background surface.
  static const surfaceCanvas = Color(0xFFF7F7ED);

  /// Light green surface for completed actions and positive indicators.
  static const softGreen = Color(0xFFE0F2E5);

  /// Yellow surface for advisory and informational notices.
  static const surfaceAdvisory = Color(0xFFFAE8A8);

  /// Surface background for offline notices.
  static const surfaceOffline = Color(0xFFF1F5F9);

  /// Light red surface for error banners and validation messages.
  static const surfaceError = Color(0xFFFFF6F5);

  /// Primary high-contrast text color.
  static const textPrimary = Color(0xFF1A2B29);

  /// Secondary text color for captions and metadata.
  static const textSecondary = Color(0xFF5A6A64);

  /// Muted text color for subtle labels and icons.
  static const textTertiary = Color(0xFF7E8C86);

  /// Text color for offline status indicators.
  static const textOffline = Color(0xFF475569);

  /// Text color for error messages and critical notices.
  static const textError = Color(0xFF853029);

  /// Border color for text fields, select inputs, and unselected chips.
  static const borderInput = Color(0xFF7E8C86);

  /// Subtle border color for cards and dividing lines.
  static const borderSubtle = Color(0xFFE0E5DB);

  /// Border color for advisory cards and banners.
  static const borderAdvisory = Color(0xFFD6C88D);

  /// Border color for error states.
  static const borderError = Color(0xFFB83D33);

  /// Focus outline color for interactive controls.
  static const focus = Color(0xFF1F634D);

  /// Critical error color.
  static const error = Color(0xFF853029);

  /// Info status background color for metadata and provenance badges.
  static const statusInfo = Color(0xFFD9E8F7);

  /// Caution status background color.
  static const statusCaution = Color(0xFFFAE8A8);

  /// Offline status indicator color.
  static const statusOffline = Color(0xFFF1F5F9);
}

/// Spacing scale constants based on an 8-point grid.
abstract final class AppSpacing {
  /// 4 dp spacing.
  static const double space4 = 4;

  /// 8 dp spacing.
  static const double space8 = 8;

  /// 12 dp spacing.
  static const double space12 = 12;

  /// 16 dp spacing.
  static const double space16 = 16;

  /// 20 dp spacing.
  static const double space20 = 20;

  /// 24 dp spacing.
  static const double space24 = 24;

  /// 32 dp spacing.
  static const double space32 = 32;
}

/// Corner radius values for controls, containers, and chips.
abstract final class AppRadius {
  /// Radius for buttons, text fields, and inputs.
  static const double control = 10;

  /// Radius for cards and dialogs.
  static const double card = 16;

  /// Radius for pill tags and chips.
  static const double chip = 20;
}

/// Layout and interactive dimension constants.
abstract final class AppSizes {
  /// Minimum recommended touch target size for interactive controls.
  static const double touchTarget = 48;

  /// Minimum touch target size for secondary links.
  static const double touchTargetSecondary = 44;

  /// Standard height of the top app bar.
  static const double topBarHeight = 60;

  /// Standard height of the bottom navigation bar.
  static const double bottomBarHeight = 72;

  /// Width of the extended desktop navigation sidebar.
  static const double sidebarWidth = 240;

  /// Maximum readable width for primary screen content columns.
  static const double contentMaxWidth = 760;

  /// Minimum viewport width that switches from bottom bar to side navigation.
  static const double wideLayoutBreakpoint = 840;
}

/// Animation durations and curve constants.
abstract final class AppMotion {
  /// Duration for quick interactive feedback like presses and hover states.
  static const Duration durationFast = Duration(milliseconds: 120);

  /// Duration for modal transitions and expanding views.
  static const Duration durationBase = Duration(milliseconds: 200);

  /// Standard ease-out animation curve.
  static const Curve easingStandard = Cubic(0.2, 0.0, 0.0, 1.0);
}
