import "package:equatable/equatable.dart";

class ArretDeTravail extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int doctorId;
  final String type;
  final String motif;
  final DateTime dateDebut;
  final int jours;
  final DateTime dateReprise;
  final DateTime dateCreation;
  final bool needsSync;
  final bool isDeleted;

  ArretDeTravail({
    this.id,
    this.uuid,
    required this.patientId,
    required this.doctorId,
    required this.type,
    required this.motif,
    required this.dateDebut,
    required this.jours,
    required this.dateReprise,
    DateTime? dateCreation,
    this.needsSync = false,
    this.isDeleted = false,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'type': type,
      'motif': motif,
      'date_debut': dateDebut.toIso8601String(),
      'jours': jours,
      'date_reprise': dateReprise.toIso8601String(),
      'date_creation': dateCreation.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory ArretDeTravail.fromMap(Map<String, dynamic> map) {
    return ArretDeTravail(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      patientId: map['patient_id'] as int,
      doctorId: map['doctor_id'] as int,
      type: map['type'] as String,
      motif: map['motif'] as String,
      dateDebut: map['date_debut'] is DateTime
          ? map['date_debut'] as DateTime
          : DateTime.parse(map['date_debut'] as String),
      jours: map['jours'] as int,
      dateReprise: map['date_reprise'] is DateTime
          ? map['date_reprise'] as DateTime
          : DateTime.parse(map['date_reprise'] as String),
      dateCreation: map['date_creation'] is DateTime
          ? map['date_creation'] as DateTime
          : DateTime.parse(map['date_creation'] as String),
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  ArretDeTravail copyWith({
    int? id,
    String? uuid,
    int? patientId,
    int? doctorId,
    String? type,
    String? motif,
    DateTime? dateDebut,
    int? jours,
    DateTime? dateReprise,
    DateTime? dateCreation,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return ArretDeTravail(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      type: type ?? this.type,
      motif: motif ?? this.motif,
      dateDebut: dateDebut ?? this.dateDebut,
      jours: jours ?? this.jours,
      dateReprise: dateReprise ?? this.dateReprise,
      dateCreation: dateCreation ?? this.dateCreation,
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
        type,
        motif,
        dateDebut,
        jours,
        dateReprise,
        dateCreation,
        needsSync,
        isDeleted,
      ];
}
