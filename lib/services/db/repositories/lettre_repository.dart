import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class LettreRepository implements BaseRepository<Lettre, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Lettre>>> getAll() async {
    try {
      final results = await _db.query('SELECT * FROM lettres WHERE is_deleted = 0 ORDER BY created_at DESC');
      final lettres = results.map((row) => Lettre.fromMap(row)).toList();
      return Right(lettres);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get lettres: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Lettre>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM lettres WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Lettre not found'));
      }
      return Right(Lettre.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get lettre: ${e.toString()}'));
    }
  }

  @override
Future<Either<Failure, int>> create(Lettre entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO lettres (uuid, patient_id, doctor_id, atcd, motif_consultation, examen_clinique, motif_lettre, created_at, is_deleted, needs_sync, source_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), 0, 1, ?)''',
        [
          uuid,
          entity.patientId,
          entity.doctorId,
          entity.atcd,
          entity.motifConsultation,
          entity.examenClinique,
          entity.motifLettre,
          'local_server',
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create lettre: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Lettre entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE lettres SET 
           patient_id = ?, doctor_id = ?, atcd = ?, 
           motif_consultation = ?, examen_clinique = ?, motif_lettre = ?, needs_sync = 1
           WHERE id = ?''',
        [
          entity.patientId,
          entity.doctorId,
          entity.atcd,
          entity.motifConsultation,
          entity.examenClinique,
          entity.motifLettre,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update lettre: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE lettres SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete lettre: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Lettre>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT l.* FROM lettres l
           JOIN patients p ON l.patient_id = p.patient_id
           WHERE (p.first_name LIKE ? OR p.last_name LIKE ? 
              OR l.motif_lettre LIKE ? OR l.motif_consultation LIKE ?)
           AND l.is_deleted = 0 AND p.is_deleted = 0
           ORDER BY l.created_at DESC''',
        [searchPattern, searchPattern, searchPattern, searchPattern],
      );
      final lettres = results.map((row) => Lettre.fromMap(row)).toList();
      return Right(lettres);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search lettres: ${e.toString()}'));
    }
  }

  /// Get lettres by patient ID
  Future<Either<Failure, List<Lettre>>> getByPatientId(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM lettres WHERE patient_id = ? AND is_deleted = 0 ORDER BY created_at DESC',
        [patientId],
      );
      final lettres = results.map((row) => Lettre.fromMap(row)).toList();
      return Right(lettres);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get lettres by patient: ${e.toString()}'));
    }
  }

  /// Get lettres by doctor ID
  Future<Either<Failure, List<Lettre>>> getByDoctorId(int doctorId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM lettres WHERE doctor_id = ? AND is_deleted = 0 ORDER BY created_at DESC',
        [doctorId],
      );
      final lettres = results.map((row) => Lettre.fromMap(row)).toList();
      return Right(lettres);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get lettres by doctor: ${e.toString()}'));
    }
  }

  /// Get latest lettre for a patient
  Future<Either<Failure, Lettre?>> getLatestByPatientId(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM lettres WHERE patient_id = ? AND is_deleted = 0 ORDER BY created_at DESC LIMIT 1',
        [patientId],
      );
      if (results.isEmpty) {
        return const Right(null);
      }
      return Right(Lettre.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get latest lettre: ${e.toString()}'));
    }
  }

  /// Get lettres count
  Future<Either<Failure, int>> getCount() async {
    try {
      final results = await _db.query('SELECT COUNT(*) as count FROM lettres WHERE is_deleted = 0');
      return Right(results.first['count'] as int);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get lettres count: ${e.toString()}'));
    }
  }
}
