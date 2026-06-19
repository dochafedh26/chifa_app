import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class DoctorWorkingHoursRepository {
  final DatabaseService _db = DatabaseService();

  Future<Either<Failure, List<DoctorWorkingHours>>> getByDoctorId(int doctorId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM doctor_working_hours WHERE doctor_id = ? AND is_deleted = 0 ORDER BY working_date DESC, start_time ASC',
        [doctorId],
      );
      final hours = results.map((row) => DoctorWorkingHours.fromMap(row)).toList();
      return Right(hours);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get working hours: ${e.toString()}'));
    }
  }

  Future<Either<Failure, int>> create(DoctorWorkingHours hours) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO doctor_working_hours (uuid, doctor_id, working_date, start_time, end_time, needs_sync)
           VALUES (?, ?, ?, ?, ?, 1)''',
        [
          uuid,
          hours.doctorId,
          hours.workingDate.toIso8601String().split('T')[0],
          hours.startTime,
          hours.endTime,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save working hours: ${e.toString()}'));
    }
  }

  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE doctor_working_hours SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete working hours: ${e.toString()}'));
    }
  }

  /// Check if a specific time is within a doctor's working hours
  Future<Either<Failure, bool>> isAvailable(int doctorId, DateTime dateTime) async {
    try {
      final dateStr = dateTime.toIso8601String().split('T')[0];
      final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:00';
      
      final results = await _db.query(
        '''SELECT * FROM doctor_working_hours 
           WHERE doctor_id = ? 
           AND working_date = ? 
           AND ? BETWEEN start_time AND end_time
           AND is_deleted = 0''',
        [doctorId, dateStr, timeStr],
      );
      
      return Right(results.isNotEmpty);
    } catch (e) {
      return Left(DatabaseFailure('Failed to check availability: ${e.toString()}'));
    }
  }
}
