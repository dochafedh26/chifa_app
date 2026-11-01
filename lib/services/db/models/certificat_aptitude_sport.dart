import "package:equatable/equatable.dart";

class CertificatAptitudeSport extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int? doctorId;
  final String sport;
  final String typePratique;
  final String? examenClinique;
  final String? remarques;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool needsSync;
  final String? sourceId;
  final bool isDeleted;

  const CertificatAptitudeSport({
    this.id,
    this.uuid,
    required this.patientId,
    this.doctorId,
    this.sport = 'Toutes disciplines sportives',
    this.typePratique = 'Entraînement et Loisir',
    this.examenClinique,
    this.remarques,
    required this.createdAt,
    this.updatedAt,
    this.needsSync = false,
    this.sourceId = 'local_server',
    this.isDeleted = false,
  });

  factory CertificatAptitudeSport.fromMap(Map<String, dynamic> map) {
    return CertificatAptitudeSport(
      id: map['id'],
      uuid: map['uuid'],
      patientId: map['patient_id'] is int
          ? map['patient_id']
          : int.tryParse(map['patient_id']?.toString() ?? '0') ?? 0,
      doctorId: map['doctor_id'] != null
          ? (map['doctor_id'] is int
              ? map['doctor_id']
              : int.tryParse(map['doctor_id'].toString()))
          : null,
      sport: map['sport'] ?? 'Toutes disciplines sportives',
      typePratique: map['type_pratique'] ?? 'Entraînement et Loisir',
      examenClinique: map['examen_clinique'],
      remarques: map['remarques'],
      createdAt: map['created_at'] is DateTime
          ? map['created_at']
          : DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
              ? map['updated_at']
              : DateTime.tryParse(map['updated_at'].toString()))
          : null,
      needsSync: (map['needs_sync'] == 1 || map['needs_sync'] == true),
      sourceId: map['source_id']?.toString(),
      isDeleted: (map['is_deleted'] == 1 || map['is_deleted'] == true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'sport': sport,
      'type_pratique': typePratique,
      'examen_clinique': examenClinique,
      'remarques': remarques,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
      if (sourceId != null) 'source_id': sourceId,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        patientId,
        doctorId,
        sport,
        typePratique,
        examenClinique,
        remarques,
        createdAt,
        updatedAt,
        needsSync,
        sourceId,
        isDeleted,
      ];
}

