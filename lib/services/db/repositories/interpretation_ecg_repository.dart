import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class InterpretationEcgRepository {
  final DatabaseService _db = DatabaseService();

  Future<List<InterpretationEcg>> getAll() async {
    final results = await _db.query(
      'SELECT * FROM interpretation_ecg WHERE is_deleted = 0 ORDER BY created_at DESC',
    );
    return results.map((row) => InterpretationEcg.fromMap(row)).toList();
  }

  Future<Either<Failure, InterpretationEcg>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM interpretation_ecg WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Compte-rendu ECG non trouvé'));
      }
      return Right(InterpretationEcg.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get ECG interpretation: ${e.toString()}'));
    }
  }

  Future<List<InterpretationEcg>> getByPatientId(int patientId) async {
    final results = await _db.query(
      'SELECT * FROM interpretation_ecg WHERE patient_id = ? AND is_deleted = 0 ORDER BY created_at DESC',
      [patientId],
    );
    return results.map((row) => InterpretationEcg.fromMap(row)).toList();
  }

  Future<Either<Failure, int>> create(InterpretationEcg ecg) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO interpretation_ecg 
           (uuid, patient_id, doctor_id, motif, rythme, frequence_cardiaque, axe_qrs, onde_p, espace_pr, complexe_qrs, segment_st, onde_t, intervalle_qt, conclusion, remarques, created_at, is_deleted, needs_sync, source_id) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 0, 1, ?)''',
        [
          uuid,
          ecg.patientId,
          ecg.doctorId,
          ecg.motif,
          ecg.rythme,
          ecg.frequenceCardiaque,
          ecg.axeQrs,
          ecg.ondeP,
          ecg.espacePr,
          ecg.complexeQrs,
          ecg.segmentSt,
          ecg.ondeT,
          ecg.intervalleQt,
          ecg.conclusion,
          ecg.remarques,
          SyncManager.currentSourceId,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create ECG interpretation: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> update(int id, InterpretationEcg ecg) async {
    try {
      final result = await _db.execute(
        '''UPDATE interpretation_ecg 
           SET motif = ?, rythme = ?, frequence_cardiaque = ?, axe_qrs = ?, onde_p = ?, espace_pr = ?, complexe_qrs = ?, segment_st = ?, onde_t = ?, intervalle_qt = ?, conclusion = ?, remarques = ?, needs_sync = 1, updated_at = CURRENT_TIMESTAMP 
           WHERE id = ?''',
        [
          ecg.motif,
          ecg.rythme,
          ecg.frequenceCardiaque,
          ecg.axeQrs,
          ecg.ondeP,
          ecg.espacePr,
          ecg.complexeQrs,
          ecg.segmentSt,
          ecg.ondeT,
          ecg.intervalleQt,
          ecg.conclusion,
          ecg.remarques,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update ECG interpretation: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> delete(int id) async {
    try {
      final result = await _db.execute(
        'UPDATE interpretation_ecg SET is_deleted = 1, needs_sync = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete ECG interpretation: ${e.toString()}'));
    }
  }
}

