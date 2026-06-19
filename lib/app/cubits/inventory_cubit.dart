import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Inventory Events
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadInventory extends InventoryEvent {}

class LoadInventoryItemById extends InventoryEvent {
  final int id;

  const LoadInventoryItemById(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadInventoryByCategory extends InventoryEvent {
  final InventoryCategory category;

  const LoadInventoryByCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class SearchInventory extends InventoryEvent {
  final String query;

  const SearchInventory(this.query);

  @override
  List<Object?> get props => [query];
}

class CreateInventoryItem extends InventoryEvent {
  final InventoryItem item;

  const CreateInventoryItem(this.item);

  @override
  List<Object?> get props => [item];
}

class UpdateInventoryItem extends InventoryEvent {
  final int id;
  final InventoryItem item;

  const UpdateInventoryItem(this.id, this.item);

  @override
  List<Object?> get props => [id, item];
}

class DeleteInventoryItem extends InventoryEvent {
  final int id;

  const DeleteInventoryItem(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateInventoryQuantity extends InventoryEvent {
  final int id;
  final int quantity;

  const UpdateInventoryQuantity(this.id, this.quantity);

  @override
  List<Object?> get props => [id, quantity];
}

class AddStock extends InventoryEvent {
  final int id;
  final int quantity;

  const AddStock(this.id, this.quantity);

  @override
  List<Object?> get props => [id, quantity];
}

class RemoveStock extends InventoryEvent {
  final int id;
  final int quantity;

  const RemoveStock(this.id, this.quantity);

  @override
  List<Object?> get props => [id, quantity];
}

class LoadLowStockItems extends InventoryEvent {
  final int threshold;

  const LoadLowStockItems(this.threshold);

  @override
  List<Object?> get props => [threshold];
}

class LoadExpiredItems extends InventoryEvent {}

// Inventory States
abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => [];
}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  final List<InventoryItem> items;

  const InventoryLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class InventoryItemLoaded extends InventoryState {
  final InventoryItem item;

  const InventoryItemLoaded(this.item);

  @override
  List<Object?> get props => [item];
}

class InventoryError extends InventoryState {
  final String message;

  const InventoryError(this.message);

  @override
  List<Object?> get props => [message];
}

class InventoryOperationSuccess extends InventoryState {
  final String message;

  const InventoryOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class InventoryValueLoaded extends InventoryState {
  final double totalValue;

  const InventoryValueLoaded(this.totalValue);

  @override
  List<Object?> get props => [totalValue];
}

// Inventory Cubit
class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository _repository;
  List<InventoryItem> _allItems = [];
  static const int _defaultLowStockThreshold = 10;

  InventoryCubit(this._repository) : super(InventoryInitial());

  /// Load all inventory items
  Future<void> loadInventory() async {
    emit(InventoryLoading());

    final result = await _repository.getAll();

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (items) {
        _allItems = items;
        emit(InventoryLoaded(items));
      },
    );
  }

  /// Load inventory item by ID
  Future<void> loadInventoryItemById(int id) async {
    emit(InventoryLoading());

    final result = await _repository.getById(id);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (item) => emit(InventoryItemLoaded(item)),
    );
  }

  /// Load inventory by category
  Future<void> loadInventoryByCategory(InventoryCategory category) async {
    emit(InventoryLoading());

    final result = await _repository.getByCategory(category);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (items) => emit(InventoryLoaded(items)),
    );
  }

  /// Search inventory
  Future<void> searchInventory(String query) async {
    if (query.isEmpty) {
      emit(InventoryLoaded(_allItems));
      return;
    }

    emit(InventoryLoading());

    final result = await _repository.search(query);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (items) => emit(InventoryLoaded(items)),
    );
  }

  /// Create new inventory item
  Future<void> createInventoryItem(InventoryItem item) async {
    final result = await _repository.create(item);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (id) {
        emit(const InventoryOperationSuccess('Item added to inventory successfully'));
        loadInventory();
      },
    );
  }

  /// Update inventory item
  Future<void> updateInventoryItem(int id, InventoryItem item) async {
    final result = await _repository.update(id, item);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (success) {
        if (success) {
          emit(const InventoryOperationSuccess('Item updated successfully'));
          loadInventory();
        } else {
          emit(const InventoryError('Failed to update item'));
        }
      },
    );
  }

  /// Delete inventory item
  Future<void> deleteInventoryItem(int id) async {
    final result = await _repository.delete(id);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (success) {
        if (success) {
          emit(const InventoryOperationSuccess('Item deleted successfully'));
          loadInventory();
        } else {
          emit(const InventoryError('Failed to delete item'));
        }
      },
    );
  }

  /// Update inventory quantity directly
  Future<void> updateInventoryQuantity(int id, int quantity) async {
    final result = await _repository.updateQuantity(id, quantity);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (success) {
        if (success) {
          emit(const InventoryOperationSuccess('Quantity updated successfully'));
          loadInventory();
        } else {
          emit(const InventoryError('Failed to update quantity'));
        }
      },
    );
  }

  /// Add stock (increment)
  Future<void> addStock(int id, int quantity) async {
    final result = await _repository.addStock(id, quantity);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (success) {
        if (success) {
          emit(const InventoryOperationSuccess('Stock added successfully'));
          loadInventory();
        } else {
          emit(const InventoryError('Failed to add stock'));
        }
      },
    );
  }

  /// Remove stock (decrement)
  Future<void> removeStock(int id, int quantity) async {
    final result = await _repository.removeStock(id, quantity);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (success) {
        if (success) {
          emit(const InventoryOperationSuccess('Stock removed successfully'));
          loadInventory();
        } else {
          emit(const InventoryError('Failed to remove stock or insufficient quantity'));
        }
      },
    );
  }

  /// Load low stock items
  Future<void> loadLowStockItems([int threshold = _defaultLowStockThreshold]) async {
    emit(InventoryLoading());

    final result = await _repository.getLowStockItems(threshold);

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (items) => emit(InventoryLoaded(items)),
    );
  }

  /// Load expired items
  Future<void> loadExpiredItems() async {
    emit(InventoryLoading());

    final result = await _repository.getExpiredItems();

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (items) => emit(InventoryLoaded(items)),
    );
  }

  /// Get total inventory value
  Future<void> getTotalInventoryValue() async {
    final result = await _repository.getTotalValue();

    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (value) => emit(InventoryValueLoaded(value)),
    );
  }

  /// Get items count
  Future<int> getItemsCount() async {
    final result = await _repository.getCount();
    return result.fold((_) => 0, (count) => count);
  }

  /// Check if item is low stock
  bool isLowStock(InventoryItem item, [int threshold = _defaultLowStockThreshold]) {
    return item.quantity < threshold;
  }

  /// Check if item is expired
  bool isExpired(InventoryItem item) {
    final expirationDate = item.expirationDate;
    if (expirationDate == null) return false;
    return expirationDate.isBefore(DateTime.now());
  }

  /// Get items expiring soon (within days)
  Future<void> getExpiringSoonItems(int days) async {
    emit(InventoryLoading());
    
    final result = await _repository.getAll();
    
    result.fold(
      (failure) => emit(InventoryError(failure.message)),
      (items) {
        final expiringSoon = items.where((item) {
          final expirationDate = item.expirationDate;
          if (expirationDate == null) return false;
          final daysUntilExpiry = expirationDate.difference(DateTime.now()).inDays;
          return daysUntilExpiry >= 0 && daysUntilExpiry <= days;
        }).toList();
        emit(InventoryLoaded(expiringSoon));
      },
    );
  }
}
