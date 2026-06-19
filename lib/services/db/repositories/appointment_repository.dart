import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class AppointmentRepository implements BaseRepository<Appointment, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Appointment>>> getAll() async {
    try {
      final results = await _db.query(
        'SELECT * FROM appointments WHERE is_deleted = 0 ORDER BY appointment_date DESC',
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get appointments: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Appointment>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM appointments WHERE appointment_id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Appointment not found'));
      }
      return Right(Appointment.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get appointment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> create(Appointment entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO appointments (uuid, patient_id, doctor_id, appointment_date, status, notes, is_deleted, needs_sync, source_id)
           VALUES (?, ?, ?, ?, ?, ?, 0, 1, 'local_server')''',
        [
          uuid,
          entity.patientId,
          entity.doctorId,
          entity.appointmentDate.toIso8601String(),
          entity.status.name,
          entity.notes,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create appointment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Appointment entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE appointments SET 
           patient_id = ?, doctor_id = ?, appointment_date = ?, status = ?, notes = ?, needs_sync = 1
           WHERE appointment_id = ?''',
        [
          entity.patientId,
          entity.doctorId,
          entity.appointmentDate.toIso8601String(),
          entity.status.name,
          entity.notes,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update appointment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete for sync
      final result = await _db.execute(
        'UPDATE appointments SET is_deleted = 1, needs_sync = 1 WHERE appointment_id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete appointment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Appointment>>> search(String query) async {
    try {
      // Search appointments by patient name (requires join)
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT a.* FROM appointments a
           JOIN patients p ON a.patient_id = p.patient_id
           WHERE (p.first_name LIKE ? OR p.last_name LIKE ?) AND a.is_deleted = 0 AND p.is_deleted = 0
           ORDER BY a.appointment_date DESC''',
        [searchPattern, searchPattern],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search appointments: ${e.toString()}'));
    }
  }

  /// Get appointments by patient ID
  Future<Either<Failure, List<Appointment>>> getByPatientId(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM appointments WHERE patient_id = ? AND is_deleted = 0 ORDER BY appointment_date DESC',
        [patientId],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get appointments by patient: ${e.toString()}'));
    }
  }

  /// Get appointments by doctor ID
  Future<Either<Failure, List<Appointment>>> getByDoctorId(int doctorId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM appointments WHERE doctor_id = ? AND is_deleted = 0 ORDER BY appointment_date DESC',
        [doctorId],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get appointments by doctor: ${e.toString()}'));
    }
  }

  /// Get appointments by date
  Future<Either<Failure, List<Appointment>>> getByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final results = await _db.query(
        '''SELECT * FROM appointments 
           WHERE (appointment_date BETWEEN ? AND ?) AND is_deleted = 0
           ORDER BY appointment_date''',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get appointments by date: ${e.toString()}'));
    }
  }

  /// Get appointments by date range
  Future<Either<Failure, List<Appointment>>> getByDateRange(DateTime start, DateTime end) async {
    try {
      final results = await _db.query(
        '''SELECT * FROM appointments 
           WHERE (appointment_date BETWEEN ? AND ?) AND is_deleted = 0
           ORDER BY appointment_date''',
        [start.toIso8601String(), end.toIso8601String()],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get appointments by date range: ${e.toString()}'));
    }
  }

  /// Get appointments by status
  Future<Either<Failure, List<Appointment>>> getByStatus(AppointmentStatus status) async {
    try {
      final results = await _db.query(
        'SELECT * FROM appointments WHERE status = ? AND is_deleted = 0 ORDER BY appointment_date DESC',
        [status.name],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get appointments by status: ${e.toString()}'));
    }
  }

  /// Update appointment status
  Future<Either<Failure, bool>> updateStatus(int id, AppointmentStatus status) async {
    try {
      final result = await _db.execute(
        'UPDATE appointments SET status = ?, needs_sync = 1 WHERE appointment_id = ?',
        [status.name, id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update appointment status: ${e.toString()}'));
    }
  }

  /// Get upcoming appointments
  Future<Either<Failure, List<Appointment>>> getUpcoming() async {
    try {
      final now = DateTime.now();
      final results = await _db.query(
        '''SELECT * FROM appointments 
           WHERE appointment_date > ? AND status = ? AND is_deleted = 0
           ORDER BY appointment_date ASC
           LIMIT 50''',
        [now.toIso8601String(), AppointmentStatus.scheduled.name],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get upcoming appointments: ${e.toString()}'));
    }
  }

  /// Get today's appointments
  Future<Either<Failure, List<Appointment>>> getTodayAppointments() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final results = await _db.query(
        '''SELECT * FROM appointments 
           WHERE (appointment_date BETWEEN ? AND ?) AND is_deleted = 0
           ORDER BY appointment_date''',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );
      final appointments = results.map((row) => Appointment.fromMap(row)).toList();
      return Right(appointments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get today\'s appointments: ${e.toString()}'));
    }
  }

  /// Automatically cancel past scheduled appointments
  Future<void> autoCancelPastAppointments() async {
    try {
      final now = DateTime.now();
      await _db.execute(
        '''UPDATE appointments 
           SET status = ?, needs_sync = 1
           WHERE appointment_date < ? AND status = ? AND is_deleted = 0''',
        [AppointmentStatus.cancelled.name, now.toIso8601String(), AppointmentStatus.scheduled.name],
      );
    } catch (e) {
      // Ignored
    }
  }
}
