import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class PatientRepository implements BaseRepository<Patient, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Patient>>> getAll() async {
    try {
      final results = await _db.query(
        '''SELECT p.*, IFNULL(pf.medical_records_count, 0) as medical_records_count,
           ps.pathologies as suivi_pathologies,
           (SELECT GROUP_CONCAT(category) FROM patient_suivi_categories WHERE patient_id = p.patient_id AND is_deleted = 0) as categories
           FROM patients p 
           LEFT JOIN patients_fideles pf ON p.patient_id = pf.patient_id 
           LEFT JOIN patients_suivi ps ON p.patient_id = ps.patient_id AND ps.is_deleted = 0
           WHERE p.is_deleted = 0
           ORDER BY p.created_at DESC''',
      );
      final patients = results.map((row) => Patient.fromMap(row)).toList();
      return Right(patients);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get patients: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Patient>> getById(int id) async {
    try {
      final results = await _db.query(
        '''SELECT p.*, IFNULL(pf.medical_records_count, 0) as medical_records_count,
           ps.pathologies as suivi_pathologies,
           (SELECT GROUP_CONCAT(category) FROM patient_suivi_categories WHERE patient_id = p.patient_id AND is_deleted = 0) as categories
           FROM patients p 
           LEFT JOIN patients_fideles pf ON p.patient_id = pf.patient_id 
           LEFT JOIN patients_suivi ps ON p.patient_id = ps.patient_id AND ps.is_deleted = 0
           WHERE p.patient_id = ? AND p.is_deleted = 0''',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Patient not found'));
      }
      return Right(Patient.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get patient: ${e.toString()}'));
    }
  }

  /// Get patient by full name
  Future<Either<Failure, Patient?>> getByName(
    String firstName,
    String lastName,
  ) async {
    try {
      final results = await _db.query(
        'SELECT * FROM patients WHERE first_name = ? AND last_name = ? AND is_deleted = 0',
        [firstName, lastName],
      );
      if (results.isEmpty) {
        return const Right(null);
      }
      return Right(Patient.fromMap(results.first));
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get patient by name: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> create(Patient entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      
      final id = await _db.insert(
        '''INSERT INTO patients (uuid, first_name, last_name, gender, date_of_birth, phone, atcd, source, email, national_id, address, status, is_deleted, needs_sync, source_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?)''',
        [
          uuid,
          entity.firstName,
          entity.lastName,
          entity.gender.name,
          '${entity.dateOfBirth.year}-${entity.dateOfBirth.month.toString().padLeft(2, '0')}-${entity.dateOfBirth.day.toString().padLeft(2, '0')}',
          entity.phone,
          entity.atcd,
          entity.source,
          entity.email,
          entity.nationalId,
          entity.address,
          entity.status.name,
          SyncManager.currentSourceId,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create patient: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Patient entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE patients SET 
           first_name = ?, last_name = ?, gender = ?, date_of_birth = ?, 
           phone = ?, atcd = ?, source = ?, email = ?, national_id = ?, 
           address = ?, status = ?, needs_sync = 1
           WHERE patient_id = ?''',
        [
          entity.firstName,
          entity.lastName,
          entity.gender.name,
          '${entity.dateOfBirth.year}-${entity.dateOfBirth.month.toString().padLeft(2, '0')}-${entity.dateOfBirth.day.toString().padLeft(2, '0')}',
          entity.phone,
          entity.atcd,
          entity.source,
          entity.email,
          entity.nationalId,
          entity.address,
          entity.status.name,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update patient: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete for sync
      final result = await _db.execute(
        'UPDATE patients SET is_deleted = 1, needs_sync = 1 WHERE patient_id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete patient: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Patient>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT p.*, IFNULL(pf.medical_records_count, 0) as medical_records_count,
           ps.pathologies as suivi_pathologies,
           (SELECT GROUP_CONCAT(category) FROM patient_suivi_categories WHERE patient_id = p.patient_id AND is_deleted = 0) as categories
           FROM patients p 
           LEFT JOIN patients_fideles pf ON p.patient_id = pf.patient_id 
           LEFT JOIN patients_suivi ps ON p.patient_id = ps.patient_id AND ps.is_deleted = 0
           WHERE (p.first_name LIKE ? OR p.last_name LIKE ? OR p.phone LIKE ? OR p.email LIKE ? OR p.date_of_birth LIKE ?)
           AND p.is_deleted = 0
           ORDER BY p.created_at DESC''',
        [
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
        ],
      );
      final patients = results.map((row) => Patient.fromMap(row)).toList();
      return Right(patients);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to search patients: ${e.toString()}'),
      );
    }
  }

  /// Get patients by status
  Future<Either<Failure, List<Patient>>> getByStatus(
    PatientStatus status,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT p.*, IFNULL(pf.medical_records_count, 0) as medical_records_count 
           FROM patients p 
           LEFT JOIN patients_fideles pf ON p.patient_id = pf.patient_id 
           WHERE p.status = ? AND p.is_deleted = 0
           ORDER BY p.created_at DESC''',
        [status.name],
      );
      final patients = results.map((row) => Patient.fromMap(row)).toList();
      return Right(patients);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get patients by status: ${e.toString()}'),
      );
    }
  }

  /// Update patient status
  Future<Either<Failure, bool>> updateStatus(
    int id,
    PatientStatus status,
  ) async {
    try {
      final result = await _db.execute(
        'UPDATE patients SET status = ?, needs_sync = 1 WHERE patient_id = ?',
        [status.name, id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to update patient status: ${e.toString()}'),
      );
    }
  }

  /// Get patient count
  Future<Either<Failure, int>> getCount() async {
    try {
      final results = await _db.query('SELECT COUNT(*) as count FROM patients WHERE is_deleted = 0');
      return Right(results.first['count'] as int);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get patient count: ${e.toString()}'),
      );
    }
  }

  /// Get patients by fidelity stars
  Future<Either<Failure, List<Patient>>> getByFidelity(int stars) async {
    try {
      int minRecords;
      int? maxRecords;

      switch (stars) {
        case 1:
          minRecords = 1;
          maxRecords = 2;
          break;
        case 2:
          minRecords = 3;
          maxRecords = 4;
          break;
        case 3:
          minRecords = 5;
          maxRecords = 6;
          break;
        case 4:
          minRecords = 7;
          maxRecords = 8;
          break;
        case 5:
          minRecords = 9;
          maxRecords = null;
          break;
        default:
          return await getAll();
      }

      String sql = '''SELECT p.*, IFNULL(pf.medical_records_count, 0) as medical_records_count,
                      ps.pathologies as suivi_pathologies,
                      (SELECT GROUP_CONCAT(category) FROM patient_suivi_categories WHERE patient_id = p.patient_id AND is_deleted = 0) as categories
                      FROM patients p 
                      JOIN patients_fideles pf ON p.patient_id = pf.patient_id 
                      LEFT JOIN patients_suivi ps ON p.patient_id = ps.patient_id AND ps.is_deleted = 0
                      WHERE pf.medical_records_count >= ? AND p.is_deleted = 0''';
      List<dynamic> params = [minRecords];

      if (maxRecords != null) {
        sql += ' AND pf.medical_records_count <= ?';
        params.add(maxRecords);
      }

      sql += ' ORDER BY p.created_at DESC';

      final results = await _db.query(sql, params);
      final patients = results.map((row) => Patient.fromMap(row)).toList();
      return Right(patients);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get patients by fidelity: ${e.toString()}'),
      );
    }
  }

  /// Get unique categories from patient_suivi_categories
  Future<Either<Failure, List<String>>> getSuiviCategories() async {
    try {
      final results = await _db.query(
        'SELECT DISTINCT category FROM patient_suivi_categories WHERE category IS NOT NULL AND category != "" AND is_deleted = 0',
      );
      final categories = results.map((row) => row['category'] as String).toList();
      return Right(categories);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get categories: ${e.toString()}'));
    }
  }

  /// Get patients by category
  Future<Either<Failure, List<Patient>>> getBySuiviCategory(String category) async {
    try {
      final results = await _db.query(
        '''SELECT p.*, IFNULL(pf.medical_records_count, 0) as medical_records_count,
           ps.pathologies as suivi_pathologies,
           (SELECT GROUP_CONCAT(category) FROM patient_suivi_categories WHERE patient_id = p.patient_id AND is_deleted = 0) as categories
           FROM patients p 
           JOIN patient_suivi_categories psc ON p.patient_id = psc.patient_id 
           LEFT JOIN patients_suivi ps ON p.patient_id = ps.patient_id AND ps.is_deleted = 0
           LEFT JOIN patients_fideles pf ON p.patient_id = pf.patient_id 
           WHERE psc.category = ? AND p.is_deleted = 0 AND psc.is_deleted = 0
           ORDER BY p.created_at DESC''',
        [category],
      );
      final patients = results.map((row) => Patient.fromMap(row)).toList();
      return Right(patients);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get patients by category: ${e.toString()}'));
    }
  }

  /// Sync patient suivi data (insert or update or delete)
  Future<Either<Failure, bool>> syncSuivi(
    int patientId,
    int? doctorId,
    List<String> categories,
    String? pathologies,
  ) async {
    try {
      return await _db.transaction((conn) async {
        // 1. Manage the patients_suivi record (notes/pathologies)
        final results = await conn.query(
          'SELECT id FROM patients_suivi WHERE patient_id = ? AND is_deleted = 0',
          [patientId],
        );

        if (categories.isEmpty && (pathologies == null || pathologies.isEmpty)) {
          // If everything is empty, soft delete the suivi entry and categories
          await conn.execute('UPDATE patients_suivi SET is_deleted = 1, needs_sync = 1 WHERE patient_id = ?', [patientId]);
          await conn.execute('UPDATE patient_suivi_categories SET is_deleted = 1, needs_sync = 1 WHERE patient_id = ?', [patientId]);
          return const Right(true);
        }

        if (results.isEmpty) {
          // Insert suivi
          final uuid = SyncManager().generateUuid();
          await conn.insert(
            'INSERT INTO patients_suivi (uuid, patient_id, doctor_id, pathologies, needs_sync) VALUES (?, ?, ?, ?, 1)',
            [uuid, patientId, doctorId ?? 1, pathologies ?? ''],
          );
        } else {
          // Update suivi
          await conn.execute(
            'UPDATE patients_suivi SET pathologies = ?, updated_at = current_timestamp(), needs_sync = 1 WHERE patient_id = ? AND is_deleted = 0',
            [pathologies ?? '', patientId],
          );
        }

        // 2. Synchronize categories table
        // For simplicity in offline sync, we soft delete existing and insert new ones
        await conn.execute('UPDATE patient_suivi_categories SET is_deleted = 1, needs_sync = 1 WHERE patient_id = ?', [patientId]);
        for (final category in categories) {
          if (category.isNotEmpty) {
            final uuid = SyncManager().generateUuid();
            await conn.insert(
              'INSERT INTO patient_suivi_categories (uuid, patient_id, category, needs_sync) VALUES (?, ?, ?, 1)',
              [uuid, patientId, category],
            );
          }
        }

        return const Right(true);
      });
    } catch (e) {
      return Left(DatabaseFailure('Failed to sync suivi: ${e.toString()}'));
    }
  }
}
