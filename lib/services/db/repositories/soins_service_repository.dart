import "package:chifa/services/db/database.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/sync_manager.dart";
import "package:dartz/dartz.dart";

class SoinsServiceRepository implements BaseRepository<SoinsService, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  /// Fetches the services ordered alphabetically by name (Legacy compatibility)
  Future<List<SoinsService>> getAllSoinsServices() async {
    final results = await _db.query(
      'SELECT * FROM soins_services WHERE is_deleted = 0 ORDER BY nom ASC',
    );
    return results.map((row) => SoinsService.fromMap(row)).toList();
  }

  @override
  Future<Either<Failure, List<SoinsService>>> getAll() async {
    try {
      final results = await _db.query(
        'SELECT * FROM soins_services WHERE is_deleted = 0 ORDER BY nom ASC',
      );
      final services = results.map((row) => SoinsService.fromMap(row)).toList();
      return Right(services);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get soins services: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SoinsService>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM soins_services WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Soins service not found'));
      }
      return Right(SoinsService.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get soins service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> create(SoinsService entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO soins_services (uuid, nom, price, doctor_commission, needs_sync)
           VALUES (?, ?, ?, ?, 1)''',
        [
          uuid,
          entity.nom,
          entity.price,
          entity.doctorCommission,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create soins service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, SoinsService entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE soins_services SET 
           nom = ?, price = ?, doctor_commission = ?, needs_sync = 1
           WHERE id = ?''',
        [
          entity.nom,
          entity.price,
          entity.doctorCommission,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update soins service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      final result = await _db.execute(
        'UPDATE soins_services SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete soins service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SoinsService>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        'SELECT * FROM soins_services WHERE nom LIKE ? AND is_deleted = 0 ORDER BY nom ASC',
        [searchPattern],
      );
      final services = results.map((row) => SoinsService.fromMap(row)).toList();
      return Right(services);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search soins services: ${e.toString()}'));
    }
  }
}
