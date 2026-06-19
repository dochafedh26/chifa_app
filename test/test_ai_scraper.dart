@Timeout(Duration(minutes: 2))
import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/services/pathology/pathology_scraper_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  test('Pathology Scraper and AI Extraction Test for Chifa', () async {
    // Load .env
    await dotenv.load(fileName: ".env");
    print('Loaded .env successfully.');

    print('Running scrapePathology for "avc"...');
    final result = await PathologyScraperService.instance.scrapePathology('avc');
    expect(result, isNotNull);
    if (result != null) {
      print('\n=======================================');
      print('Matched pathology: ${result['matched_pathology']}');
      print('=======================================');
      print('\n--- DEFINITION ---');
      print(result['definition']);
      print('\n--- SYMPTOMES ---');
      print(result['symptomes']);
      print('\n--- DIAGNOSTIC ---');
      print(result['diagnostic']);
      print('\n--- TRAITEMENTS ---');
      print(result['traitements']);
      print('\n=======================================');
    }
  });
}
