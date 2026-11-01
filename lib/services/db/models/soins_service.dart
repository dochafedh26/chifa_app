import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

class SoinsService extends Equatable {
  final int? id;
  final String? uuid;
  final String nom;
  final double price;
  final double doctorCommission;
  final bool needsSync;
  final bool isDeleted;

  const SoinsService({
    this.id,
    this.uuid,
    required this.nom,
    this.price = 0.0,
    this.doctorCommission = 0.0,
    this.needsSync = false,
    this.isDeleted = false,
  });

  factory SoinsService.fromMap(Map<String, dynamic> map) {
    return SoinsService(
      id: DbUtils.toInt(map['id']),
      uuid: map['uuid'] as String?,
      nom: DbUtils.toStringValue(map['nom']),
      price: DbUtils.toDouble(map['price'] ?? map['prix']),
      doctorCommission: DbUtils.toDouble(map['doctor_commission']),
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      'nom': nom,
      'price': price,
      'doctor_commission': doctorCommission,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  SoinsService copyWith({
    int? id,
    String? uuid,
    String? nom,
    double? price,
    double? doctorCommission,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return SoinsService(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nom: nom ?? this.nom,
      price: price ?? this.price,
      doctorCommission: doctorCommission ?? this.doctorCommission,
      needsSync: needsSync ?? this.needsSync,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        nom,
        price,
        doctorCommission,
        needsSync,
        isDeleted,
      ];
}
