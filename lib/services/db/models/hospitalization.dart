import "package:equatable/equatable.dart";

enum HospitalizationStatus { active, discharged, transferred }

class Hospitalization extends Equatable {
  final int? id;
  final int patientId;
  final DateTime admissionDate;
  final DateTime? dischargeDate;
  final String? diagnosis;
  final String? roomNumber;
  final HospitalizationStatus status;

  const Hospitalization({
    this.id,
    required this.patientId,
    required this.admissionDate,
    this.dischargeDate,
    this.diagnosis,
    this.roomNumber,
    this.status = HospitalizationStatus.active,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'admission_date': admissionDate.toIso8601String(),
      'discharge_date': dischargeDate?.toIso8601String(),
      'diagnosis': diagnosis,
      'room_number': roomNumber,
      'status': status.name,
    };
  }

  factory Hospitalization.fromMap(Map<String, dynamic> map) {
    return Hospitalization(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      admissionDate: map['admission_date'] is DateTime
          ? map['admission_date'] as DateTime
          : DateTime.parse(map['admission_date'] as String),
      dischargeDate: map['discharge_date'] != null
          ? (map['discharge_date'] is DateTime
              ? map['discharge_date'] as DateTime
              : DateTime.parse(map['discharge_date'] as String))
          : null,
      diagnosis: map['diagnosis'] as String?,
      roomNumber: map['room_number'] as String?,
      status: HospitalizationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => HospitalizationStatus.active,
      ),
    );
  }

  Hospitalization copyWith({
    int? id,
    int? patientId,
    DateTime? admissionDate,
    DateTime? dischargeDate,
    String? diagnosis,
    String? roomNumber,
    HospitalizationStatus? status,
  }) {
    return Hospitalization(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      admissionDate: admissionDate ?? this.admissionDate,
      dischargeDate: dischargeDate ?? this.dischargeDate,
      diagnosis: diagnosis ?? this.diagnosis,
      roomNumber: roomNumber ?? this.roomNumber,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        patientId,
        admissionDate,
        dischargeDate,
        diagnosis,
        roomNumber,
        status,
      ];
}
