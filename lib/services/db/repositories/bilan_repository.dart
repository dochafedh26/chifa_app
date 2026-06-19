import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class BilanRepository implements BaseRepository<Bilan, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Bilan>>> getAll() async {
    try {
      final results = await _db.query('''
        SELECT b.*, 
               CONCAT(e.first_name, " ", e.last_name) as doctorName,
               CONCAT(p.first_name, " ", p.last_name) as patientName
        FROM bilans b
        LEFT JOIN employees e ON b.doctor_id = e.employee_id
        LEFT JOIN patients p ON b.patient_id = p.patient_id
        WHERE b.is_deleted = 0
        ORDER BY b.created_at DESC
      ''');
      final bilans = results.map((row) => Bilan.fromMap(row)).toList();
      return Right(bilans);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get bilans: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Bilan>> getById(int id) async {
    try {
      final results = await _db.query(
        '''
        SELECT b.*, 
               CONCAT(e.first_name, " ", e.last_name) as doctorName,
               CONCAT(p.first_name, " ", p.last_name) as patientName
        FROM bilans b
        LEFT JOIN employees e ON b.doctor_id = e.employee_id
        LEFT JOIN patients p ON b.patient_id = p.patient_id
        WHERE b.id = ? AND b.is_deleted = 0
        ''',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Bilan not found'));
      }
      return Right(Bilan.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get bilan: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> create(Bilan entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO bilans (uuid, patient_id, doctor_id, bilans, medicalrecord_id, created_at, is_deleted, needs_sync, source_id)
           VALUES (?, ?, ?, ?, ?, NOW(), 0, 1, 'local_server')''',
        [
          uuid,
          entity.patientId,
          entity.doctorId,
          entity.bilans,
          entity.medicalrecordId,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create bilan: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Bilan entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE bilans SET 
           patient_id = ?, doctor_id = ?, bilans = ?, needs_sync = 1
           WHERE id = ?''',
        [
          entity.patientId,
          entity.doctorId,
          entity.bilans,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update bilan: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE bilans SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete bilan: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Bilan>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''
        SELECT b.*, 
               CONCAT(e.first_name, " ", e.last_name) as doctorName,
               CONCAT(p.first_name, " ", p.last_name) as patientName
        FROM bilans b
        LEFT JOIN employees e ON b.doctor_id = e.employee_id
        LEFT JOIN patients p ON b.patient_id = p.patient_id
        WHERE (b.bilans LIKE ? OR p.first_name LIKE ? OR p.last_name LIKE ?)
        AND b.is_deleted = 0
        ORDER BY b.created_at DESC
        ''',
        [searchPattern, searchPattern, searchPattern],
      );
      final bilans = results.map((row) => Bilan.fromMap(row)).toList();
      return Right(bilans);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search bilans: ${e.toString()}'));
    }
  }

  /// Get bilans by patient ID
  Future<Either<Failure, List<Bilan>>> getByPatientId(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM bilans WHERE patient_id = ? AND is_deleted = 0 ORDER BY created_at DESC',
        [patientId],
      );
      final bilans = results.map((row) => Bilan.fromMap(row)).toList();
      return Right(bilans);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get bilans by patient: ${e.toString()}'));
    }
  }

  /// Get bilans by doctor ID
  Future<Either<Failure, List<Bilan>>> getByDoctorId(int doctorId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM bilans WHERE doctor_id = ? AND is_deleted = 0 ORDER BY created_at DESC',
        [doctorId],
      );
      final bilans = results.map((row) => Bilan.fromMap(row)).toList();
      return Right(bilans);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get bilans by doctor: ${e.toString()}'));
    }
  }

  /// Get latest bilan for a patient
  Future<Either<Failure, Bilan?>> getLatestByPatientId(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM bilans WHERE patient_id = ? AND is_deleted = 0 ORDER BY created_at DESC LIMIT 1',
        [patientId],
      );
      if (results.isEmpty) {
        return const Right(null);
      }
      return Right(Bilan.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get latest bilan: ${e.toString()}'));
    }
  }

  /// Get all predefined bilan types
  Future<Either<Failure, List<BilanType>>> getAllBilanTypes() async {
    try {
      final results = await _db.query('SELECT * FROM bilan_type WHERE is_deleted = 0 ORDER BY name ASC');
      final types = results.map((row) => BilanType.fromMap(row)).toList();
      return Right(types);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get bilan types: ${e.toString()}'));
    }
  }
}
