import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class ArretDeTravailRepository implements BaseRepository<ArretDeTravail, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<ArretDeTravail>>> getAll() async {
    try {
      final results = await _db.query('SELECT * FROM arret_de_travail WHERE is_deleted = 0 ORDER BY date_creation DESC');
      final arrets = results.map((row) => ArretDeTravail.fromMap(row)).toList();
      return Right(arrets);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get arrets de travail: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ArretDeTravail>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM arret_de_travail WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Arret de travail not found'));
      }
      return Right(ArretDeTravail.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get arret de travail: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> create(ArretDeTravail entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO arret_de_travail (uuid, patient_id, doctor_id, type, motif, date_debut, jours, date_reprise, date_creation, is_deleted, needs_sync, source_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), 0, 1, 'local_server')''',
        [
          uuid,
          entity.patientId,
          entity.doctorId,
          entity.type,
          entity.motif,
          entity.dateDebut.toIso8601String(),
          entity.jours,
          entity.dateReprise.toIso8601String(),
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create arret de travail: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, ArretDeTravail entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE arret_de_travail SET 
           patient_id = ?, doctor_id = ?, type = ?, motif = ?, 
           date_debut = ?, jours = ?, date_reprise = ?, needs_sync = 1
           WHERE id = ?''',
        [
          entity.patientId,
          entity.doctorId,
          entity.type,
          entity.motif,
          entity.dateDebut.toIso8601String(),
          entity.jours,
          entity.dateReprise.toIso8601String(),
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update arret de travail: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE arret_de_travail SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete arret de travail: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ArretDeTravail>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT a.* FROM arret_de_travail a
           JOIN patients p ON a.patient_id = p.patient_id
           WHERE (p.first_name LIKE ? OR p.last_name LIKE ? OR a.motif LIKE ? OR a.type LIKE ?)
           AND a.is_deleted = 0 AND p.is_deleted = 0
           ORDER BY a.date_creation DESC''',
        [searchPattern, searchPattern, searchPattern, searchPattern],
      );
      final arrets = results.map((row) => ArretDeTravail.fromMap(row)).toList();
      return Right(arrets);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search arrets de travail: ${e.toString()}'));
    }
  }

  /// Get arrets by patient ID
  Future<Either<Failure, List<ArretDeTravail>>> getByPatientId(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM arret_de_travail WHERE patient_id = ? AND is_deleted = 0 ORDER BY date_creation DESC',
        [patientId],
      );
      final arrets = results.map((row) => ArretDeTravail.fromMap(row)).toList();
      return Right(arrets);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get arrets by patient: ${e.toString()}'));
    }
  }

  /// Get arrets by doctor ID
  Future<Either<Failure, List<ArretDeTravail>>> getByDoctorId(int doctorId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM arret_de_travail WHERE doctor_id = ? AND is_deleted = 0 ORDER BY date_creation DESC',
        [doctorId],
      );
      final arrets = results.map((row) => ArretDeTravail.fromMap(row)).toList();
      return Right(arrets);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get arrets by doctor: ${e.toString()}'));
    }
  }

  /// Get arrets by type
  Future<Either<Failure, List<ArretDeTravail>>> getByType(String type) async {
    try {
      final results = await _db.query(
        'SELECT * FROM arret_de_travail WHERE type = ? AND is_deleted = 0 ORDER BY date_creation DESC',
        [type],
      );
      final arrets = results.map((row) => ArretDeTravail.fromMap(row)).toList();
      return Right(arrets);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get arrets by type: ${e.toString()}'));
    }
  }

  /// Get arrets by date range
  Future<Either<Failure, List<ArretDeTravail>>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT * FROM arret_de_travail 
           WHERE (date_creation BETWEEN ? AND ?) AND is_deleted = 0
           ORDER BY date_creation DESC''',
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );
      final arrets = results.map((row) => ArretDeTravail.fromMap(row)).toList();
      return Right(arrets);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get arrets by date range: ${e.toString()}'));
    }
  }

  /// Get arrets count
  Future<Either<Failure, int>> getCount() async {
    try {
      final results = await _db.query('SELECT COUNT(*) as count FROM arret_de_travail WHERE is_deleted = 0');
      return Right(results.first['count'] as int);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get arrets count: ${e.toString()}'));
    }
  }
}
