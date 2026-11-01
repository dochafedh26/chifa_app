import 'dart:convert';
import 'dart:io';

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

  /// Searches VIDAL for indications by query string
  Future<VidalIndicationSearchResult?> searchByIndication(String query) async {
    try {
      final scriptPath = 'scripts/search_vidal_indication.py';
      final result = await Process.run('python', [scriptPath, query]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final jsonMap = json.decode(output) as Map<String, dynamic>;
          return VidalIndicationSearchResult.fromJson(jsonMap);
        }
      } else {
        print('search_vidal_indication.py failed with exit code ${result.exitCode}: ${result.stderr}');
      }
    } catch (e) {
      print('Exception in VidalIndicationService.searchByIndication: $e');
    }
    return null;
  }

  /// Fetches medications for a specific indication URL
  Future<List<VidalMedicationItem>> fetchMedicationsForUrl(String query, String indicationUrl) async {
    try {
      final scriptPath = 'scripts/search_vidal_indication.py';
      final result = await Process.run('python', [scriptPath, query, indicationUrl]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final jsonMap = json.decode(output) as Map<String, dynamic>;
          final meds = (jsonMap['medications'] as List? ?? [])
              .map((e) => VidalMedicationItem.fromJson(e as Map<String, dynamic>))
              .toList();
          return meds;
        }
      }
    } catch (e) {
      print('Exception in VidalIndicationService.fetchMedicationsForUrl: $e');
    }
    return [];
  }
}
