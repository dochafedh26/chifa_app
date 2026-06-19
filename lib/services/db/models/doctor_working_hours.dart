import "package:equatable/equatable.dart";
import "package:flutter/material.dart";

class DoctorWorkingHours extends Equatable {
  final int? id;
  final String? uuid;
  final int doctorId;
  final DateTime workingDate;
  final String startTime; // "HH:mm:ss"
  final String endTime; // "HH:mm:ss"
  final bool needsSync;
  final bool isDeleted;

  const DoctorWorkingHours({
    this.id,
    this.uuid,
    required this.doctorId,
    required this.workingDate,
    required this.startTime,
    required this.endTime,
    this.needsSync = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'doctor_id': doctorId,
      'working_date': workingDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory DoctorWorkingHours.fromMap(Map<String, dynamic> map) {
    String formatTime(dynamic value) {
      if (value is String) return value;
      if (value is Duration) {
        final hours = value.inHours.toString().padLeft(2, '0');
        final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
        return '$hours:$minutes:$seconds';
      }
      return value.toString();
    }

    return DoctorWorkingHours(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      doctorId: map['doctor_id'] as int,
      workingDate: map['working_date'] is DateTime
          ? map['working_date'] as DateTime
          : DateTime.parse(map['working_date'] as String),
      startTime: formatTime(map['start_time']),
      endTime: formatTime(map['end_time']),
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  DoctorWorkingHours copyWith({
    int? id,
    String? uuid,
    int? doctorId,
    DateTime? workingDate,
    String? startTime,
    String? endTime,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return DoctorWorkingHours(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      doctorId: doctorId ?? this.doctorId,
      workingDate: workingDate ?? this.workingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      needsSync: needsSync ?? this.needsSync,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
    id,
    uuid,
    doctorId,
    workingDate,
    startTime,
    endTime,
    needsSync,
    isDeleted,
  ];

  // Helper to get TimeOfDay from string
  TimeOfDay get stTime {
    final parts = startTime.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  TimeOfDay get enTime {
    final parts = endTime.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
