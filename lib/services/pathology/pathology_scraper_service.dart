import 'dart:convert';
import 'dart:io';
import '../ai/ai_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PathologyScraperService {
  static final PathologyScraperService instance =
      PathologyScraperService._internal();
  PathologyScraperService._internal();

  Future<Map<String, dynamic>?> scrapePathology(String pathologyName) async {
    try {
      if (AiService.instance.isAiActive()) {
        print('Generating pathology guide via AI-First Medical Assistant...');

        // 1. Search Google Drive clinical PDFs
        String? localContext;
        List<Map<String, dynamic>> driveSources = [];

        final credsPath =
            (dotenv.env['GOOGLE_SERVICE_ACCOUNT_JSON'] ?? '').trim();
        final folderIds =
            (dotenv.env['GOOGLE_DRIVE_FOLDER_IDS'] ?? '').trim();

        if (credsPath.isNotEmpty && folderIds.isNotEmpty) {
          try {
            print('Querying Google Drive files via search_drive.py...');
            final driveResult = await Process.run('python', [
              'scripts/search_drive.py',
              pathologyName,
              credsPath,
              folderIds,
            ], stdoutEncoding: utf8, stderrEncoding: utf8);

            if (driveResult.exitCode == 0) {
              final driveOutput = driveResult.stdout.toString().trim();
              if (driveOutput.isNotEmpty &&
                  driveOutput != '[]' &&
                  !driveOutput.startsWith('{')) {
                final list = json.decode(driveOutput) as List;

                // Build context string for the AI
                localContext = list.map((item) {
                  final src = item['source'] ?? 'Unknown';
                  final page = item['page'] ?? 0;
                  final txt = item['text'] ?? '';
                  return '[Source PDF: $src (page $page)]:\n$txt';
                }).join('\n\n');

                // Collect unique sources for UI display
                final seen = <String>{};
                for (final item in list) {
                  final src = item['source']?.toString() ?? 'Unknown';
                  final page = item['page'] ?? 0;
                  final fileId = item['id']?.toString();
                  final key = '$src#$page';
                  if (seen.add(key)) {
                    driveSources.add({
                      'source': src,
                      'page': page,
                      if (fileId != null) 'id': fileId,
                    });
                  }
                }
                print('Google Drive search found ${list.length} matches '
                    'across ${driveSources.length} pages.');
              } else if (driveOutput.startsWith('{')) {
                print('Google Drive script returned error: $driveOutput');
              }
            } else {
              print(
                  'Google Drive script failed (exit ${driveResult.exitCode}). '
                  'Stderr: ${driveResult.stderr}');
            }
          } catch (e) {
            print('Error running Google Drive search script: $e');
          }
        }

        // 2. Call LLM guide generator with optional Drive context
        final aiResult = await AiService.instance
            .generatePathologyGuide(pathologyName, localContext: localContext)
            .timeout(const Duration(seconds: 60));

        if (aiResult != null) {
          print('AI-First generation succeeded.');
          return {
            'status': 'success',
            'url': 'Généré par Assistant IA',
            'matched_pathology':
                aiResult['matched_pathology'] ?? pathologyName,
            'definition': aiResult['definition'] ?? '',
            'symptomes': aiResult['symptomes'] ?? '',
            'diagnostic': aiResult['diagnostic'] ?? '',
            'traitements': aiResult['traitements'] ?? '',
            'suggestions': <String>[],
            'is_ai_structured': true,
            // Sources list for UI display
            'drive_sources': driveSources,
          };
        }
      } else {
        return {
          'status': 'error',
          'message':
              'L\'Assistant IA n\'est pas configuré. Veuillez ajouter une clé API dans les paramètres.',
        };
      }
    } catch (aiError) {
      print('AI-First generation failed: $aiError');
      return {
        'status': 'error',
        'message': 'Erreur lors de la génération par l\'IA : $aiError',
      };
    }

    return {
      'status': 'error',
      'message':
          'Impossible de générer le guide clinique pour cette pathologie.',
    };
  }
}
