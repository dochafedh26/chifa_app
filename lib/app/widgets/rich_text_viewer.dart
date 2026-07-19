import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class RichTextViewer extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;

  const RichTextViewer({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if it looks like JSON
    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) || 
        (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
      try {
        final decoded = jsonDecode(trimmed);
        final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);
        final doc = quill.Document.fromJson(ops);
        final controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );

        return IgnorePointer(
          child: quill.QuillEditor.basic(
            controller: controller,
            config: const quill.QuillEditorConfig(
              scrollable: false,
              expands: false,
            ),
          ),
        );
      } catch (_) {
        // Fallback to plain text on any JSON/Quill error
      }
    }

    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  /// Utility function to convert rich text to plain text (e.g. for simple views or exports)
  static String toPlainText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) || 
        (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
      try {
        final decoded = jsonDecode(trimmed);
        final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);
        final doc = quill.Document.fromJson(ops);
        return doc.toPlainText().trim();
      } catch (_) {
        // Fallback
      }
    }
    return text;
  }
}
