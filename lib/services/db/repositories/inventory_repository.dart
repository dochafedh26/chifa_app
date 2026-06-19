import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class InventoryRepository implements BaseRepository<InventoryItem, int> {
  final DatabaseService _db = DatabaseService();

  @override
  DatabaseService get db => _db;

  @override
  Future<Either<Failure, List<InventoryItem>>> getAll() async {
    try {
      final results = await _db.query('SELECT * FROM inventory WHERE is_deleted = 0 ORDER BY item_name');
      final items = results.map((row) => InventoryItem.fromMap(row)).toList();
      return Right(items);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get inventory items: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, InventoryItem>> getById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM inventory WHERE item_id = ? AND is_deleted = 0',
        [id],
      );
      if (results.isEmpty) {
        return Left(NotFoundFailure('Inventory item not found'));
      }
      return Right(InventoryItem.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get inventory item: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> create(InventoryItem entity) async {
    try {
      final uuid = SyncManager().generateUuid();
      final id = await _db.insert(
        '''INSERT INTO inventory (uuid, item_name, category, quantity, unit_price, expiration_date, purchase_date, supplier_name, created_at, is_deleted, needs_sync, source_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), 0, 1, ?)''',
        [
          uuid,
          entity.itemName,
          entity.category.name,
          entity.quantity,
          entity.unitPrice,
          entity.expirationDate?.toIso8601String(),
          entity.purchaseDate.toIso8601String(),
          entity.supplierName,
          'local_server',
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure('Failed to create inventory item: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> update(int id, InventoryItem entity) async {
    try {
      final result = await _db.execute(
        '''UPDATE inventory SET
           item_name = ?, category = ?, quantity = ?, unit_price = ?,
           expiration_date = ?, purchase_date = ?, supplier_name = ?, needs_sync = 1
           WHERE item_id = ?''',
        [
          entity.itemName,
          entity.category.name,
          entity.quantity,
          entity.unitPrice,
          entity.expirationDate?.toIso8601String(),
          entity.purchaseDate.toIso8601String(),
          entity.supplierName,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update inventory item: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> delete(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE inventory SET is_deleted = 1, needs_sync = 1 WHERE item_id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete inventory item: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<InventoryItem>>> search(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = await _db.query(
        '''SELECT * FROM inventory
           WHERE (item_name LIKE ? OR supplier_name LIKE ?) AND is_deleted = 0
           ORDER BY item_name''',
        [searchPattern, searchPattern],
      );
      final items = results.map((row) => InventoryItem.fromMap(row)).toList();
      return Right(items);
    } catch (e) {
      return Left(DatabaseFailure('Failed to search inventory items: ${e.toString()}'));
    }
  }

  /// Get items by category
  Future<Either<Failure, List<InventoryItem>>> getByCategory(InventoryCategory category) async {
    try {
      final results = await _db.query(
        'SELECT * FROM inventory WHERE category = ? AND is_deleted = 0 ORDER BY item_name',
        [category.name],
      );
      final items = results.map((row) => InventoryItem.fromMap(row)).toList();
      return Right(items);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get items by category: ${e.toString()}'));
    }
  }

  /// Get low stock items (quantity below threshold)
  Future<Either<Failure, List<InventoryItem>>> getLowStockItems(int threshold) async {
    try {
      final results = await _db.query(
        'SELECT * FROM inventory WHERE quantity < ? AND is_deleted = 0 ORDER BY quantity ASC',
        [threshold],
      );
      final items = results.map((row) => InventoryItem.fromMap(row)).toList();
      return Right(items);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get low stock items: ${e.toString()}'));
    }
  }

  /// Get expired items
  Future<Either<Failure, List<InventoryItem>>> getExpiredItems() async {
    try {
      final now = DateTime.now().toIso8601String();
      final results = await _db.query(
        '''SELECT * FROM inventory
           WHERE expiration_date IS NOT NULL AND expiration_date < ? AND is_deleted = 0
           ORDER BY expiration_date ASC''',
        [now],
      );
      final items = results.map((row) => InventoryItem.fromMap(row)).toList();
      return Right(items);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get expired items: ${e.toString()}'));
    }
  }

  /// Update item quantity (for stock in/out operations)
  Future<Either<Failure, bool>> updateQuantity(int id, int quantity) async {
    try {
      final result = await _db.execute(
        'UPDATE inventory SET quantity = ?, needs_sync = 1 WHERE item_id = ?',
        [quantity, id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update quantity: ${e.toString()}'));
    }
  }

  /// Add stock (increment quantity)
  Future<Either<Failure, bool>> addStock(int id, int quantity) async {
    try {
      final result = await _db.execute(
        'UPDATE inventory SET quantity = quantity + ?, needs_sync = 1 WHERE item_id = ?',
        [quantity, id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to add stock: ${e.toString()}'));
    }
  }

  /// Remove stock (decrement quantity)
  Future<Either<Failure, bool>> removeStock(int id, int quantity) async {
    try {
      final result = await _db.execute(
        'UPDATE inventory SET quantity = quantity - ?, needs_sync = 1 WHERE item_id = ? AND quantity >= ?',
        [quantity, id, quantity],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to remove stock: ${e.toString()}'));
    }
  }

  /// Get total inventory value
  Future<Either<Failure, double>> getTotalValue() async {
    try {
      final results = await _db.query(
        'SELECT SUM(quantity * unit_price) as total FROM inventory WHERE is_deleted = 0',
      );
      final total = results.first['total'];
      return Right(total != null ? (total as num).toDouble() : 0.0);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get total inventory value: ${e.toString()}'));
    }
  }

  /// Get items count
  Future<Either<Failure, int>> getCount() async {
    try {
      final results = await _db.query('SELECT COUNT(*) as count FROM inventory WHERE is_deleted = 0');
      return Right(results.first['count'] as int);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get inventory count: ${e.toString()}'));
    }
  }
}
