import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

class MedicalRecord extends Equatable {
  final int? id; // mapped to record_id
  final String? uuid;
  final int patientId; // mapped to patient_id
  final int doctorId; // mapped to doctor_id
  final DateTime recordDate; // mapped to record_date
  final String? motif; // mapped to motif
  final String details; // mapped to details
  final String? diagnostic; // mapped to diagnostic
  final String? prescriptions; // mapped to prescriptions
  final double? weight; // mapped to weight
  final double? temperature; // mapped to temperature
  final String? tensionArterielle; // mapped to tension_arterielle
  final int? frequenceCardiaque; // mapped to frequence_cardiaque
  final int? spao2; // mapped to spao2
  final String recordTimer; // mapped to record_timer
  final String? patientFirstName; // joined from patients table
  final String? patientLastName; // joined from patients table
  final String? soins; // joined from soins_medicaux via GROUP_CONCAT
  final bool needsSync;
  final bool isDeleted;

  MedicalRecord({
    this.id,
    this.uuid,
    required this.patientId,
    required this.doctorId,
    DateTime? recordDate,
    this.motif,
    required this.details,
    this.diagnostic,
    this.prescriptions,
    this.weight,
    this.temperature,
    this.tensionArterielle,
    this.frequenceCardiaque,
    this.spao2,
    required this.recordTimer,
    this.patientFirstName,
    this.patientLastName,
    this.soins,
    this.needsSync = false,
    this.isDeleted = false,
  }) : recordDate = recordDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'record_id': id,
      'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'record_date': recordDate.toIso8601String(),
      'motif': motif,
      'details': details,
      'diagnostic': diagnostic,
      'prescriptions': prescriptions,
      'weight': weight,
      'temperature': temperature,
      'tension_arterielle': tensionArterielle,
      'frequence_cardiaque': frequenceCardiaque,
      'spao2': spao2,
      'record_timer': recordTimer,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      if (patientFirstName != null) 'first_name': patientFirstName,
      if (patientLastName != null) 'last_name': patientLastName,
      if (soins != null) 'soins_text': soins,
    };
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    return MedicalRecord(
      id: DbUtils.toInt(map['record_id']),
      uuid: map['uuid'] as String?,
      patientId: DbUtils.toInt(map['patient_id']),
      doctorId: DbUtils.toInt(map['doctor_id']),
      recordDate: map['record_date'] is DateTime
          ? map['record_date'] as DateTime
          : (DateTime.tryParse(map['record_date']?.toString() ?? '') ??
                DateTime.now()),
      motif: map['motif'] as String?,
      details: map['details'] as String? ?? '',
      diagnostic: map['diagnostic'] as String?,
      prescriptions: map['prescriptions'] as String?,
      weight: DbUtils.toDouble(map['weight']),
      temperature: DbUtils.toDouble(map['temperature']),
      tensionArterielle: map['tension_arterielle'] as String?,
      frequenceCardiaque: DbUtils.toInt(map['frequence_cardiaque']),
      spao2: DbUtils.toInt(map['spao2']),
      recordTimer: map['record_timer'] as String? ?? '00:00:00',
      patientFirstName: map['first_name'] as String?,
      patientLastName: map['last_name'] as String?,
      soins: map['soins_text'] as String?,
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  MedicalRecord copyWith({
    int? id,
    String? uuid,
    int? patientId,
    int? doctorId,
    DateTime? recordDate,
    String? motif,
    String? details,
    String? diagnostic,
    String? prescriptions,
    double? weight,
    double? temperature,
    String? tensionArterielle,
    int? frequenceCardiaque,
    int? spao2,
    String? recordTimer,
    String? patientFirstName,
    String? patientLastName,
    String? soins,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      recordDate: recordDate ?? this.recordDate,
      motif: motif ?? this.motif,
      details: details ?? this.details,
      diagnostic: diagnostic ?? this.diagnostic,
      prescriptions: prescriptions ?? this.prescriptions,
      weight: weight ?? this.weight,
      temperature: temperature ?? this.temperature,
      tensionArterielle: tensionArterielle ?? this.tensionArterielle,
      frequenceCardiaque: frequenceCardiaque ?? this.frequenceCardiaque,
      spao2: spao2 ?? this.spao2,
      recordTimer: recordTimer ?? this.recordTimer,
      patientFirstName: patientFirstName ?? this.patientFirstName,
      patientLastName: patientLastName ?? this.patientLastName,
      soins: soins ?? this.soins,
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
    recordDate,
    motif,
    details,
    diagnostic,
    prescriptions,
    weight,
    temperature,
    tensionArterielle,
    frequenceCardiaque,
    spao2,
    recordTimer,
    patientFirstName,
    patientLastName,
    soins,
    needsSync,
    isDeleted,
  ];
}
