import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PosologyScraperService {
  static final PosologyScraperService instance = PosologyScraperService._internal();
  PosologyScraperService._internal();

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  String _cleanMedicName(String name) {
    var cleaned = name
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '');
    cleaned = cleaned.split(RegExp(r'\d')).first.trim();
    cleaned = cleaned
        .split(
          RegExp(
            r'\b(CP|GEL|GELULE|SACHET|AMPOULE|FLACON|PDRE|LYOPH|INJ|SUSPENSION|SOL|SOLUT|SIROP|COMP|COMPRIME)\b',
            caseSensitive: false,
          ),
        )
        .first
        .trim();
    return cleaned;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|li|div|tr)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&eacute;', 'é')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&ecirc;', 'ê')
        .replaceAll('&agrave;', 'à')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
  }

  String? _extractFormula(String text) {
    final pat1 = RegExp(
      r'(\d+)\s*(?:-|à|ou)\s*(\d+)\s*(?:mg par kg|mg\s*/\s*kg)',
      caseSensitive: false,
    ).firstMatch(text);
    if (pat1 != null) {
      return '${pat1.group(1)}-${pat1.group(2)}mg/kg';
    }
    final pat2 = RegExp(
      r'(\d+)\s*(?:mg par kg|mg\s*/\s*kg)',
      caseSensitive: false,
    ).firstMatch(text);
    if (pat2 != null) {
      return '${pat2.group(1)}mg/kg';
    }
    return null;
  }

  Map<String, String> _splitPosology(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return {'adulte': '', 'pediatrique': ''};
    }
    final lines = trimmed.split('\n');
    int splitIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      final cleanLine = lines[i].trim().toLowerCase();
      if ((cleanLine.startsWith('enfant') ||
              cleanLine.startsWith('nourrisson') ||
              cleanLine.contains('enfant :') ||
              cleanLine.contains('nourrisson :')) &&
          !cleanLine.contains('adulte et')) {
        splitIdx = i;
        break;
      }
    }
    if (splitIdx != -1) {
      final adult = lines.sublist(0, splitIdx).join('\n').trim();
      final pediatric = lines.sublist(splitIdx).join('\n').trim();
      return {
        'adulte': adult.isEmpty ? trimmed : adult,
        'pediatrique': pediatric,
      };
    }
    return {'adulte': trimmed, 'pediatrique': trimmed};
  }

  Future<Map<String, dynamic>?> _scrapePosologyHttp(String medicName) async {
    if (kIsWeb) return null;
    final brand = _cleanMedicName(medicName);
    if (brand.isEmpty) return null;

    final firstChar = brand[0].toLowerCase();
    final letter = RegExp(r'^\d$').hasMatch(firstChar)
        ? '0-9'
        : (RegExp(r'^[a-z]$').hasMatch(firstChar) ? firstChar : null);
    if (letter == null) return null;

    final indexUrl = Uri.parse('https://www.vidal.fr/medicaments/gammes/liste-$letter.html');
    try {
      final res = await http.get(indexUrl, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final target = brand.toLowerCase();
      final linkRegex = RegExp(
        r'''<a\b[^>]*href=["']([^"']*gamme[^"']*)["'][^>]*>([\s\S]*?)<\/a>''',
        caseSensitive: false,
      );

      final candidateHrefs = <String>[];
      for (final m in linkRegex.allMatches(body)) {
        final href = (m.group(1) ?? '').trim();
        final text = _stripHtml(m.group(2) ?? '').toLowerCase();
        if (href.contains('liste-') || text.length <= 1) continue;
        if (text == target && !candidateHrefs.contains(href)) {
          candidateHrefs.add(href);
        }
      }
      for (final m in linkRegex.allMatches(body)) {
        final href = (m.group(1) ?? '').trim();
        final text = _stripHtml(m.group(2) ?? '').toLowerCase();
        if (href.contains('liste-') || text.length <= 1) continue;
        if ((text.startsWith(target) || target.startsWith(text)) &&
            !candidateHrefs.contains(href)) {
          candidateHrefs.add(href);
        }
      }

      for (final href in candidateHrefs.take(4)) {
        final detailUrl = href.startsWith('http')
            ? href
            : 'https://www.vidal.fr/${href.replaceFirst(RegExp(r'^/+'), '')}';
        try {
          final rd = await http
              .get(Uri.parse(detailUrl), headers: _headers)
              .timeout(const Duration(seconds: 12));
          if (rd.statusCode != 200) continue;
          final dbody = utf8.decode(rd.bodyBytes, allowMalformed: true);
          final posoMatch = RegExp(
            r'<h[234][^>]*>[^<]*posologie[^<]*</h[234]>([\s\S]*?)(?=<h[234]\b|$)',
            caseSensitive: false,
          ).firstMatch(dbody);
          if (posoMatch != null) {
            final sectionText = _stripHtml(posoMatch.group(1) ?? '');
            if (sectionText.isNotEmpty) {
              final split = _splitPosology(sectionText);
              final formula = _extractFormula(sectionText);
              return {
                'status': 'success',
                'posologie_adulte': split['adulte'],
                'posologie_pediatrique': split['pediatrique'],
                'posologie': formula,
                'source_url': detailUrl,
              };
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[_scrapePosologyHttp] error: $e');
    }
    return null;
  }

  /// Scrapes posology data for a medic name or ID.
  /// Returns a map with 'status', 'posologie_adulte', 'posologie_pediatrique', and 'posologie' (weight-based formula if extracted).
  Future<Map<String, dynamic>?> scrapePosology(String medicNameOrId) async {
    // 1. Native Dart HTTP scraping first (works on Android, iOS, Windows, macOS, Linux)
    final httpResult = await _scrapePosologyHttp(medicNameOrId);
    if (httpResult != null && httpResult['status'] == 'success') {
      return httpResult;
    }

    // 2. Desktop Python script fallback if available
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        const scriptPath = 'scripts/scrape_vidal.py';
        if (await File(scriptPath).exists()) {
          final result = await Process.run('python', [scriptPath, medicNameOrId]);
          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            if (output.isNotEmpty) {
              return json.decode(output) as Map<String, dynamic>;
            }
          }
        }
      } catch (e) {
        debugPrint('Exception while running posology scraper: $e');
      }
    }
    return null;
  }
}
