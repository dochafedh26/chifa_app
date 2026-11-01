import 'package:flutter/material.dart';

/// Centralized responsive extension and utilities for Chifa application.
/// Ensures seamless adaptation across mobile phones (Portrait & Landscape),
/// tablets, and desktop workstations.
extension ResponsiveContext on BuildContext {
  /// Standard screen size
  Size get screenSize => MediaQuery.of(this).size;

  /// Width in logical pixels
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Height in logical pixels
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Shortest side in logical pixels.
  /// Flutter standard: shortestSide < 600 indicates a phone (regardless of orientation).
  double get shortestSide => MediaQuery.of(this).size.shortestSide;

  /// Orientation
  Orientation get orientation => MediaQuery.of(this).orientation;

  /// Whether the device is currently in landscape orientation
  bool get isLandscape => orientation == Orientation.landscape;

  /// Whether the device is currently in portrait orientation
  bool get isPortrait => orientation == Orientation.portrait;

  /// True if the device is a mobile phone (or window resized below 800px).
  /// Guarantees that phones in landscape mode (which often have width 800-950px
  /// but shortestSide < 600px) are properly identified as mobile devices.
  bool get isMobile => shortestSide < 600 || screenWidth < 800;

  /// Specific to phones held horizontally (height ~360-450px)
  bool get isPhoneLandscape => shortestSide < 600 && isLandscape;

  /// Specific to phones held vertically (width ~360-450px)
  bool get isPhonePortrait => shortestSide < 600 && isPortrait;

  /// True if screen is a tablet or medium screen
  bool get isTablet => shortestSide >= 600 && screenWidth < 1200;

  /// True for large desktop monitors (width >= 1200)
  bool get isDesktop => shortestSide >= 600 && screenWidth >= 1200;
}

