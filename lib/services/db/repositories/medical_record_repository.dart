import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class MedicalRecordRepository implements BaseRepository<MedicalRecord, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<MedicalRecord>>> getAll() async {
    try {
      final results = await _db.query('''SELECT mr.*, p.first_name, p.last_name,
                  GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
           FROM medicalrecords mr 
           JOIN patients p ON mr.patient_id = p.patient_id 
           LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
           WHERE mr.is_deleted = 0 AND p.is_deleted = 0
           GROUP BY mr.record_id
           ORDER BY mr.record_date DESC''');
      final records = results.map((row) => MedicalRecord.fromMap(row)).toList();
      return Right(records);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get medical records: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, MedicalRecord>> getById(int id) async {
    try {
      final results = await _db.query(
        '''SELECT mr.*, 
                  GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
           FROM medicalrecords mr 
           LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
           WHERE mr.record_id = ? AND mr.is_deleted = 0 GROUP BY mr.record_id''',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Medical record not found'));
      }
      return Right(MedicalRecord.fromMap(results.first));
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get medical record: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> create(MedicalRecord entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO medicalrecords (
             uuid, patient_id, doctor_id, record_date, motif, details, diagnostic, 
             prescriptions, weight, temperature, tension_arterielle, 
             frequence_cardiaque, spao2, record_timer, is_deleted, needs_sync, source_id
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, 'local_server')''',
        [
          uuid,
          entity.patientId,
          entity.doctorId,
          entity.recordDate.toIso8601String(),
          entity.motif,
          entity.details,
          entity.diagnostic,
          entity.prescriptions,
          entity.weight,
          entity.temperature,
          entity.tensionArterielle,
          entity.frequenceCardiaque,
          entity.spao2,
          entity.recordTimer,
        ],
      );
      await _updateFideliteStatus(entity.patientId);
      return Right(id);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to create medical record: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, MedicalRecord entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE medicalrecords SET 
           patient_id = ?, doctor_id = ?, motif = ?, details = ?, 
           diagnostic = ?, prescriptions = ?, weight = ?, temperature = ?, 
           tension_arterielle = ?, frequence_cardiaque = ?, spao2 = ?, record_timer = ?, needs_sync = 1
           WHERE record_id = ?''',
        [
          entity.patientId,
          entity.doctorId,
          entity.motif,
          entity.details,
          entity.diagnostic,
          entity.prescriptions,
          entity.weight,
          entity.temperature,
          entity.tensionArterielle,
          entity.frequenceCardiaque,
          entity.spao2,
          entity.recordTimer,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to update medical record: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Get patient_id before deleting to update loyalty status later
      final recordResult = await getById(id);
      int? patientId;
      recordResult.fold((_) => null, (r) => patientId = r.patientId);

      // Cascade soft delete: Related payments
      await _db.execute(
        'UPDATE payments SET is_deleted = 1, needs_sync = 1 WHERE record_id = ?',
        [id],
      );

      // Cascade soft delete: Related medicalrecord_services
      await _db.execute(
        'UPDATE medicalrecord_services SET is_deleted = 1, needs_sync = 1 WHERE record_id = ?',
        [id],
      );

      // Cascade soft delete: Related soins_medicaux (medical care)
      await _db.execute(
        'UPDATE soins_medicaux SET is_deleted = 1, needs_sync = 1 WHERE medicalrecord_id = ?',
        [id],
      );

      // Soft delete the medical record itself
      final result = await _db.execute(
        'UPDATE medicalrecords SET is_deleted = 1, needs_sync = 1 WHERE record_id = ?',
        [id],
      );

      if (result > 0 && patientId != null) {
        await _updateFideliteStatus(patientId!);
      }
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to delete medical record: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<MedicalRecord>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT mr.*, p.first_name, p.last_name,
                  GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
           FROM medicalrecords mr 
           JOIN patients p ON mr.patient_id = p.patient_id 
           LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
           WHERE (mr.motif LIKE ? OR mr.details LIKE ? OR mr.diagnostic LIKE ? 
              OR p.first_name LIKE ? OR p.last_name LIKE ?)
           AND mr.is_deleted = 0 AND p.is_deleted = 0
           GROUP BY mr.record_id
           ORDER BY mr.record_date DESC''',
        [
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
        ],
      );
      final records = results.map((row) => MedicalRecord.fromMap(row)).toList();
      return Right(records);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to search medical records: ${e.toString()}'),
      );
    }
  }

  /// Get medical records by patient ID
  Future<Either<Failure, List<MedicalRecord>>> getByPatientId(
    int patientId,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT mr.*, 
                  GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
           FROM medicalrecords mr 
           LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
           WHERE mr.patient_id = ? AND mr.is_deleted = 0
           GROUP BY mr.record_id
           ORDER BY mr.record_date DESC''',
        [patientId],
      );
      final records = results.map((row) => MedicalRecord.fromMap(row)).toList();
      return Right(records);
    } catch (e) {
      return Left(
        DatabaseFailure(
          'Failed to get medical records by patient: ${e.toString()}',
        ),
      );
    }
  }

  /// Get medical records by doctor ID
  Future<Either<Failure, List<MedicalRecord>>> getByDoctorId(
    int doctorId,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT mr.*, 
                  GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
           FROM medicalrecords mr 
           LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
           WHERE mr.doctor_id = ? AND mr.is_deleted = 0
           GROUP BY mr.record_id
           ORDER BY mr.record_date DESC''',
        [doctorId],
      );
      final records = results.map((row) => MedicalRecord.fromMap(row)).toList();
      return Right(records);
    } catch (e) {
      return Left(
        DatabaseFailure(
          'Failed to get medical records by doctor: ${e.toString()}',
        ),
      );
    }
  }

  /// Get latest medical record for a patient
  Future<Either<Failure, MedicalRecord?>> getLatestByPatientId(
    int patientId,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT mr.*, 
                  GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
           FROM medicalrecords mr 
           LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
           WHERE mr.patient_id = ? AND mr.is_deleted = 0
           GROUP BY mr.record_id
           ORDER BY mr.record_date DESC LIMIT 1''',
        [patientId],
      );
      if (results.isEmpty) {
        return const Right(null);
      }
      return Right(MedicalRecord.fromMap(results.first));
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get latest medical record: ${e.toString()}'),
      );
    }
  }

  /// Get medical records count
  Future<Either<Failure, int>> getCount() async {
    try {
      final results = await _db.query(
        'SELECT COUNT(*) as count FROM medicalrecords WHERE is_deleted = 0',
      );
      return Right(results.first['count'] as int);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get medical records count: ${e.toString()}'),
      );
    }
  }

  /// Get medical records by date range
  Future<Either<Failure, List<MedicalRecord>>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT mr.*, p.first_name, p.last_name,
                  GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
           FROM medicalrecords mr 
           JOIN patients p ON mr.patient_id = p.patient_id 
           LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
           WHERE mr.record_date BETWEEN ? AND ? AND mr.is_deleted = 0 AND p.is_deleted = 0
           GROUP BY mr.record_id
           ORDER BY mr.record_date DESC''',
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );
      final records = results.map((row) => MedicalRecord.fromMap(row)).toList();
      return Right(records);
    } catch (e) {
      return Left(
        DatabaseFailure(
          'Failed to get medical records by date range: ${e.toString()}',
        ),
      );
    }
  }

  /// Get filtered medical records
  Future<Either<Failure, List<MedicalRecord>>> getFiltered({
    DateTime? startDate,
    DateTime? endDate,
    int? doctorId,
    String? patientQuery,
    String? motifQuery,
  }) async {
    try {
      final List<dynamic> params = [];
      String sql = '''SELECT mr.*, p.first_name, p.last_name,
                              GROUP_CONCAT(sm.soins SEPARATOR '\n') as soins_text 
                       FROM medicalrecords mr 
                       JOIN patients p ON mr.patient_id = p.patient_id 
                       LEFT JOIN soins_medicaux sm ON sm.medicalrecord_id = mr.record_id AND sm.is_deleted = 0
                       WHERE mr.is_deleted = 0 AND p.is_deleted = 0''';

      if (startDate != null) {
        sql += ' AND mr.record_date >= ?';
        params.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        // Use end of day
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        sql += ' AND mr.record_date <= ?';
        params.add(endOfDay.toIso8601String());
      }
      if (doctorId != null) {
        sql += ' AND mr.doctor_id = ?';
        params.add(doctorId);
      }
      if (patientQuery != null && patientQuery.trim().isNotEmpty) {
        sql += ' AND (p.first_name LIKE ? OR p.last_name LIKE ?)';
        final pattern = '%${patientQuery.trim()}%';
        params.add(pattern);
        params.add(pattern);
      }
      if (motifQuery != null && motifQuery.trim().isNotEmpty) {
        sql +=
            ' AND (mr.motif LIKE ? OR mr.details LIKE ? OR mr.diagnostic LIKE ?)';
        final pattern = '%${motifQuery.trim()}%';
        params.add(pattern);
        params.add(pattern);
        params.add(pattern);
      }

      sql += ' GROUP BY mr.record_id ORDER BY mr.record_date DESC';

      final results = await _db.query(sql, params);
      final records = results.map((row) => MedicalRecord.fromMap(row)).toList();
      return Right(records);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to filter medical records: ${e.toString()}'),
      );
    }
  }

  /// Update the loyalty status in patients_fideles table
  Future<void> _updateFideliteStatus(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT COUNT(*) as count FROM medicalrecords WHERE patient_id = ? AND is_deleted = 0',
        [patientId],
      );
      final count = results.first['count'] as int;

      if (count >= 3) {
        // Check if patient already exists in patients_fideles
        final existing = await _db.query(
          'SELECT patient_id FROM patients_fideles WHERE patient_id = ? AND is_deleted = 0',
          [patientId],
        );

        if (existing.isNotEmpty) {
          // Update existing record
          await _db.execute(
            'UPDATE patients_fideles SET medical_records_count = ?, updated_at = CURRENT_TIMESTAMP, needs_sync = 1 WHERE patient_id = ? AND is_deleted = 0',
            [count, patientId],
          );
        } else {
          // Insert new record
          final uuid = SyncManager().generateUuid();
          await _db.execute(
            'INSERT INTO patients_fideles (uuid, patient_id, medical_records_count, needs_sync) VALUES (?, ?, ?, 1)',
            [uuid, patientId, count],
          );
        }
      } else {
        // Soft delete from loyalty table if count drops below 3
        await _db.execute(
          'UPDATE patients_fideles SET is_deleted = 1, needs_sync = 1 WHERE patient_id = ? AND is_deleted = 0',
          [patientId],
        );
      }
    } catch (e) {
      // Silently fail, as this is a non-critical background task.
    }
  }
}
