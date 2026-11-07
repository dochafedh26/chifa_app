import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";
import "package:flutter/foundation.dart";

class PrescriptionRepository implements BaseRepository<Prescription, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<Prescription>>> getAll() async {
    try {
      final results = await _db.query(
        'SELECT * FROM modern_prescriptions WHERE is_deleted = 0 ORDER BY id DESC',
      );
      final prescriptions = results
          .map((row) => Prescription.fromMap(row))
          .toList();
      return Right(prescriptions);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get prescriptions: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Prescription>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM modern_prescriptions WHERE id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Prescription not found'));
      }
      return Right(Prescription.fromMap(results.first));
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get prescription: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> create(Prescription entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      debugPrint('💊 Creating prescription: ${entity.prescription.substring(0, entity.prescription.length > 50 ? 50 : entity.prescription.length)}...');
      final id = await _db.insert(
        'INSERT INTO modern_prescriptions (uuid, prescription, updated_at, is_deleted, needs_sync, source_id) VALUES (?, ?, NOW(), 0, 1, ?)',
        [uuid, entity.prescription, 'local_server'],
      );
      debugPrint('💊 Prescription created with id: $id');
      return Right(id);
    } catch (e) {
      debugPrint('💊 Failed to create prescription: $e');
      return Left(
        DatabaseFailure('Failed to create prescription: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, Prescription entity) async {
    try {
      final result = await _db.execute(
        'UPDATE modern_prescriptions SET prescription = ?, needs_sync = 1 WHERE id = ?',
        [entity.prescription, id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to update prescription: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE modern_prescriptions SET is_deleted = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to delete prescription: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Prescription>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        'SELECT * FROM modern_prescriptions WHERE prescription LIKE ? AND is_deleted = 0 ORDER BY id DESC LIMIT 50',
        [searchPattern],
      );
      final prescriptions = results
          .map((row) => Prescription.fromMap(row))
          .toList();

      try {
        final typeResults = await _db.query(
          'SELECT * FROM ordonnance_type WHERE (title LIKE ? OR prescription LIKE ?) AND is_deleted = 0 ORDER BY id DESC LIMIT 25',
          [searchPattern, searchPattern],
        );
        final existingTexts = prescriptions.map((p) => p.prescription.trim()).toSet();
        for (final row in typeResults) {
          final typeItem = PrescriptionType.fromMap(row);
          if (typeItem.prescription.trim().isNotEmpty &&
              !existingTexts.contains(typeItem.prescription.trim())) {
            prescriptions.insert(
              0,
              Prescription(
                id: typeItem.id,
                prescription: typeItem.prescription,
              ),
            );
            existingTexts.add(typeItem.prescription.trim());
          }
        }
      } catch (_) {}

      return Right(prescriptions);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to search prescriptions: ${e.toString()}'),
      );
    }
  }

  /// Get common prescriptions (templates)
  Future<Either<Failure, List<Prescription>>> getCommonPrescriptions() async {
    try {
      final results = await _db.query(
        'SELECT * FROM modern_prescriptions WHERE is_deleted = 0 ORDER BY id DESC LIMIT 50',
      );
      final prescriptions = results
          .map((row) => Prescription.fromMap(row))
          .toList();
      return Right(prescriptions);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get common prescriptions: ${e.toString()}'),
      );
    }
  }

  /// Get all prescription types (named templates)
  Future<Either<Failure, List<PrescriptionType>>> getAllPrescriptionTypes() async {
    try {
      final results = await _db.query(
        'SELECT * FROM ordonnance_type WHERE is_deleted = 0 ORDER BY id DESC',
      );
      final types = results
          .map((row) => PrescriptionType.fromMap(row))
          .toList();
      return Right(types);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get prescription types: ${e.toString()}'),
      );
    }
  }
}

