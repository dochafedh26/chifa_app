import "package:equatable/equatable.dart";

enum PatientStatus { waiting, current, done }

enum Gender { male, female, other }

class Patient extends Equatable {
  final int? patientId;
  final String? uuid;
  final String firstName;
  final String lastName;
  final Gender gender;
  final DateTime dateOfBirth;
  final String? phone;
  final String atcd;
  final String? source;
  final String? email;
  final String? nationalId;
  final String? address;
  final DateTime createdAt;
  final PatientStatus status;
  final int medicalRecordsCount;
  final List<String> categories;
  final String? suiviPathologies;
  final bool needsSync;
  final bool isDeleted;

  Patient({
    this.patientId,
    this.uuid,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    this.phone,
    this.atcd = '',
    this.source,
    this.email,
    this.nationalId,
    this.address,
    DateTime? createdAt,
    this.status = PatientStatus.waiting,
    this.medicalRecordsCount = 0,
    this.categories = const [],
    this.suiviPathologies,
    this.needsSync = false,
    this.isDeleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    final monthDiff = now.month - dateOfBirth.month;
    if (monthDiff < 0 || (monthDiff == 0 && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'patient_id': patientId,
      'uuid': uuid,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender.name,
      'date_of_birth':
          '${dateOfBirth.year}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
      'phone': phone,
      'atcd': atcd,
      'source': source,
      'email': email,
      'national_id': nationalId,
      'address': address,
      'status': status.name,
      'medical_records_count': medicalRecordsCount,
      'categories': categories.join(','),
      'suivi_pathologies': suiviPathologies,
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patient_id'] as int?,
      uuid: map['uuid'] as String?,
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      gender: Gender.values.firstWhere(
        (e) => e.name.toLowerCase() == map['gender']?.toString().toLowerCase(),
        orElse: () => Gender.other,
      ),
      dateOfBirth: map['date_of_birth'] is DateTime
          ? map['date_of_birth'] as DateTime
          : DateTime.parse(map['date_of_birth'] as String),
      phone: map['phone'] as String?,
      atcd: map['atcd'] as String? ?? '',
      source: map['source'] as String?,
      email: map['email'] as String?,
      nationalId: map['national_id'] as String?,
      address: map['address'] as String?,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'] as String),
      status: PatientStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == map['status']?.toString().toLowerCase(),
        orElse: () => PatientStatus.waiting,
      ),
      medicalRecordsCount:
          int.tryParse(map['medical_records_count']?.toString() ?? '0') ?? 0,
      categories:
          (map['categories'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      suiviPathologies: map['suivi_pathologies'] as String?,
      needsSync: (map['needs_sync'] == 1),
      isDeleted: (map['is_deleted'] == 1),
    );
  }

  Patient copyWith({
    int? patientId,
    String? uuid,
    String? firstName,
    String? lastName,
    Gender? gender,
    DateTime? dateOfBirth,
    String? phone,
    String? atcd,
    String? source,
    String? email,
    String? nationalId,
    String? address,
    DateTime? createdAt,
    PatientStatus? status,
    int? medicalRecordsCount,
    List<String>? categories,
    String? suiviPathologies,
    bool? needsSync,
    bool? isDeleted,
  }) {
    return Patient(
      patientId: patientId ?? this.patientId,
      uuid: uuid ?? this.uuid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      atcd: atcd ?? this.atcd,
      source: source ?? this.source,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      medicalRecordsCount: medicalRecordsCount ?? this.medicalRecordsCount,
      categories: categories ?? this.categories,
      suiviPathologies: suiviPathologies ?? this.suiviPathologies,
      needsSync: needsSync ?? this.needsSync,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
    patientId,
    uuid,
    firstName,
    lastName,
    gender,
    dateOfBirth,
    phone,
    atcd,
    source,
    email,
    nationalId,
    address,
    createdAt,
    status,
    medicalRecordsCount,
    categories,
    suiviPathologies,
    needsSync,
    isDeleted,
  ];
}
