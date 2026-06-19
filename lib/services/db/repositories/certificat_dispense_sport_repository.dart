import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class CertificatDispenseSportRepository {
  final DatabaseService _db = DatabaseService();

  Future<List<CertificatDispenseSport>> getAll() async {
    final results = await _db.query(
      'SELECT * FROM certificat_dispension_sport WHERE is_deleted = 0 ORDER BY created_at DESC',
    );
    return results.map((row) => CertificatDispenseSport.fromMap(row)).toList();
  }

  Future<Either<Failure, int>> create(CertificatDispenseSport cert) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        'INSERT INTO certificat_dispension_sport (uuid, patient_id, doctor_id, motif, created_at, is_deleted, needs_sync, source_id) VALUES (?, ?, ?, ?, NOW(), 0, 1, ?)',
        [uuid, cert.patientId, cert.doctorId, cert.motif, 'local_server'],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create certificat: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> update(int id, CertificatDispenseSport cert) async {
    try {
      final result = await _db.execute(
        'UPDATE certificat_dispension_sport SET motif = ?, needs_sync = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [cert.motif, id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update certificat: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> delete(int id) async {
    try {
      final result = await _db.execute(
        'UPDATE certificat_dispension_sport SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete certificat: ${e.toString()}'));
    }
  }
}
