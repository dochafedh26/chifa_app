import "package:equatable/equatable.dart";

enum AppointmentStatus { scheduled, waitingRoom, completed, cancelled }

extension AppointmentStatusX on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'Programmé';
      case AppointmentStatus.waitingRoom:
        return 'En salle d\'attente';
      case AppointmentStatus.completed:
        return 'Terminé';
      case AppointmentStatus.cancelled:
        return 'Annulé';
    }
  }
}

class Appointment extends Equatable {
  final int? appointmentId;
  final String? uuid;
  final int patientId;
  final int doctorId;
  final DateTime appointmentDate;
  final AppointmentStatus status;
  final String? notes;
  final bool needsSync;
  final bool isDeleted;

  const Appointment({
    this.appointmentId,
    this.uuid,
    required this.patientId,
    required this.doctorId,
    required this.appointmentDate,
    this.status = AppointmentStatus.scheduled,
    this.notes,
    this.needsSync = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'appointment_id': appointmentId,
      'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'appointment_date': appointmentDate.toIso8601String(),
      'status': status.name,
      'notes': notes,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      appointmentId: map['appointment_id'] as int?,
      uuid: map['uuid'] as String?,
      patientId: map['patient_id'] as int,
      doctorId: map['doctor_id'] as int,
      appointmentDate: map['appointment_date'] is DateTime
          ? map['appointment_date'] as DateTime
          : DateTime.parse(map['appointment_date'] as String),
      status: AppointmentStatus.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (map['status'] as String?)
                ?.toLowerCase()
                .replaceAll('_', '')
                .replaceAll(' ', ''),
        orElse: () => AppointmentStatus.scheduled,
      ),
      notes: map['notes'] as String?,
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Appointment copyWith({
    int? appointmentId,
    String? uuid,
    int? patientId,
    int? doctorId,
    DateTime? appointmentDate,
    AppointmentStatus? status,
    String? notes,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return Appointment(
      appointmentId: appointmentId ?? this.appointmentId,
      uuid: uuid ?? this.uuid,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      needsSync: needsSync ?? this.needsSync,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        appointmentId,
        uuid,
        patientId,
        doctorId,
        appointmentDate,
        status,
        notes,
        needsSync,
        isDeleted,
      ];
}
