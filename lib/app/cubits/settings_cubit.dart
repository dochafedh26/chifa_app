import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Settings Events
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

// User Management Events
class LoadUsers extends SettingsEvent {}

class LoadUserById extends SettingsEvent {
  final int id;

  const LoadUserById(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadDoctors extends SettingsEvent {}

class LoadUsersByRole extends SettingsEvent {
  final EmployeeRole role;

  const LoadUsersByRole(this.role);

  @override
  List<Object?> get props => [role];
}

class CreateUser extends SettingsEvent {
  final Employee user;

  const CreateUser(this.user);

  @override
  List<Object?> get props => [user];
}

class UpdateUser extends SettingsEvent {
  final int id;
  final Employee user;

  const UpdateUser(this.id, this.user);

  @override
  List<Object?> get props => [id, user];
}

class DeleteUser extends SettingsEvent {
  final int id;

  const DeleteUser(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateUserPassword extends SettingsEvent {
  final int id;
  final String newPassword;

  const UpdateUserPassword(this.id, this.newPassword);

  @override
  List<Object?> get props => [id, newPassword];
}

// Settings Events
class LoadSettings extends SettingsEvent {}

class UpdateClinicInfo extends SettingsEvent {
  final ClinicSettings settings;

  const UpdateClinicInfo(this.settings);

  @override
  List<Object?> get props => [settings];
}

class UpdateTheme extends SettingsEvent {
  final String theme;

  const UpdateTheme(this.theme);

  @override
  List<Object?> get props => [theme];
}

class UpdateLanguage extends SettingsEvent {
  final String language;

  const UpdateLanguage(this.language);

  @override
  List<Object?> get props => [language];
}

// Settings States
abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class UsersLoaded extends SettingsState {
  final List<Employee> users;

  const UsersLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UserLoaded extends SettingsState {
  final Employee user;

  const UserLoaded(this.user);

  @override
  List<Object?> get props => [user];
}

class DoctorsLoaded extends SettingsState {
  final List<Employee> doctors;

  const DoctorsLoaded(this.doctors);

  @override
  List<Object?> get props => [doctors];
}

class SettingsLoaded extends SettingsState {
  final ClinicSettings settings;

  const SettingsLoaded(this.settings);

  @override
  List<Object?> get props => [settings];
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

class SettingsOperationSuccess extends SettingsState {
  final String message;

  const SettingsOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Clinic Settings Model
class ClinicSettings extends Equatable {
  final String clinicName;
  final String clinicAddress;
  final String clinicPhone;
  final String clinicEmail;
  final String clinicLogo;
  final String doctorName;
  final String doctorSpecialization;
  final String taxId;
  final String currency;
  final String language;
  final String theme;

  const ClinicSettings({
    this.clinicName = 'Clinic',
    this.clinicAddress = '',
    this.clinicPhone = '',
    this.clinicEmail = '',
    this.clinicLogo = '',
    this.doctorName = '',
    this.doctorSpecialization = 'General Practice',
    this.taxId = '',
    this.currency = 'DZD',
    this.language = 'fr',
    this.theme = 'light',
  });

  Map<String, dynamic> toMap() {
    return {
      'clinic_name': clinicName,
      'clinic_address': clinicAddress,
      'clinic_phone': clinicPhone,
      'clinic_email': clinicEmail,
      'clinic_logo': clinicLogo,
      'doctor_name': doctorName,
      'doctor_specialization': doctorSpecialization,
      'tax_id': taxId,
      'currency': currency,
      'language': language,
      'theme': theme,
    };
  }

  factory ClinicSettings.fromMap(Map<String, dynamic> map) {
    return ClinicSettings(
      clinicName: map['clinic_name'] as String? ?? 'Clinic',
      clinicAddress: map['clinic_address'] as String? ?? '',
      clinicPhone: map['clinic_phone'] as String? ?? '',
      clinicEmail: map['clinic_email'] as String? ?? '',
      clinicLogo: map['clinic_logo'] as String? ?? '',
      doctorName: map['doctor_name'] as String? ?? '',
      doctorSpecialization: map['doctor_specialization'] as String? ?? 'General Practice',
      taxId: map['tax_id'] as String? ?? '',
      currency: map['currency'] as String? ?? 'DZD',
      language: map['language'] as String? ?? 'fr',
      theme: map['theme'] as String? ?? 'light',
    );
  }

  ClinicSettings copyWith({
    String? clinicName,
    String? clinicAddress,
    String? clinicPhone,
    String? clinicEmail,
    String? clinicLogo,
    String? doctorName,
    String? doctorSpecialization,
    String? taxId,
    String? currency,
    String? language,
    String? theme,
  }) {
    return ClinicSettings(
      clinicName: clinicName ?? this.clinicName,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      clinicPhone: clinicPhone ?? this.clinicPhone,
      clinicEmail: clinicEmail ?? this.clinicEmail,
      clinicLogo: clinicLogo ?? this.clinicLogo,
      doctorName: doctorName ?? this.doctorName,
      doctorSpecialization: doctorSpecialization ?? this.doctorSpecialization,
      taxId: taxId ?? this.taxId,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }

  @override
  List<Object?> get props => [
        clinicName,
        clinicAddress,
        clinicPhone,
        clinicEmail,
        clinicLogo,
        doctorName,
        doctorSpecialization,
        taxId,
        currency,
        language,
        theme,
      ];
}

// Settings Cubit
class SettingsCubit extends Cubit<SettingsState> {
  final AuthRepository _authRepository;
  List<Employee> _allUsers = [];
  ClinicSettings _settings = const ClinicSettings();

  SettingsCubit(this._authRepository) : super(SettingsInitial());

  /// Get current settings
  ClinicSettings get settings => _settings;

  /// Load all users
  Future<void> loadUsers() async {
    emit(SettingsLoading());

    final result = await _authRepository.getAllEmployees();

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (users) {
        _allUsers = users;
        emit(UsersLoaded(users));
      },
    );
  }

  /// Load user by ID
  Future<void> loadUserById(int id) async {
    emit(SettingsLoading());

    final result = await _authRepository.getEmployeeById(id);

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (user) => emit(UserLoaded(user)),
    );
  }

  /// Load all doctors
  Future<void> loadDoctors() async {
    emit(SettingsLoading());

    final result = await _authRepository.getAllDoctors();

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (doctors) => emit(DoctorsLoaded(doctors)),
    );
  }

  /// Load users by role
  Future<void> loadUsersByRole(EmployeeRole role) async {
    emit(SettingsLoading());

    final result = await _authRepository.getEmployeesByRole(role);

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (users) => emit(UsersLoaded(users)),
    );
  }

  /// Create new user
  Future<void> createUser(Employee user) async {
    final result = await _authRepository.createEmployee(user);

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (id) {
        emit(const SettingsOperationSuccess('User created successfully'));
        loadUsers();
      },
    );
  }

  /// Update user
  Future<void> updateUser(int id, Employee user) async {
    final result = await _authRepository.updateEmployee(id, user);

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (success) {
        if (success) {
          emit(const SettingsOperationSuccess('User updated successfully'));
          loadUsers();
        } else {
          emit(const SettingsError('Failed to update user'));
        }
      },
    );
  }

  /// Delete user
  Future<void> deleteUser(int id) async {
    final result = await _authRepository.deleteEmployee(id);

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (success) {
        if (success) {
          emit(const SettingsOperationSuccess('User deleted successfully'));
          loadUsers();
        } else {
          emit(const SettingsError('Failed to delete user'));
        }
      },
    );
  }

  /// Update user password
  Future<void> updateUserPassword(int id, String newPassword) async {
    final result = await _authRepository.updatePassword(id, newPassword);

    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (success) {
        if (success) {
          emit(const SettingsOperationSuccess('Password updated successfully'));
        } else {
          emit(const SettingsError('Failed to update password'));
        }
      },
    );
  }

  /// Load settings
  Future<void> loadSettings() async {
    emit(SettingsLoaded(_settings));
  }

  /// Update clinic info
  Future<void> updateClinicInfo(ClinicSettings settings) async {
    _settings = settings;
    emit(SettingsLoaded(settings));
    emit(const SettingsOperationSuccess('Clinic information updated'));
  }

  /// Update theme
  Future<void> updateTheme(String theme) async {
    _settings = _settings.copyWith(theme: theme);
    emit(SettingsLoaded(_settings));
    emit(const SettingsOperationSuccess('Theme updated'));
  }

  /// Update language
  Future<void> updateLanguage(String language) async {
    _settings = _settings.copyWith(language: language);
    emit(SettingsLoaded(_settings));
    emit(const SettingsOperationSuccess('Language updated'));
  }

  /// Search users
  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      emit(UsersLoaded(_allUsers));
      return;
    }

    emit(SettingsLoading());

    final filteredUsers = _allUsers.where((user) {
      return user.firstName.toLowerCase().contains(query.toLowerCase()) ||
          user.lastName.toLowerCase().contains(query.toLowerCase()) ||
          user.email.toLowerCase().contains(query.toLowerCase());
    }).toList();

    emit(UsersLoaded(filteredUsers));
  }

  /// Get users count
  int get usersCount => _allUsers.length;

  /// Get doctors count
  int get doctorsCount => _allUsers.where((u) => u.role == EmployeeRole.doctor).length;

  /// Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate password strength
  bool isValidPassword(String password) {
    return password.length >= 8;
  }
}
