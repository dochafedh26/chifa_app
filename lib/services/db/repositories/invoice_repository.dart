import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:chifa/services/db/utils/db_utils.dart";
import "package:dartz/dartz.dart";

class FilteredPaymentsResult {
  final List<Payment> payments;
  final double totalAmount;
  final double totalCommission;

  FilteredPaymentsResult({
    required this.payments,
    required this.totalAmount,
    required this.totalCommission,
  });
}

class InvoiceRepository implements BaseRepository<Payment, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Payment>>> getAll() async {
    try {
      final results = await _db.query(
        'SELECT * FROM payments WHERE is_deleted = 0 ORDER BY payment_date DESC',
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get payments: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Payment>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM payments WHERE payment_id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Payment not found'));
      }
      return Right(Payment.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get payment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> create(Payment entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO payments (uuid, patient_id, doctor_id, patient_name, patient_surname, services, total_amount, payment_date, record_id, note, payment_method, needs_sync)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)''',
        [
          uuid,
          entity.patientId,
          entity.doctorId,
          entity.patientName,
          entity.patientSurname,
          entity.servicesText,
          entity.amount,
          entity.paymentDate.toIso8601String(),
          entity.recordId,
          entity.notes,
          entity.paymentMethod,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create payment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Payment entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE payments SET 
           patient_id = ?, doctor_id = ?, patient_name = ?, patient_surname = ?, 
           services = ?, total_amount = ?, payment_date = ?, record_id = ?, note = ?, 
           payment_method = ?, needs_sync = 1
           WHERE payment_id = ?''',
        [
          entity.patientId,
          entity.doctorId,
          entity.patientName,
          entity.patientSurname,
          entity.servicesText,
          entity.amount,
          entity.paymentDate.toIso8601String(),
          entity.recordId,
          entity.notes,
          entity.paymentMethod,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update payment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      int affectedRows = 0;

      await _db.transaction((conn) async {
        // Soft delete associated services
        await conn.execute(
          'UPDATE payment_services SET is_deleted = 1, needs_sync = 1 WHERE payment_id = ?',
          [id],
        );

        // Soft delete the payment
        final deleteResult = await conn.execute(
          'UPDATE payments SET is_deleted = 1, needs_sync = 1 WHERE payment_id = ?',
          [id],
        );

        affectedRows = deleteResult;
      });

      return Right(affectedRows > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete payment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Payment>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT * FROM payments 
           WHERE (patient_name LIKE ? OR patient_surname LIKE ? OR services LIKE ?)
           AND is_deleted = 0
           ORDER BY payment_date DESC''',
        [searchPattern, searchPattern, searchPattern],
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to search payments: ${e.toString()}'),
      );
    }
  }

  /// Get payments by patient ID
  Future<Either<Failure, List<Payment>>> getByPatientId(int patientId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM payments WHERE patient_id = ? AND is_deleted = 0 ORDER BY payment_date DESC',
        [patientId],
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get payments by patient: ${e.toString()}'),
      );
    }
  }

  /// Get payments by date range
  Future<Either<Failure, List<Payment>>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT * FROM payments 
           WHERE (payment_date BETWEEN ? AND ?) AND is_deleted = 0
           ORDER BY payment_date DESC''',
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(
        DatabaseFailure(
          'Failed to get payments by date range: ${e.toString()}',
        ),
      );
    }
  }

  /// Get payments by date range and doctor ID
  Future<Either<Failure, List<Payment>>> getByDateAndDoctor(
    DateTime startDate,
    DateTime endDate,
    int doctorId,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT * FROM payments 
           WHERE (payment_date BETWEEN ? AND ?) AND doctor_id = ? AND is_deleted = 0
           ORDER BY payment_date DESC''',
        [startDate.toIso8601String(), endDate.toIso8601String(), doctorId],
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(
        DatabaseFailure(
          'Failed to get payments by date and doctor: ${e.toString()}',
        ),
      );
    }
  }

  /// Get total revenue by date range
  Future<Either<Failure, double>> getTotalRevenue(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT COALESCE(SUM(total_amount), 0) as total FROM payments
           WHERE (payment_date BETWEEN ? AND ?) AND is_deleted = 0''',
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );

      if (results.isEmpty) {
        return const Right(0.0);
      }

      final total = results.first['total'];
      // Handle cases where the driver might return Decimal, String, or double
      final revenue = total != null
          ? (total is num
                ? total.toDouble()
                : double.tryParse(total.toString()) ?? 0.0)
          : 0.0;

      return Right(revenue);
    } catch (e) {
      print('Error in getTotalRevenue: $e');
      return Left(
        DatabaseFailure('Failed to get total revenue: ${e.toString()}'),
      );
    }
  }

  /// Get today's revenue
  Future<Either<Failure, double>> getTodayRevenue() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return await getTotalRevenue(startOfDay, endOfDay);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get today\'s revenue: ${e.toString()}'),
      );
    }
  }

  /// Get filtered payments with totals
  Future<Either<Failure, FilteredPaymentsResult>> getFilteredPayments({
    DateTime? startDate,
    DateTime? endDate,
    int? doctorId,
    int? patientId,
    String? patientQuery,
    String? serviceQuery,
  }) async {
    try {
      String whereClause = 'WHERE p.is_deleted = 0';
      List<dynamic> params = [];

      if (startDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        whereClause += ' AND p.payment_date >= ?';
        params.add(start.toIso8601String());
      }

      if (endDate != null) {
        final end = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        );
        whereClause += ' AND p.payment_date <= ?';
        params.add(end.toIso8601String());
      }

      if (doctorId != null) {
        whereClause += ' AND p.doctor_id = ?';
        params.add(doctorId);
      }

      if (patientId != null) {
        whereClause += ' AND p.patient_id = ?';
        params.add(patientId);
      }

      if (patientQuery != null && patientQuery.isNotEmpty) {
        whereClause +=
            ' AND (p.patient_name LIKE ? OR p.patient_surname LIKE ?)';
        params.add('%$patientQuery%');
        params.add('%$patientQuery%');
      }

      if (serviceQuery != null && serviceQuery.isNotEmpty) {
        whereClause += ' AND p.services = ?';
        params.add(serviceQuery);
      }

      // 1. Get payments list
      final listSql =
          'SELECT p.* FROM payments p $whereClause ORDER BY p.payment_date DESC';
      final listResults = await _db.query(listSql, params);
      final payments = listResults.map((row) => Payment.fromMap(row)).toList();

      // 2. Get totals (Amount sum)
      final sumAmountSql =
          'SELECT COALESCE(SUM(p.total_amount), 0) as total FROM payments p $whereClause';
      final sumAmountResults = await _db.query(sumAmountSql, params);
      final totalAmount = DbUtils.toDouble(sumAmountResults.first['total']);

      // 3. Get total commission
      final sumCommSql =
          '''SELECT COALESCE(SUM(ps.doctor_commission), 0) as total 
                             FROM payment_services ps 
                             JOIN payments p ON ps.payment_id = p.payment_id 
                             $whereClause AND ps.is_deleted = 0''';
      final sumCommResults = await _db.query(sumCommSql, params);
      final totalCommission = DbUtils.toDouble(sumCommResults.first['total']);

      return Right(
        FilteredPaymentsResult(
          payments: payments,
          totalAmount: totalAmount,
          totalCommission: totalCommission,
        ),
      );
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to filter payments: ${e.toString()}'),
      );
    }
  }
}
