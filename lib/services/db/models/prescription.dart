import "package:equatable/equatable.dart";

class Prescription extends Equatable {
  final int? id;
  final String? uuid;
  final String prescription;
  final bool needsSync;
  final bool isDeleted;

  const Prescription({
    this.id,
    this.uuid,
    required this.prescription,
    this.needsSync = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'prescription': prescription,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      prescription: map['prescription'] as String,
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Prescription copyWith({
    int? id,
    String? uuid,
    String? prescription,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return Prescription(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      prescription: prescription ?? this.prescription,
      needsSync: needsSync ?? this.needsSync,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [id, uuid, prescription, needsSync, isDeleted];
}
