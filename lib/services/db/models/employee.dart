import "package:equatable/equatable.dart";

enum EmployeeRole { admin, doctor, nurse, patient }
enum AccessLevel { admin, doctor, nurse, patient }

class Employee extends Equatable {
  final int? employeeId;
  final String firstName;
  final String lastName;
  final EmployeeRole role;
  final String? specialization;
  final String email;
  final String? phone;
  final String password;
  final AccessLevel accessLevel;
  final int? patientId;
  final DateTime? workSchedule;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.specialization,
    required this.email,
    this.phone,
    required this.password,
    required this.accessLevel,
    this.patientId,
    this.workSchedule,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'employee_id': employeeId,
      'first_name': firstName,
      'last_name': lastName,
      'role': role.name,
      'specialization': specialization,
      'email': email,
      'phone': phone,
      'password': password,
      'access_level': accessLevel.name,
      'patient_id': patientId,
      'work_schedule': workSchedule?.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      employeeId: map['employee_id'] as int?,
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      role: EmployeeRole.values.firstWhere(
        (e) => e.name.toLowerCase() == map['role']?.toString().toLowerCase(),
        orElse: () => EmployeeRole.nurse,
      ),
      specialization: map['specialization'] as String?,
      email: map['email']?.toString() ?? '',
      phone: map['phone'] as String?,
      password: map['password']?.toString() ?? '',
      accessLevel: AccessLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == map['access_level']?.toString().toLowerCase(),
        orElse: () => AccessLevel.nurse,
      ),
      patientId: map['patient_id'] as int?,
      workSchedule: map['work_schedule'] != null
          ? (map['work_schedule'] is DateTime
              ? map['work_schedule'] as DateTime
              : DateTime.parse(map['work_schedule'] as String))
          : null,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] is DateTime
          ? map['updated_at'] as DateTime
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Employee copyWith({
    int? employeeId,
    String? firstName,
    String? lastName,
    EmployeeRole? role,
    String? specialization,
    String? email,
    String? phone,
    String? password,
    AccessLevel? accessLevel,
    int? patientId,
    DateTime? workSchedule,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      employeeId: employeeId ?? this.employeeId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      specialization: specialization ?? this.specialization,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      accessLevel: accessLevel ?? this.accessLevel,
      patientId: patientId ?? this.patientId,
      workSchedule: workSchedule ?? this.workSchedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        employeeId,
        firstName,
        lastName,
        role,
        specialization,
        email,
        phone,
        password,
        accessLevel,
        patientId,
        workSchedule,
        createdAt,
        updatedAt,
      ];
}
