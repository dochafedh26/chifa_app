import "package:equatable/equatable.dart";

class SoinsService extends Equatable {
  final int? id;
  final String? uuid;
  final String nom;
  final bool needsSync;
  final bool isDeleted;

  SoinsService({
    this.id,
    this.uuid,
    required this.nom,
    this.needsSync = false,
    this.isDeleted = false,
  });

  factory SoinsService.fromMap(Map<String, dynamic> map) {
    return SoinsService(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      nom: map['nom'] as String,
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nom': nom,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [id, uuid, nom, needsSync, isDeleted];
}
