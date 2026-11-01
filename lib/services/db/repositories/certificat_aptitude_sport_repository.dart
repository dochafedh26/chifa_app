import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class CertificatAptitudeSportRepository {
  final DatabaseService _db = DatabaseService();

  Future<List<CertificatAptitudeSport>> getAll() async {
    final results = await _db.query(
      'SELECT * FROM certificat_aptitude_sport WHERE is_deleted = 0 ORDER BY created_at DESC',
    );
    return results.map((row) => CertificatAptitudeSport.fromMap(row)).toList();
  }

  Future<Either<Failure, CertificatAptitudeSport>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM certificat_aptitude_sport WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Certificat not found'));
      }
      return Right(CertificatAptitudeSport.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get certificat: ${e.toString()}'));
    }
  }

  Future<List<CertificatAptitudeSport>> getByPatientId(int patientId) async {
    final results = await _db.query(
      'SELECT * FROM certificat_aptitude_sport WHERE patient_id = ? AND is_deleted = 0 ORDER BY created_at DESC',
      [patientId],
    );
    return results.map((row) => CertificatAptitudeSport.fromMap(row)).toList();
  }

  Future<Either<Failure, int>> create(CertificatAptitudeSport cert) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO certificat_aptitude_sport 
           (uuid, patient_id, doctor_id, sport, type_pratique, examen_clinique, remarques, created_at, is_deleted, needs_sync, source_id) 
           VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), 0, 1, ?)''',
        [
          uuid,
          cert.patientId,
          cert.doctorId,
          cert.sport,
          cert.typePratique,
          cert.examenClinique,
          cert.remarques,
          SyncManager.currentSourceId,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create certificat: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> update(int id, CertificatAptitudeSport cert) async {
    try {
      final result = await _db.execute(
        '''UPDATE certificat_aptitude_sport 
           SET sport = ?, type_pratique = ?, examen_clinique = ?, remarques = ?, needs_sync = 1, updated_at = CURRENT_TIMESTAMP 
           WHERE id = ?''',
        [
          cert.sport,
          cert.typePratique,
          cert.examenClinique,
          cert.remarques,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update certificat: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> delete(int id) async {
    try {
      final result = await _db.execute(
        'UPDATE certificat_aptitude_sport SET is_deleted = 1, needs_sync = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete certificat: ${e.toString()}'));
    }
  }
}

