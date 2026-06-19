import "package:equatable/equatable.dart";

class CertificatPrenuptial extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int? doctorId;
  final String? groupeSanguin;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool needsSync;
  final bool isDeleted;

  CertificatPrenuptial({
    this.id,
    this.uuid,
    required this.patientId,
    this.doctorId,
    this.groupeSanguin,
    required this.createdAt,
    this.updatedAt,
    this.needsSync = false,
    this.isDeleted = false,
  });

  factory CertificatPrenuptial.fromMap(Map<String, dynamic> map) {
    return CertificatPrenuptial(
      id: map['id'],
      uuid: map['uuid'],
      patientId: map['patient_id'],
      doctorId: map['doctor_id'],
      groupeSanguin: map['groupe_sanguin'],
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
      'groupe_sanguin': groupeSanguin,
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
        groupeSanguin,
        createdAt,
        updatedAt,
        needsSync,
        isDeleted
      ];
}
