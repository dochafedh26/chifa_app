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

  /// Utility function to convert rich text or Quill Delta JSON to clean plain text
  static String toPlainText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) || 
        (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
      try {
        final decoded = jsonDecode(trimmed);
        final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);

        final StringBuffer buffer = StringBuffer();
        int orderedCounter = 0;
        List<String> lineTextSegments = [];

        for (final op in ops) {
          if (op is! Map) continue;
          final insertVal = op['insert'];
          if (insertVal is! String) continue;

          final Map<String, dynamic> attrs = op['attributes'] != null 
              ? Map<String, dynamic>.from(op['attributes']) 
              : const {};

          final List<String> segments = insertVal.split('\n');

          for (int i = 0; i < segments.length; i++) {
            if (segments[i].isNotEmpty) {
              lineTextSegments.add(segments[i]);
            }

            if (i < segments.length - 1) {
              final listType = attrs['list'] as String?;
              String prefix = '';
              if (listType == 'bullet') {
                prefix = '• ';
                orderedCounter = 0;
              } else if (listType == 'ordered') {
                orderedCounter++;
                prefix = '$orderedCounter. ';
              } else {
                orderedCounter = 0;
              }

              buffer.write(prefix);
              buffer.write(lineTextSegments.join());
              buffer.writeln();
              lineTextSegments.clear();
            }
          }
        }

        if (lineTextSegments.isNotEmpty) {
          buffer.write(lineTextSegments.join());
        }

        return buffer.toString().trim();
      } catch (_) {
        // Fallback
      }
    }
    return text;
  }
}
