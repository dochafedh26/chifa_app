import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";

class SoinsServiceRepository {
  final DatabaseService _dbService = DatabaseService();

  Future<List<SoinsService>> getAllSoinsServices() async {
    // Fetches the services ordered alphabetically by name
    final results = await _dbService.query(
      'SELECT id, nom FROM soins_services WHERE is_deleted = 0 ORDER BY nom ASC',
    );

    return results
        .map(
          (row) =>
              SoinsService(id: row['id'] as int, nom: row['nom'] as String),
        )
        .toList();
  }
}
