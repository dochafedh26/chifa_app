import "package:equatable/equatable.dart";

class CertificatBonneSante extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int? doctorId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool needsSync;
  final bool isDeleted;

  CertificatBonneSante({
    this.id,
    this.uuid,
    required this.patientId,
    this.doctorId,
    required this.createdAt,
    this.updatedAt,
    this.needsSync = false,
    this.isDeleted = false,
  });

  factory CertificatBonneSante.fromMap(Map<String, dynamic> map) {
    return CertificatBonneSante(
      id: map['id'],
      uuid: map['uuid'],
      patientId: map['patient_id'],
      doctorId: map['doctor_id'],
      createdAt: map['created_at'] is DateTime
          ? map['created_at']
          : DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
                ? map['updated_at']
                : DateTime.tryParse(map['updated_at'].toString()))
          : null,
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        patientId,
        doctorId,
        createdAt,
        updatedAt,
        needsSync,
        isDeleted
      ];
}
