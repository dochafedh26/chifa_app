import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Medical Record Events
abstract class MedicalRecordEvent extends Equatable {
  const MedicalRecordEvent();

  @override
  List<Object?> get props => [];
}

class LoadMedicalRecords extends MedicalRecordEvent {}

class LoadMedicalRecordById extends MedicalRecordEvent {
  final int id;

  const LoadMedicalRecordById(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadMedicalRecordsByPatientId extends MedicalRecordEvent {
  final int patientId;

  const LoadMedicalRecordsByPatientId(this.patientId);

  @override
  List<Object?> get props => [patientId];
}

class LoadMedicalRecordsByDoctorId extends MedicalRecordEvent {
  final int doctorId;

  const LoadMedicalRecordsByDoctorId(this.doctorId);

  @override
  List<Object?> get props => [doctorId];
}

class SearchMedicalRecords extends MedicalRecordEvent {
  final String query;

  const SearchMedicalRecords(this.query);

  @override
  List<Object?> get props => [query];
}

class CreateMedicalRecord extends MedicalRecordEvent {
  final MedicalRecord medicalRecord;

  const CreateMedicalRecord(this.medicalRecord);

  @override
  List<Object?> get props => [medicalRecord];
}

class UpdateMedicalRecord extends MedicalRecordEvent {
  final int id;
  final MedicalRecord medicalRecord;

  const UpdateMedicalRecord(this.id, this.medicalRecord);

  @override
  List<Object?> get props => [id, medicalRecord];
}

class DeleteMedicalRecord extends MedicalRecordEvent {
  final int id;

  const DeleteMedicalRecord(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadMedicalRecordsByDateRange extends MedicalRecordEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadMedicalRecordsByDateRange(this.startDate, this.endDate);

  @override
  List<Object?> get props => [startDate, endDate];
}

// Medical Record State
class MedicalRecordState extends Equatable {
  final List<MedicalRecord> medicalRecords;
  final List<Employee> doctors;
  final MedicalRecord? selectedRecord;
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final int? lastCreatedId;

  const MedicalRecordState({
    this.medicalRecords = const [],
    this.doctors = const [],
    this.selectedRecord,
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.lastCreatedId,
  });

  MedicalRecordState copyWith({
    List<MedicalRecord>? medicalRecords,
    List<Employee>? doctors,
    MedicalRecord? selectedRecord,
    bool? isLoading,
    String? error,
    String? successMessage,
    int? lastCreatedId,
    bool clearSelectedRecord = false,
    bool clearError = false,
    bool clearSuccessMessage = false,
  }) {
    return MedicalRecordState(
      medicalRecords: medicalRecords ?? this.medicalRecords,
      doctors: doctors ?? this.doctors,
      selectedRecord: clearSelectedRecord
          ? null
          : (selectedRecord ?? this.selectedRecord),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      lastCreatedId: lastCreatedId ?? this.lastCreatedId,
    );
  }

  @override
  List<Object?> get props => [
    medicalRecords,
    doctors,
    selectedRecord,
    isLoading,
    error,
    successMessage,
    lastCreatedId,
  ];
}

// Medical Record Cubit
class MedicalRecordCubit extends Cubit<MedicalRecordState> {
  final MedicalRecordRepository _repository;
  final AuthRepository? _authRepository;
  List<MedicalRecord> _allMedicalRecords = [];

  MedicalRecordCubit(this._repository, {AuthRepository? authRepository})
    : _authRepository = authRepository,
      super(const MedicalRecordState());

  /// Load all medical records
  Future<void> loadMedicalRecords() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getAll();
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (records) {
        _allMedicalRecords = records;
        emit(state.copyWith(isLoading: false, medicalRecords: records));
      },
    );
  }

  /// Load medical record by ID
  Future<void> loadMedicalRecordById(int id) async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getById(id);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (record) =>
          emit(state.copyWith(isLoading: false, selectedRecord: record)),
    );
  }

  /// Load medical records by patient ID
  Future<void> loadMedicalRecordsByPatientId(int patientId) async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getByPatientId(patientId);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (records) =>
          emit(state.copyWith(isLoading: false, medicalRecords: records)),
    );
  }

  /// Load medical records by doctor ID
  Future<void> loadMedicalRecordsByDoctorId(int doctorId) async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getByDoctorId(doctorId);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (records) =>
          emit(state.copyWith(isLoading: false, medicalRecords: records)),
    );
  }

  /// Search medical records
  Future<void> searchMedicalRecords(String query) async {
    if (isClosed) return;
    if (query.isEmpty) {
      emit(state.copyWith(medicalRecords: _allMedicalRecords));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.search(query);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (records) =>
          emit(state.copyWith(isLoading: false, medicalRecords: records)),
    );
  }

  /// Filter medical records with multiple criteria
  Future<void> filterMedicalRecords({
    DateTime? startDate,
    DateTime? endDate,
    int? doctorId,
    String? patientQuery,
    String? motifQuery,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getFiltered(
      startDate: startDate,
      endDate: endDate,
      doctorId: doctorId,
      patientQuery: patientQuery,
      motifQuery: motifQuery,
    );
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (records) =>
          emit(state.copyWith(isLoading: false, medicalRecords: records)),
    );
  }

  /// Load all doctors
  Future<void> loadDoctors() async {
    if (isClosed) return;
    if (_authRepository == null) return;

    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _authRepository.getAllDoctors();
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (doctors) => emit(state.copyWith(isLoading: false, doctors: doctors)),
    );
  }

  /// Create new medical record
  Future<void> createMedicalRecord(MedicalRecord medicalRecord) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: true,
        error: null,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );
    final result = await _repository.create(medicalRecord);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (id) {
        emit(
          state.copyWith(
            isLoading: false,
            successMessage: 'Medical record created successfully',
            lastCreatedId: id,
          ),
        );
        loadMedicalRecords(); // Reload medical records
      },
    );
  }

  /// Update medical record
  Future<void> updateMedicalRecord(int id, MedicalRecord medicalRecord) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: true,
        error: null,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );
    final result = await _repository.update(id, medicalRecord);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(
            state.copyWith(
              isLoading: false,
              successMessage: 'Medical record updated successfully',
            ),
          );
          loadMedicalRecords();
        } else {
          emit(
            state.copyWith(
              isLoading: false,
              error: 'Failed to update medical record',
            ),
          );
        }
      },
    );
  }

  /// Delete medical record
  Future<void> deleteMedicalRecord(int id) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: true,
        error: null,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );
    final result = await _repository.delete(id);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(
            state.copyWith(
              isLoading: false,
              successMessage: 'Medical record deleted successfully',
            ),
          );
          loadMedicalRecords();
        } else {
          emit(
            state.copyWith(
              isLoading: false,
              error: 'Failed to delete medical record',
            ),
          );
        }
      },
    );
  }

  /// Load medical records by date range
  Future<void> loadMedicalRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _repository.getByDateRange(startDate, endDate);
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (records) =>
          emit(state.copyWith(isLoading: false, medicalRecords: records)),
    );
  }

  /// Get medical records count
  Future<int> getMedicalRecordsCount() async {
    final result = await _repository.getCount();
    return result.fold((_) => 0, (count) => count);
  }

  /// Clear error
  void clearError() {
    if (isClosed) return;
    emit(state.copyWith(clearError: true));
  }

  /// Clear success message
  void clearSuccessMessage() {
    if (isClosed) return;
    emit(state.copyWith(clearSuccessMessage: true));
  }
}
