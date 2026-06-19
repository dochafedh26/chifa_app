import "package:equatable/equatable.dart";

class Medication extends Equatable {
  final int? medicationId;
  final String name;
  final int? stock;

  const Medication({
    this.medicationId,
    required this.name,
    this.stock,
  });

  Map<String, dynamic> toMap() {
    return {
      'medication_id': medicationId,
      'name': name,
      'stock': stock,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      medicationId: map['medication_id'] as int?,
      name: map['name'] as String,
      stock: map['stock'] as int?,
    );
  }

  Medication copyWith({
    int? medicationId,
    String? name,
    int? stock,
  }) {
    return Medication(
      medicationId: medicationId ?? this.medicationId,
      name: name ?? this.name,
      stock: stock ?? this.stock,
    );
  }

  @override
  List<Object?> get props => [medicationId, name, stock];
}
