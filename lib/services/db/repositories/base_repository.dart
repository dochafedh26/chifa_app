import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

/// Base failure class for error handling
abstract class Failure {
  final String message;
  final int? code;

  Failure(this.message, {this.code});

  @override
  String toString() => 'Failure{message: $message, code: $code}';
}

class DatabaseFailure extends Failure {
  DatabaseFailure(super.message, {super.code});
}

class NotFoundFailure extends Failure {
  NotFoundFailure(super.message);
}

class ValidationFailure extends Failure {
  ValidationFailure(super.message);
}

/// Base Repository with common CRUD operations
abstract class BaseRepository<T, ID> {
  final DatabaseService _db = DatabaseService();

  DatabaseService get db => _db;

  /// Get all entities
  Future<Either<Failure, List<T>>> getAll();

  /// Get entity by ID
  Future<Either<Failure, T>> getById(ID id);

  /// Create new entity
  Future<Either<Failure, ID>> create(T entity);

  /// Update entity
  Future<Either<Failure, bool>> update(ID id, T entity);

  /// Delete entity
  Future<Either<Failure, bool>> delete(ID id);

  /// Search entities by query
  Future<Either<Failure, List<T>>> search(String query);
}
