import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Parses a Quill Delta JSON string and returns a list of pdf widgets
/// representing the formatted text. Falls back to plain text line splitting
/// if the input is not valid Quill JSON.
List<pw.Widget> parseDeltaToPdfWidgets({
  required String text,
  required pw.TextStyle baseStyle,
  required pw.Font boldFont,
  required pw.Font regularFont,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return [];

  // Check if it's JSON
  if ((trimmed.startsWith('[') && trimmed.endsWith(']')) || 
      (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
    try {
      final decoded = jsonDecode(trimmed);
      final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);
      
      final List<pw.Widget> widgets = [];
      List<pw.TextSpan> currentSpans = [];

      for (final op in ops) {
        final insertVal = op['insert'];
        if (insertVal is! String) continue; // skip embeds like images/videos
        
        final Map<String, dynamic>? attrs = op['attributes'] != null 
            ? Map<String, dynamic>.from(op['attributes']) 
            : null;

        // Split the insert by newlines while preserving them
        final List<String> lines = insertVal.split('\n');
        
        for (int i = 0; i < lines.length; i++) {
          final lineText = lines[i];
          
          if (lineText.isNotEmpty) {
            // Apply formatting attributes to TextStyle
            pw.Font font = regularFont;
            pw.FontWeight fontWeight = pw.FontWeight.normal;
            pw.FontStyle fontStyle = pw.FontStyle.normal;
            pw.TextDecoration decoration = pw.TextDecoration.none;
            PdfColor color = baseStyle.color ?? PdfColors.black;

            if (attrs != null) {
              if (attrs['bold'] == true) {
                font = boldFont;
                fontWeight = pw.FontWeight.bold;
              }
              if (attrs['italic'] == true) {
                fontStyle = pw.FontStyle.italic;
              }
              if (attrs['underline'] == true) {
                decoration = pw.TextDecoration.underline;
              }
              if (attrs['color'] != null) {
                try {
                  final colorHex = attrs['color'] as String;
                  color = PdfColor.fromHex(colorHex);
                } catch (_) {}
              }
            }

            currentSpans.add(
              pw.TextSpan(
                text: lineText,
                style: pw.TextStyle(
                  font: font,
                  fontWeight: fontWeight,
                  fontStyle: fontStyle,
                  decoration: decoration,
                  color: color,
                  fontSize: baseStyle.fontSize,
                  lineSpacing: baseStyle.lineSpacing,
                ),
              ),
            );
          }

          // If this is not the last line segment, it means we hit a '\n' and must yield a paragraph
          if (i < lines.length - 1) {
            if (currentSpans.isNotEmpty) {
              widgets.add(pw.RichText(text: pw.TextSpan(children: currentSpans)));
              currentSpans = [];
            } else {
              // Empty line/paragraph break
              widgets.add(pw.SizedBox(height: 6));
            }
          }
        }
      }

      // Add any remaining spans
      if (currentSpans.isNotEmpty) {
        widgets.add(pw.RichText(text: pw.TextSpan(children: currentSpans)));
      }

      return widgets;
    } catch (_) {
      // fallback to plain text if JSON is corrupted
    }
  }

  // Fallback to splitting by newline for plain text
  return trimmed
      .split('\n')
      .map((line) => pw.Text(
            line,
            style: baseStyle,
          ))
      .toList();
}
