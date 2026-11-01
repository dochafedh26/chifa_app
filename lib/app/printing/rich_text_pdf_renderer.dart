import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Parses a Quill Delta JSON string and returns a list of pdf widgets
/// representing the formatted text. Falls back to plain text line splitting
/// if the input is not valid Quill JSON.
class _TextSegment {
  final String text;
  final Map<String, dynamic> attributes;

  _TextSegment(this.text, this.attributes);
}

class _LineData {
  final List<_TextSegment> segments = [];
  final Map<String, dynamic> lineAttributes = {};
}

/// Parses rich text (Quill Delta JSON, HTML, or plain text with list markers)
/// and returns a list of PDF widgets representing the formatted text.
List<pw.Widget> parseDeltaToPdfWidgets({
  required String text,
  required pw.TextStyle baseStyle,
  required pw.Font boldFont,
  required pw.Font regularFont,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return [];

  List<_LineData> lines = [];

  // 1. Try parsing as Quill Delta JSON
  if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
      (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
    try {
      final decoded = jsonDecode(trimmed);
      final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);
      lines = _parseOpsToLines(ops);
    } catch (_) {
      try {
        final normalized = trimmed.replaceAll("'", '"');
        final decoded = jsonDecode(normalized);
        final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);
        lines = _parseOpsToLines(ops);
      } catch (_) {
        lines = [];
      }
    }
  }

  // 2. Try parsing as HTML if JSON parsing didn't produce lines and input contains HTML tags
  if (lines.isEmpty && trimmed.contains('<') && trimmed.contains('>')) {
    lines = _parseHtmlToLines(trimmed);
  }

  // 3. Fallback to Plain Text with list marker auto-detection
  if (lines.isEmpty) {
    lines = _parsePlainTextToLines(trimmed);
  }

  return _renderLinesToWidgets(
    lines: lines,
    baseStyle: baseStyle,
    boldFont: boldFont,
    regularFont: regularFont,
  );
}

List<_LineData> _parseOpsToLines(List<dynamic> ops) {
  final List<_LineData> lines = [];
  _LineData currentLine = _LineData();

  for (final op in ops) {
    if (op is! Map) continue;
    final insertVal = op['insert'];
    if (insertVal is! String) continue; // Skip non-text embeds

    final Map<String, dynamic> attrs = op['attributes'] != null
        ? Map<String, dynamic>.from(op['attributes'])
        : const {};

    final String textStr = insertVal;
    final List<String> segments = textStr.split('\n');

    for (int i = 0; i < segments.length; i++) {
      final segmentText = segments[i];

      if (segmentText.isNotEmpty) {
        currentLine.segments.add(_TextSegment(segmentText, attrs));
      }

      if (i < segments.length - 1) {
        // Line ends at '\n'. Attach block attributes (list, header, align, indent) to currentLine
        currentLine.lineAttributes.addAll(attrs);
        lines.add(currentLine);
        currentLine = _LineData();
      }
    }
  }

  if (currentLine.segments.isNotEmpty || currentLine.lineAttributes.isNotEmpty) {
    lines.add(currentLine);
  }

  return lines;
}

List<_LineData> _parseHtmlToLines(String htmlStr) {
  final List<_LineData> lines = [];

  String processed = htmlStr
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</h1>|</h2>|Follow|</h3>|Standard|</h4>|</h5>|</h6>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

  bool inUl = false;
  bool inOl = false;

  final rawLines = processed.split('\n');
  for (final rawLine in rawLines) {
    final clean = rawLine.trim();
    if (clean.isEmpty) continue;

    final lower = clean.toLowerCase();
    if (lower.contains('<ul')) inUl = true;
    if (lower.contains('</ul')) inUl = false;
    if (lower.contains('<ol')) inOl = true;
    if (lower.contains('</ol')) inOl = false;

    final line = _LineData();
    if (inUl || lower.contains('<li')) {
      line.lineAttributes['list'] = 'bullet';
    } else if (inOl) {
      line.lineAttributes['list'] = 'ordered';
    }

    bool isBold = lower.contains('<b>') || lower.contains('<strong>');
    bool isItalic = lower.contains('<i>') || lower.contains('<em>');
    bool isUnderline = lower.contains('<u>');

    final textOnly = clean.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (textOnly.isNotEmpty) {
      line.segments.add(_TextSegment(textOnly, {
        if (isBold) 'bold': true,
        if (isItalic) 'italic': true,
        if (isUnderline) 'underline': true,
      }));
      lines.add(line);
    }
  }

  return lines;
}

List<_LineData> _parsePlainTextToLines(String text) {
  final List<_LineData> lines = [];
  final rawLines = text.split('\n');

  for (final rawLine in rawLines) {
    final line = _LineData();
    String trimmedLine = rawLine.trim();

    if (trimmedLine.isEmpty) {
      lines.add(line);
      continue;
    }

    // Check bullet marker
    final bulletMatch = RegExp(r'^[\-\*•]\s+').firstMatch(trimmedLine);
    if (bulletMatch != null) {
      line.lineAttributes['list'] = 'bullet';
      trimmedLine = trimmedLine.substring(bulletMatch.end);
    } else {
      // Check ordered list marker
      final orderedMatch = RegExp(r'^\d+[\.\)\-]\s+').firstMatch(trimmedLine);
      if (orderedMatch != null) {
        line.lineAttributes['list'] = 'ordered';
        trimmedLine = trimmedLine.substring(orderedMatch.end);
      }
    }

    line.segments.add(_TextSegment(trimmedLine, const {}));
    lines.add(line);
  }

  return lines;
}

List<pw.Widget> _renderLinesToWidgets({
  required List<_LineData> lines,
  required pw.TextStyle baseStyle,
  required pw.Font boldFont,
  required pw.Font regularFont,
}) {
  final List<pw.Widget> widgets = [];
  int orderedListCounter = 0;

  for (final line in lines) {
    final listType = line.lineAttributes['list'] as String?;
    final headerLevel = line.lineAttributes['header'] as int?;
    final alignStr = line.lineAttributes['align'] as String?;
    final indentLevel = (line.lineAttributes['indent'] as num?)?.toInt() ?? 0;

    if (listType == 'ordered') {
      orderedListCounter++;
    } else {
      orderedListCounter = 0;
    }

    if (line.segments.isEmpty) {
      widgets.add(pw.SizedBox(height: (baseStyle.fontSize ?? 10) * 0.6));
      continue;
    }

    pw.TextAlign align = pw.TextAlign.left;
    if (alignStr == 'center') {
      align = pw.TextAlign.center;
    } else if (alignStr == 'right') {
      align = pw.TextAlign.right;
    } else if (alignStr == 'justify') {
      align = pw.TextAlign.justify;
    }

    final List<pw.InlineSpan> spans = [];
    for (final seg in line.segments) {
      final attrs = seg.attributes;

      final isBold = attrs['bold'] == true || (headerLevel != null && headerLevel > 0);
      final isItalic = attrs['italic'] == true;
      final isUnderline = attrs['underline'] == true;
      final isStrike = attrs['strike'] == true;

      pw.Font font = isBold ? boldFont : regularFont;
      pw.FontWeight fontWeight = isBold ? pw.FontWeight.bold : pw.FontWeight.normal;
      pw.FontStyle fontStyle = isItalic ? pw.FontStyle.italic : pw.FontStyle.normal;

      pw.TextDecoration decoration = pw.TextDecoration.none;
      if (isUnderline && isStrike) {
        decoration = pw.TextDecoration.combine([pw.TextDecoration.underline, pw.TextDecoration.lineThrough]);
      } else if (isUnderline) {
        decoration = pw.TextDecoration.underline;
      } else if (isStrike) {
        decoration = pw.TextDecoration.lineThrough;
      }

      PdfColor color = baseStyle.color ?? PdfColors.black;
      if (attrs['color'] != null) {
        try {
          final hex = attrs['color'].toString();
          color = PdfColor.fromHex(hex);
        } catch (_) {}
      }

      PdfColor? bgColor;
      if (attrs['background'] != null) {
        try {
          final hex = attrs['background'].toString();
          bgColor = PdfColor.fromHex(hex);
        } catch (_) {}
      }

      double fontSize = baseStyle.fontSize ?? 10;
      if (headerLevel == 1) {
        fontSize *= 1.6;
      } else if (headerLevel == 2) {
        fontSize *= 1.35;
      } else if (headerLevel == 3) {
        fontSize *= 1.15;
      }

      spans.add(
        pw.TextSpan(
          text: seg.text,
          style: pw.TextStyle(
            font: font,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            color: color,
            background: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
            fontSize: fontSize,
            lineSpacing: baseStyle.lineSpacing,
          ),
        ),
      );
    }

    String prefix = '';
    if (listType == 'bullet') {
      prefix = '•';
    } else if (listType == 'ordered') {
      prefix = '$orderedListCounter.';
    } else if (listType == 'checked') {
      prefix = '[X]';
    } else if (listType == 'unchecked') {
      prefix = '[ ]';
    }

    final double leftPadding = indentLevel * 14.0;

    if (prefix.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: leftPadding, top: 1.5, bottom: 1.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: listType == 'ordered' ? (orderedListCounter > 9 ? 22 : 16) : 14,
                child: pw.Text(
                  prefix,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: baseStyle.fontSize ?? 10,
                    color: baseStyle.color ?? PdfColors.black,
                  ),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(children: spans),
                  textAlign: align,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: leftPadding, top: 1, bottom: 1),
          child: pw.RichText(
            text: pw.TextSpan(children: spans),
            textAlign: align,
          ),
        ),
      );
    }
  }

  return widgets;
}
