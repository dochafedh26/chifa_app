import "package:equatable/equatable.dart";

class Treatment extends Equatable {
  final int? id;
  final int dutyPatientEntryId;
  final String medicationName;
  final String medicationDosage;
  final int durationDays;

  const Treatment({
    this.id,
    required this.dutyPatientEntryId,
    required this.medicationName,
    required this.medicationDosage,
    required this.durationDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'duty_patient_entry_id': dutyPatientEntryId,
      'medication_name': medicationName,
      'medication_dosage': medicationDosage,
      'duration_days': durationDays,
    };
  }

  factory Treatment.fromMap(Map<String, dynamic> map) {
    return Treatment(
      id: map['id'] as int?,
      dutyPatientEntryId: map['duty_patient_entry_id'] as int,
      medicationName: map['medication_name'] as String,
      medicationDosage: map['medication_dosage'] as String,
      durationDays: map['duration_days'] as int,
    );
  }

  Treatment copyWith({
    int? id,
    int? dutyPatientEntryId,
    String? medicationName,
    String? medicationDosage,
    int? durationDays,
  }) {
    return Treatment(
      id: id ?? this.id,
      dutyPatientEntryId: dutyPatientEntryId ?? this.dutyPatientEntryId,
      medicationName: medicationName ?? this.medicationName,
      medicationDosage: medicationDosage ?? this.medicationDosage,
      durationDays: durationDays ?? this.durationDays,
    );
  }

  @override
  List<Object?> get props => [id, dutyPatientEntryId, medicationName, medicationDosage, durationDays];
}