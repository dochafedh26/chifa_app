import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VidalIndicationItem {
  final String title;
  final String url;

  VidalIndicationItem({required this.title, required this.url});

  factory VidalIndicationItem.fromJson(Map<String, dynamic> json) {
    return VidalIndicationItem(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class VidalMedicationItem {
  final String name;
  final String url;

  VidalMedicationItem({required this.name, required this.url});

  factory VidalMedicationItem.fromJson(Map<String, dynamic> json) {
    return VidalMedicationItem(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class VidalIndicationSearchResult {
  final String status;
  final String query;
  final String? selectedIndication;
  final List<VidalIndicationItem> indications;
  final List<VidalMedicationItem> medications;

  VidalIndicationSearchResult({
    required this.status,
    required this.query,
    this.selectedIndication,
    required this.indications,
    required this.medications,
  });

  factory VidalIndicationSearchResult.fromJson(Map<String, dynamic> json) {
    final inds = (json['indications'] as List? ?? [])
        .map((e) => VidalIndicationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final meds = (json['medications'] as List? ?? [])
        .map((e) => VidalMedicationItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return VidalIndicationSearchResult(
      status: json['status'] ?? 'error',
      query: json['query'] ?? '',
      selectedIndication: json['selected_indication'],
      indications: inds,
      medications: meds,
    );
  }
}

class VidalIndicationService {
  static final VidalIndicationService instance = VidalIndicationService._internal();
  VidalIndicationService._internal();

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&eacute;', 'é')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&ecirc;', 'ê')
        .replaceAll('&agrave;', 'à')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanMedName(String text) {
    return text
        .replaceFirst(
          RegExp(r'^(?:#\s*)?(?:M[ée\?a-zA-Z]*dicament|Reco)\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  Future<List<VidalIndicationItem>> _scrapeIndicationsHttp(String query) async {
    if (kIsWeb) return [];
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse('https://www.vidal.fr/medicaments/indication.html?q=$encoded');
    try {
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final linkRegex = RegExp(
        r'''<a\b[^>]*href=["']([^"']*indication-[^"']*)["'][^>]*>([\s\S]*?)<\/a>''',
        caseSensitive: false,
      );
      final seen = <String>{};
      final items = <VidalIndicationItem>[];
      for (final match in linkRegex.allMatches(body)) {
        final href = (match.group(1) ?? '').trim();
        final title = _stripHtml(match.group(2) ?? '');
        if (href.isNotEmpty && title.isNotEmpty) {
          final fullUrl = href.startsWith('http')
              ? href
              : 'https://www.vidal.fr/${href.replaceFirst(RegExp(r'^/+'), '')}';
          final key = '$title|$fullUrl';
          if (seen.add(key)) {
            items.add(VidalIndicationItem(title: title, url: fullUrl));
          }
        }
      }
      return items;
    } catch (e) {
      debugPrint('[_scrapeIndicationsHttp] error: $e');
      return [];
    }
  }

  Future<List<VidalMedicationItem>> _scrapeMedicationsHttp(String indUrl) async {
    if (kIsWeb || indUrl.isEmpty) return [];
    var targetUrl = indUrl;
    if (!targetUrl.contains('tab=list_spe')) {
      final delim = targetUrl.contains('?') ? '&' : '?';
      targetUrl = '$targetUrl${delim}market_statuses_not=supprimesansinfo&tab=list_spe';
    }
    try {
      final res = await http
          .get(Uri.parse(targetUrl), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      const ignoredKeywords = [
        'indication',
        'recherche',
        'substance',
        'gamme',
        'param',
        'login',
        'auth',
        'deconnexion',
        'laboratoire',
        'utiliser',
        'par-nom',
        'maladies',
        'utilisation',
      ];
      const fallbackSidebarNames = {
        'MERONEM 1 g pdre p sol inj/p perf',
        'MEROPENEM ARROW 1 g pdre p sol inj/p perf',
        'FORTUM 1 g pdre p sol inj/p perf IM IV',
        'MEROPENEM ACS DOBFAR 1 g pdre p sol inj/p perf',
        'RIFADINE 2 pour cent susp buv',
        'DEXAMETHASONE KRKA 4 mg ml sol inj p perf',
        'ROCEPHINE 1 g/10 ml pdre/solv p sol inj IV',
        'ISOPTINE 5 mg/2 ml sol inj',
      };
      final linkRegex = RegExp(
        r'''<a\b[^>]*href=["']([^"']*medicaments\/[^"']*\.html[^"']*)["'][^>]*>([\s\S]*?)<\/a>''',
        caseSensitive: false,
      );
      final seen = <String>{};
      final meds = <VidalMedicationItem>[];
      for (final match in linkRegex.allMatches(body)) {
        final href = (match.group(1) ?? '').trim();
        final rawText = _stripHtml(match.group(2) ?? '');
        if (href.isEmpty || rawText.isEmpty) continue;
        if (ignoredKeywords.any((k) => href.toLowerCase().contains(k))) continue;
        final name = _cleanMedName(rawText);
        if (name.length > 2 &&
            !name.contains('Bien utiliser') &&
            !fallbackSidebarNames.contains(name) &&
            seen.add(name)) {
          final fullUrl = href.startsWith('http')
              ? href
              : 'https://www.vidal.fr/${href.replaceFirst(RegExp(r'^/+'), '')}';
          meds.add(VidalMedicationItem(name: name, url: fullUrl));
        }
      }
      return meds;
    } catch (e) {
      debugPrint('[_scrapeMedicationsHttp] error: $e');
      return [];
    }
  }

  /// Searches VIDAL for indications by query string
  Future<VidalIndicationSearchResult?> searchByIndication(String query) async {
    // 1. Native Dart HTTP scraping first (works on Android, iOS, Windows, macOS, Linux)
    final indications = await _scrapeIndicationsHttp(query);
    if (indications.isNotEmpty) {
      final firstInd = indications.first;
      final meds = await _scrapeMedicationsHttp(firstInd.url);
      return VidalIndicationSearchResult(
        status: 'success',
        query: query,
        selectedIndication: firstInd.title,
        indications: indications,
        medications: meds,
      );
    }

    // 2. Desktop Python script fallback if available
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        const scriptPath = 'scripts/search_vidal_indication.py';
        if (await File(scriptPath).exists()) {
          final result = await Process.run('python', [scriptPath, query]);
          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            if (output.isNotEmpty) {
              final jsonMap = json.decode(output) as Map<String, dynamic>;
              return VidalIndicationSearchResult.fromJson(jsonMap);
            }
          }
        }
      } catch (e) {
        debugPrint('Exception in VidalIndicationService.searchByIndication: $e');
      }
    }
    return null;
  }

  /// Fetches medications for a specific indication URL
  Future<List<VidalMedicationItem>> fetchMedicationsForUrl(
    String query,
    String indicationUrl,
  ) async {
    if (indicationUrl.isEmpty) return [];
    final httpMeds = await _scrapeMedicationsHttp(indicationUrl);
    if (httpMeds.isNotEmpty) return httpMeds;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        const scriptPath = 'scripts/search_vidal_indication.py';
        if (await File(scriptPath).exists()) {
          final result = await Process.run('python', [scriptPath, query, indicationUrl]);
          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            if (output.isNotEmpty) {
              final jsonMap = json.decode(output) as Map<String, dynamic>;
              return (jsonMap['medications'] as List? ?? [])
                  .map((e) => VidalMedicationItem.fromJson(e as Map<String, dynamic>))
                  .toList();
            }
          }
        }
      } catch (e) {
        debugPrint('Exception in VidalIndicationService.fetchMedicationsForUrl: $e');
      }
    }
    return [];
  }
}
