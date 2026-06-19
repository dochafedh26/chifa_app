import "package:equatable/equatable.dart";

class Bilan extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int? doctorId;
  final String bilans;
  final DateTime createdAt;
  final int? medicalrecordId;
  final String? doctorName;
  final String? patientName;
  final bool needsSync;
  final bool isDeleted;

  Bilan({
    this.id,
    this.uuid,
    required this.patientId,
    this.doctorId,
    required this.bilans,
    DateTime? createdAt,
    this.medicalrecordId,
    this.doctorName,
    this.patientName,
    this.needsSync = false,
    this.isDeleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'bilans': bilans,
      'medicalrecord_id': medicalrecordId,
      'created_at': createdAt.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Bilan.fromMap(Map<String, dynamic> map) {
    return Bilan(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      patientId: map['patient_id'] as int,
      doctorId: map['doctor_id'] as int?,
      bilans: map['bilans'] as String,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'] as String),
      medicalrecordId: map['medicalrecord_id'] as int?,
      doctorName: map['doctorName'] as String?,
      patientName: map['patientName'] as String?,
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Bilan copyWith({
    int? id,
    String? uuid,
    int? patientId,
    int? doctorId,
    String? bilans,
    DateTime? createdAt,
    int? medicalrecordId,
    String? doctorName,
    String? patientName,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return Bilan(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      bilans: bilans ?? this.bilans,
      createdAt: createdAt ?? this.createdAt,
      medicalrecordId: medicalrecordId ?? this.medicalrecordId,
      doctorName: doctorName ?? this.doctorName,
      patientName: patientName ?? this.patientName,
      needsSync: needsSync ?? this.needsSync,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        patientId,
        doctorId,
        bilans,
        createdAt,
        medicalrecordId,
        doctorName,
        patientName,
        needsSync,
        isDeleted
      ];
}
