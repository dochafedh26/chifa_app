import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

enum InventoryCategory { medicine, equipment, supplies }

class InventoryItem extends Equatable {
  final int? itemId;
  final String itemName;
  final InventoryCategory category;
  final int quantity;
  final double unitPrice;
  final DateTime? expirationDate;
  final DateTime purchaseDate;
  final String? supplierName;
  final DateTime createdAt;

  InventoryItem({
    this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    this.expirationDate,
    required this.purchaseDate,
    this.supplierName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'category': category.name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'expiration_date': expirationDate?.toIso8601String(),
      'purchase_date': purchaseDate.toIso8601String(),
      'supplier_name': supplierName,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      itemId: DbUtils.toInt(map['item_id']),
      itemName: DbUtils.toStringValue(map['item_name']),
      category: InventoryCategory.values.firstWhere(
        (e) =>
            e.name.toLowerCase() == map['category']?.toString().toLowerCase(),
        orElse: () => InventoryCategory.supplies,
      ),
      quantity: DbUtils.toInt(map['quantity']),
      unitPrice: DbUtils.toDouble(map['unit_price']),
      expirationDate: map['expiration_date'] != null
          ? (map['expiration_date'] is DateTime
                ? map['expiration_date'] as DateTime
                : DateTime.tryParse(map['expiration_date'].toString()))
          : null,
      purchaseDate: map['purchase_date'] is DateTime
          ? map['purchase_date'] as DateTime
          : (DateTime.tryParse(map['purchase_date']?.toString() ?? '') ??
                DateTime.now()),
      supplierName: map['supplier_name'] as String?,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : (DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now()),
    );
  }

  InventoryItem copyWith({
    int? itemId,
    String? itemName,
    InventoryCategory? category,
    int? quantity,
    double? unitPrice,
    DateTime? expirationDate,
    DateTime? purchaseDate,
    String? supplierName,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      expirationDate: expirationDate ?? this.expirationDate,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierName: supplierName ?? this.supplierName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    itemId,
    itemName,
    category,
    quantity,
    unitPrice,
    expirationDate,
    purchaseDate,
    supplierName,
    createdAt,
  ];
}
