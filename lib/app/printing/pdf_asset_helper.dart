import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Centralized helper to reliably load PDF templates, background images, and fonts
/// across all Flutter build modes (Debug, Profile, Release, Inno Setup installs).
class PdfAssetHelper {
  PdfAssetHelper._();

  /// Loads asset bytes using Flutter rootBundle, with graceful fallback to disk
  static Future<Uint8List> loadBytes(String assetPath) async {
    // 1. Primary: Flutter rootBundle (standard in all Flutter platforms and build modes)
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } catch (_) {
      // Try next fallbacks
    }

    // 2. Secondary: If assetPath has leading slash or different prefix
    final cleanPath = assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
    try {
      final byteData = await rootBundle.load(cleanPath);
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } catch (_) {
      // Try next fallbacks
    }

    // 3. Fallbacks: Inspect adjacent executable and working directory (Desktop only)
    final candidates = <String>[];

    if (!kIsWeb) {
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        candidates.add('$exeDir/data/flutter_assets/$cleanPath');
        candidates.add('$exeDir/$cleanPath');
      } catch (_) {}

      try {
        final currentDir = Directory.current.path;
        candidates.add('$currentDir/$cleanPath');
        candidates.add('$currentDir/data/flutter_assets/$cleanPath');
      } catch (_) {}
    }

    candidates.add(cleanPath);

    for (final path in candidates) {
      try {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (_) {}
    }

    throw Exception('Template asset not found: $assetPath');
  }

  /// Loads a TrueType font for PDF generation
  static Future<pw.Font> loadFont(String assetPath) async {
    final bytes = await loadBytes(assetPath);
    return pw.Font.ttf(bytes.buffer.asByteData());
  }

  /// Loads the default Bold font (Bricolage Grotesque)
  static Future<pw.Font> loadBoldFont() async {
    return loadFont('assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Bold.ttf');
  }

  /// Loads the default Regular font (Bricolage Grotesque)
  static Future<pw.Font> loadRegularFont() async {
    return loadFont('assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Regular.ttf');
  }
}

