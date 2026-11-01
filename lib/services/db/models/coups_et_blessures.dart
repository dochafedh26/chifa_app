import "package:equatable/equatable.dart";

class CertificatCoupsEtBlessures extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int? doctorId;
  final DateTime dateConsultation;
  final int? agePatient;
  final DateTime? dateFaits;
  final String? heureFaits;
  final String typeAccident; // e.g. 'Coups et blessures volontaires', etc.
  final String? autresAccident;
  final String? signesSubjectifs;
  final String? examenClinique;
  final bool necessiteTraitement;
  final int? arretDeTravailJours;
  final String? avisSpecialise;
  final int? ittJours; // Incapacité temporaire totale
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool needsSync;
  final bool isDeleted;

  CertificatCoupsEtBlessures({
    this.id,
    this.uuid,
    required this.patientId,
    this.doctorId,
    required this.dateConsultation,
    this.agePatient,
    this.dateFaits,
    this.heureFaits,
    required this.typeAccident,
    this.autresAccident,
    this.signesSubjectifs,
    this.examenClinique,
    this.necessiteTraitement = false,
    this.arretDeTravailJours,
    this.avisSpecialise,
    this.ittJours,
    required this.createdAt,
    this.updatedAt,
    this.needsSync = false,
    this.isDeleted = false,
  });

  factory CertificatCoupsEtBlessures.fromMap(Map<String, dynamic> map) {
    return CertificatCoupsEtBlessures(
      id: map['id'],
      uuid: map['uuid'],
      patientId: map['patient_id'],
      doctorId: map['doctor_id'],
      dateConsultation: map['date_consultation'] is DateTime
          ? map['date_consultation']
          : DateTime.tryParse(map['date_consultation'].toString()) ?? DateTime.now(),
      agePatient: map['age_patient'],
      dateFaits: map['date_faits'] != null
          ? (map['date_faits'] is DateTime
              ? map['date_faits']
              : DateTime.tryParse(map['date_faits'].toString()))
          : null,
      heureFaits: map['heure_faits'],
      typeAccident: map['type_accident'] ?? 'Coups et blessures volontaires',
      autresAccident: map['autres_accident'],
      signesSubjectifs: map['signes_subjectifs'],
      examenClinique: map['examen_clinique'],
      necessiteTraitement: (map['necessite_traitement'] == 1 || map['necessite_traitement'] == true),
      arretDeTravailJours: map['arret_de_travail_jours'],
      avisSpecialise: map['avis_specialise'],
      ittJours: map['itt_jours'],
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
      'date_consultation': dateConsultation.toIso8601String(),
      'age_patient': agePatient,
      'date_faits': dateFaits?.toIso8601String(),
      'heure_faits': heureFaits,
      'type_accident': typeAccident,
      'autres_accident': autresAccident,
      'signes_subjectifs': signesSubjectifs,
      'examen_clinique': examenClinique,
      'necessite_traitement': necessiteTraitement ? 1 : 0,
      'arret_de_travail_jours': arretDeTravailJours,
      'avis_specialise': avisSpecialise,
      'itt_jours': ittJours,
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
        dateConsultation,
        agePatient,
        dateFaits,
        heureFaits,
        typeAccident,
        autresAccident,
        signesSubjectifs,
        examenClinique,
        necessiteTraitement,
        arretDeTravailJours,
        avisSpecialise,
        ittJours,
        createdAt,
        updatedAt,
        needsSync,
        isDeleted,
      ];
}
