import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class PaymentRepository implements BaseRepository<Payment, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Payment>>> getAll() async {
    try {
      final results = await _db.query('SELECT * FROM payments WHERE is_deleted = 0 ORDER BY payment_date DESC');
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
      final map = entity.toMap();
      map.remove('payment_id');
      map['uuid'] = uuid;
      map['needs_sync'] = 1;
      
      final columns = map.keys.join(', ');
      final placeholders = List.filled(map.keys.length, '?').join(', ');
      final values = map.values.toList();
      
      final id = await _db.insert(
        'INSERT INTO payments ($columns) VALUES ($placeholders)',
        values,
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create payment: ${e.toString()}'));
    }
  }

  /// Create a payment and associated payment services in a transaction
  Future<Either<Failure, int>> createWithServices(Payment payment, List<PaymentService> services) async {
    try {
      final paymentId = await _db.transaction((conn) async {
        // 1. Insert Payment
        final uuid = SyncManager().generateUuid();
        final map = payment.toMap();
        map.remove('payment_id');
        map['uuid'] = uuid;
        map['needs_sync'] = 1;
        
        final columns = map.keys.join(', ');
        final placeholders = List.filled(map.keys.length, '?').join(', ');
        
        final id = await conn.insert(
          'INSERT INTO payments ($columns) VALUES ($placeholders)',
          map.values.toList(),
        );

        // 2. Insert Payment Services
        if (services.isNotEmpty) {
          for (var service in services) {
            final sUuid = SyncManager().generateUuid();
            await conn.insert(
              '''INSERT INTO payment_services (uuid, payment_id, service_id, service_name, service_price, doctor_commission, service_type, needs_sync)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 1)''',
              [
                sUuid,
                id,
                service.serviceId,
                service.serviceName,
                service.servicePrice,
                service.doctorCommission,
                service.serviceType,
              ],
            );
          }
        }
        return id;
      });
      return Right(paymentId);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create payment with services: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Payment entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE payments SET
           invoice_id = ?, total_amount = ?, payment_method = ?, note = ?, discount_amount = ?, discount_type = ?, discount_value = ?,
           discount_commission_amount = ?, discount_commission_type = ?, discount_commission_value = ?, apply_commission_discount = ?, needs_sync = 1
           WHERE payment_id = ?''',
        [
          entity.invoiceId,
          entity.amount,
          entity.paymentMethod,
          entity.notes,
          entity.discountAmount,
          entity.discountType,
          entity.discountValue,
          entity.discountCommissionAmount,
          entity.discountCommissionType,
          entity.discountCommissionValue,
          entity.applyCommissionDiscount ? 1 : 0,
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
      final success = await _db.transaction((conn) async {
        // 1. Soft delete associated services
        await conn.execute(
          'UPDATE payment_services SET is_deleted = 1, needs_sync = 1 WHERE payment_id = ?',
          [id],
        );

        // 2. Soft delete the payment
        final affectedRows = await conn.execute(
          'UPDATE payments SET is_deleted = 1, needs_sync = 1 WHERE payment_id = ?',
          [id],
        );
        
        return affectedRows > 0;
      });
      
      return Right(success);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete payment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Payment>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT p.* FROM payments p
           JOIN invoices i ON p.invoice_id = i.invoice_id
           JOIN patients pt ON i.patient_id = pt.patient_id
           WHERE (pt.first_name LIKE ? OR pt.last_name LIKE ?) 
           AND p.is_deleted = 0 AND i.is_deleted = 0 AND pt.is_deleted = 0
           ORDER BY p.payment_date DESC''',
        [searchPattern, searchPattern],
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search payments: ${e.toString()}'));
    }
  }

  /// Get payments by invoice ID
  Future<Either<Failure, List<Payment>>> getByInvoiceId(int invoiceId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM payments WHERE invoice_id = ? AND is_deleted = 0 ORDER BY payment_date DESC',
        [invoiceId],
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get payments by invoice: ${e.toString()}'));
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
      return Left(DatabaseFailure('Failed to get payments by patient: ${e.toString()}'));
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
           WHERE payment_date BETWEEN ? AND ? AND is_deleted = 0
           ORDER BY payment_date DESC''',
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );
      final payments = results.map((row) => Payment.fromMap(row)).toList();
      return Right(payments);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get payments by date range: ${e.toString()}'));
    }
  }

  /// Get total payments by date range
  Future<Either<Failure, double>> getTotalByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final results = await _db.query(
        '''SELECT SUM(total_amount) as total FROM payments
           WHERE payment_date BETWEEN ? AND ? AND is_deleted = 0''',
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );
      final total = results.first['total'];
      return Right(total != null ? (total as num).toDouble() : 0.0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get total payments: ${e.toString()}'));
    }
  }

  /// Get payment services by record ID
  Future<Either<Failure, List<PaymentService>>> getServicesByRecordId(int recordId) async {
    try {
      final results = await _db.query(
        '''SELECT ps.* FROM payment_services ps
           JOIN payments p ON ps.payment_id = p.payment_id
           WHERE p.record_id = ? AND p.is_deleted = 0 AND ps.is_deleted = 0''',
        [recordId],
      );
      final services = results.map((row) => PaymentService.fromMap(row)).toList();
      return Right(services);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get services by record: ${e.toString()}'));
    }
  }

  /// Get payment by record ID
  Future<Either<Failure, Payment?>> getByRecordId(int recordId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM payments WHERE record_id = ? AND is_deleted = 0 LIMIT 1',
        [recordId],
      );
      if (results.isEmpty) {
        return const Right(null);
      }
      return Right(Payment.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get payment by record: ${e.toString()}'));
    }
  }

  /// Get payment services by payment ID
  Future<Either<Failure, List<PaymentService>>> getServicesByPaymentId(int paymentId) async {
    try {
      final results = await _db.query(
        'SELECT * FROM payment_services WHERE payment_id = ? AND is_deleted = 0',
        [paymentId],
      );
      final services = results.map((row) => PaymentService.fromMap(row)).toList();
      return Right(services);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get payment services: ${e.toString()}'));
    }
  }

  /// Update payment with services - replaces existing services
  Future<Either<Failure, bool>> updateWithServices(int paymentId, Payment payment, List<PaymentService> newServices) async {
    try {
      final success = await _db.transaction((conn) async {
        // 1. Update payment
        await conn.execute(
          '''UPDATE payments SET
             total_amount = ?, note = ?, discount_amount = ?, discount_type = ?, discount_value = ?,
             discount_commission_amount = ?, discount_commission_type = ?, discount_commission_value = ?, apply_commission_discount = ?, needs_sync = 1
             WHERE payment_id = ?''',
          [
            payment.amount,
            payment.notes,
            payment.discountAmount,
            payment.discountType,
            payment.discountValue,
            payment.discountCommissionAmount,
            payment.discountCommissionType,
            payment.discountCommissionValue,
            payment.applyCommissionDiscount ? 1 : 0,
            paymentId,
          ],
        );

        // 2. Delete existing services (soft delete)
        await conn.execute(
          'UPDATE payment_services SET is_deleted = 1, needs_sync = 1 WHERE payment_id = ?',
          [paymentId],
        );

        // 3. Insert new services
        for (var service in newServices) {
          final sUuid = SyncManager().generateUuid();
          await conn.insert(
            '''INSERT INTO payment_services (uuid, payment_id, service_id, service_name, service_price, doctor_commission, service_type, needs_sync)
               VALUES (?, ?, ?, ?, ?, ?, ?, 1)''',
            [
              sUuid,
              paymentId,
              service.serviceId,
              service.serviceName,
              service.servicePrice,
              service.doctorCommission,
              service.serviceType,
            ],
          );
        }
        return true;
      });
      return Right(success);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update payment with services: ${e.toString()}'));
    }
  }
}
