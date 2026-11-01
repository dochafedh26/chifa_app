import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class CertificatCoupsEtBlessuresRepository {
  final DatabaseService _db = DatabaseService();

  Future<List<CertificatCoupsEtBlessures>> getAll() async {
    final results = await _db.query(
      'SELECT * FROM certificat_coups_et_blessures WHERE is_deleted = 0 ORDER BY created_at DESC',
    );
    return results.map((row) => CertificatCoupsEtBlessures.fromMap(row)).toList();
  }

  Future<Either<Failure, int>> create(CertificatCoupsEtBlessures cert) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO certificat_coups_et_blessures 
        (uuid, patient_id, doctor_id, date_consultation, age_patient, date_faits, heure_faits, type_accident, autres_accident, signes_subjectifs, examen_clinique, necessite_traitement, arret_de_travail_jours, avis_specialise, itt_jours, created_at, is_deleted, needs_sync, source_id) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 0, 1, ?)''',
        [
          uuid,
          cert.patientId,
          cert.doctorId,
          cert.dateConsultation,
          cert.agePatient,
          cert.dateFaits,
          cert.heureFaits,
          cert.typeAccident,
          cert.autresAccident,
          cert.signesSubjectifs,
          cert.examenClinique,
          cert.necessiteTraitement ? 1 : 0,
          cert.arretDeTravailJours,
          cert.avisSpecialise,
          cert.ittJours,
          'local_server',
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create certificat: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> update(int id, CertificatCoupsEtBlessures cert) async {
    try {
      final result = await _db.execute(
        '''UPDATE certificat_coups_et_blessures SET 
        date_consultation = ?, age_patient = ?, date_faits = ?, heure_faits = ?, type_accident = ?, autres_accident = ?, signes_subjectifs = ?, examen_clinique = ?, necessite_traitement = ?, arret_de_travail_jours = ?, avis_specialise = ?, itt_jours = ?, needs_sync = 1, updated_at = CURRENT_TIMESTAMP 
        WHERE id = ?''',
        [
          cert.dateConsultation,
          cert.agePatient,
          cert.dateFaits,
          cert.heureFaits,
          cert.typeAccident,
          cert.autresAccident,
          cert.signesSubjectifs,
          cert.examenClinique,
          cert.necessiteTraitement ? 1 : 0,
          cert.arretDeTravailJours,
          cert.avisSpecialise,
          cert.ittJours,
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
        'UPDATE certificat_coups_et_blessures SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete certificat: ${e.toString()}'));
    }
  }
}
