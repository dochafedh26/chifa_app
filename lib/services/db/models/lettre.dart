import "package:equatable/equatable.dart";

class Lettre extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int? doctorId;
  final String? atcd;
  final String motifConsultation;
  final String? examenClinique;
  final String motifLettre;
  final DateTime createdAt;
  final bool needsSync;
  final bool isDeleted;

  Lettre({
    this.id,
    this.uuid,
    required this.patientId,
    this.doctorId,
    this.atcd,
    required this.motifConsultation,
    this.examenClinique,
    required this.motifLettre,
    DateTime? createdAt,
    this.needsSync = false,
    this.isDeleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'atcd': atcd,
      'motif_consultation': motifConsultation,
      'examen_clinique': examenClinique,
      'motif_lettre': motifLettre,
      'created_at': createdAt.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Lettre.fromMap(Map<String, dynamic> map) {
    return Lettre(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      patientId: map['patient_id'] as int,
      doctorId: map['doctor_id'] as int?,
      atcd: map['atcd'] as String?,
      motifConsultation: map['motif_consultation'] as String,
      examenClinique: map['examen_clinique'] as String?,
      motifLettre: map['motif_lettre'] as String,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'] as String),
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Lettre copyWith({
    int? id,
    String? uuid,
    int? patientId,
    int? doctorId,
    String? atcd,
    String? motifConsultation,
    String? examenClinique,
    String? motifLettre,
    DateTime? createdAt,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return Lettre(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      atcd: atcd ?? this.atcd,
      motifConsultation: motifConsultation ?? this.motifConsultation,
      examenClinique: examenClinique ?? this.examenClinique,
      motifLettre: motifLettre ?? this.motifLettre,
      createdAt: createdAt ?? this.createdAt,
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
        atcd,
        motifConsultation,
        examenClinique,
        motifLettre,
        createdAt,
        needsSync,
        isDeleted,
      ];
}
