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
  final bool isActive;
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
    this.isActive = true,
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
      'is_active': isActive ? 1 : 0,
      'work_schedule': workSchedule?.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      employeeId: map['employee_id'] is int
          ? map['employee_id'] as int
          : int.tryParse(map['employee_id']?.toString() ?? ''),
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      role: EmployeeRole.values.firstWhere(
        (e) => e.name.toLowerCase() == map['role']?.toString().toLowerCase(),
        orElse: () => EmployeeRole.nurse,
      ),
      specialization: map['specialization']?.toString(),
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString(),
      password: map['password']?.toString() ?? '',
      accessLevel: AccessLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == map['access_level']?.toString().toLowerCase(),
        orElse: () => AccessLevel.nurse,
      ),
      patientId: map['patient_id'] is int
          ? map['patient_id'] as int
          : int.tryParse(map['patient_id']?.toString() ?? ''),
      isActive: map['is_active'] == null ||
          map['is_active'] == 1 ||
          map['is_active'] == true ||
          map['is_active'] == '1',
      workSchedule: map['work_schedule'] != null
          ? (map['work_schedule'] is DateTime
              ? map['work_schedule'] as DateTime
              : DateTime.tryParse(map['work_schedule'].toString()))
          : null,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : (DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.now()),
      updatedAt: map['updated_at'] is DateTime
          ? map['updated_at'] as DateTime
          : (DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
              DateTime.now()),
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
    bool? isActive,
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
      isActive: isActive ?? this.isActive,
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
        isActive,
        workSchedule,
        createdAt,
        updatedAt,
      ];
}
