import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Patient Events
abstract class PatientEvent extends Equatable {
  const PatientEvent();

  @override
  List<Object?> get props => [];
}

class LoadPatients extends PatientEvent {}

class LoadPatientById extends PatientEvent {
  final int id;

  const LoadPatientById(this.id);

  @override
  List<Object?> get props => [id];
}

class SearchPatients extends PatientEvent {
  final String query;

  const SearchPatients(this.query);

  @override
  List<Object?> get props => [query];
}

class CreatePatient extends PatientEvent {
  final Patient patient;

  const CreatePatient(this.patient);

  @override
  List<Object?> get props => [patient];
}

class UpdatePatient extends PatientEvent {
  final int id;
  final Patient patient;

  const UpdatePatient(this.id, this.patient);

  @override
  List<Object?> get props => [id, patient];
}

class DeletePatient extends PatientEvent {
  final int id;

  const DeletePatient(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdatePatientStatusEvent extends PatientEvent {
  final int id;
  final PatientStatus status;

  const UpdatePatientStatusEvent(this.id, this.status);

  @override
  List<Object?> get props => [id, status];
}

// Patient State
class PatientState extends Equatable {
  final List<Patient> patients;
  final List<String> categories;
  final Patient? selectedPatient;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const PatientState({
    this.patients = const [],
    this.categories = const [],
    this.selectedPatient,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  PatientState copyWith({
    List<Patient>? patients,
    List<String>? categories,
    Patient? selectedPatient,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearSelectedPatient = false,
    bool clearError = false,
    bool clearSuccessMessage = false,
  }) {
    return PatientState(
      patients: patients ?? this.patients,
      categories: categories ?? this.categories,
      selectedPatient:
          clearSelectedPatient ? null : (selectedPatient ?? this.selectedPatient),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        patients,
        categories,
        selectedPatient,
        isLoading,
        error,
        successMessage,
      ];
}

// Patient Cubit
class PatientCubit extends Cubit<PatientState> {
  final PatientRepository _repository;
  List<Patient> _allPatients = [];

  PatientCubit(this._repository)
      : super(const PatientState());

  /// Load all patients
  Future<void> loadPatients() async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getAll();

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (patients) {
        _allPatients = patients;
        emit(state.copyWith(isLoading: false, patients: patients));
        loadCategories(); // Reload categories whenever patients change
      },
    );
  }

  /// Load patient by ID
  Future<void> loadPatientById(int id) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getById(id);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (patient) =>
          emit(state.copyWith(isLoading: false, selectedPatient: patient)),
    );
  }

  /// Search patients
  Future<void> searchPatients(String query) async {
    if (query.isEmpty) {
      emit(state.copyWith(patients: _allPatients));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.search(query);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (patients) => emit(state.copyWith(isLoading: false, patients: patients)),
    );
  }

  /// Create new patient
  Future<void> createPatient(Patient patient) async {
    emit(state.copyWith(
        isLoading: true,
        error: null,
        clearError: true,
        clearSuccessMessage: true));

    final result = await _repository.create(patient);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (id) async {
        // Handle suivi sync
        await _repository.syncSuivi(
          id,
          null, // doctorId will be handled by repo or passed from UI
          patient.categories,
          patient.suiviPathologies,
        );

        emit(state.copyWith(
          isLoading: false,
          successMessage: 'Patient created successfully',
        ));
        loadPatients(); // Reload patients (also reloads categories)
      },
    );
  }

  /// Update patient
  Future<void> updatePatient(int id, Patient patient) async {
    emit(state.copyWith(
        isLoading: true,
        error: null,
        clearError: true,
        clearSuccessMessage: true));

    final result = await _repository.update(id, patient);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) async {
        if (success) {
          // Handle suivi sync
          await _repository.syncSuivi(
            id,
            null, // doctorId
            patient.categories,
            patient.suiviPathologies,
          );

          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Patient updated successfully',
          ));
          loadPatients();
        } else {
          emit(state.copyWith(
              isLoading: false, error: 'Failed to update patient'));
        }
      },
    );
  }

  /// Delete patient
  Future<void> deletePatient(int id) async {
    emit(state.copyWith(
        isLoading: true,
        error: null,
        clearError: true,
        clearSuccessMessage: true));

    final result = await _repository.delete(id);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Patient deleted successfully',
          ));
          loadPatients();
        } else {
          emit(state.copyWith(
              isLoading: false, error: 'Failed to delete patient'));
        }
      },
    );
  }

  /// Update patient status
  Future<void> updatePatientStatus(int id, PatientStatus status) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));
    final result = await _repository.updateStatus(id, status);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Patient status updated',
          ));
          loadPatients();
        }
      },
    );
  }

  /// Get patients by status
  Future<void> getPatientsByStatus(PatientStatus status) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getByStatus(status);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (patients) => emit(state.copyWith(isLoading: false, patients: patients)),
    );
  }

  /// Get patients by fidelity stars
  Future<void> getPatientsByFidelity(int stars) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));
    final result = await _repository.getByFidelity(stars);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (patients) => emit(state.copyWith(isLoading: false, patients: patients)),
    );
  }

  /// Load categories
  Future<void> loadCategories() async {
    final result = await _repository.getSuiviCategories();
    result.fold(
      (failure) => null, // Ignore category load failure
      (categories) => emit(state.copyWith(categories: categories)),
    );
  }

  /// Get patients by category
  Future<void> getPatientsBySuiviCategory(String category) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));
    final result = await _repository.getBySuiviCategory(category);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (patients) => emit(state.copyWith(isLoading: false, patients: patients)),
    );
  }

  /// Filter patients by status from loaded list (Utility)
  List<Patient> filterLocalByStatus(PatientStatus status) {
    return _allPatients.where((p) => p.status == status).toList();
  }
}
