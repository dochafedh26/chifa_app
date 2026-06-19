import 'dart:convert';
import 'dart:io';

class PosologyScraperService {
  static final PosologyScraperService instance = PosologyScraperService._internal();
  PosologyScraperService._internal();

  /// Runs the scrape_vidal.py script to scrape posology data for a medic name or ID.
  /// Returns a map with 'status', 'posologie_adulte', 'posologie_pediatrique', and 'posologie' (weight-based formula if extracted).
  Future<Map<String, dynamic>?> scrapePosology(String medicNameOrId) async {
    try {
      // The script is in the scripts directory in the project root
      final scriptPath = 'scripts/scrape_vidal.py';
      
      final result = await Process.run(
        'python',
        [scriptPath, medicNameOrId],
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        try {
          if (output.isNotEmpty) {
            return json.decode(output) as Map<String, dynamic>;
          }
        } catch (e) {
          print('Failed to parse scraper JSON output: "$output". Error: $e');
        }
      } else {
        print('Scraper script failed with exit code ${result.exitCode}. Stderr: ${result.stderr}');
      }
    } catch (e) {
      print('Exception while running posology scraper: $e');
    }
    return null;
  }
}
