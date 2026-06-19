import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class ServiceRepository implements BaseRepository<Service, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Service>>> getAll() async {
    try {
      final results = await _db.query('SELECT * FROM services WHERE is_deleted = 0 ORDER BY service_name');
      final services = results.map((row) => Service.fromMap(row)).toList();
      return Right(services);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get services: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Service>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM services WHERE service_id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Service not found'));
      }
      return Right(Service.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> create(Service entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO services (uuid, service_name, price, specialization, doctor_commission, needs_sync)
           VALUES (?, ?, ?, ?, ?, 1)''',
        [
          uuid,
          entity.serviceName,
          entity.price,
          entity.specialization,
          entity.doctorCommission,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Service entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE services SET 
           service_name = ?, price = ?, specialization = ?, doctor_commission = ?, needs_sync = 1
           WHERE service_id = ?''',
        [
          entity.serviceName,
          entity.price,
          entity.specialization,
          entity.doctorCommission,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE services SET is_deleted = 1, needs_sync = 1 WHERE service_id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete service: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Service>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        'SELECT * FROM services WHERE (service_name LIKE ? OR specialization LIKE ?) AND is_deleted = 0',
        [searchPattern, searchPattern],
      );
      final services = results.map((row) => Service.fromMap(row)).toList();
      return Right(services);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search services: ${e.toString()}'));
    }
  }

  /// Get services by specialization
  Future<Either<Failure, List<Service>>> getBySpecialization(String specialization) async {
    try {
      final results = await _db.query(
        'SELECT * FROM services WHERE specialization = ? AND is_deleted = 0',
        [specialization],
      );
      final services = results.map((row) => Service.fromMap(row)).toList();
      return Right(services);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get services by specialization: ${e.toString()}'));
    }
  }

  /// Get all services count
  Future<Either<Failure, int>> getCount() async {
    try {
      final results = await _db.query('SELECT COUNT(*) as count FROM services WHERE is_deleted = 0');
      return Right(results.first['count'] as int);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get services count: ${e.toString()}'));
    }
  }
}
