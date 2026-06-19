import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Bilan Events
abstract class BilanEvent extends Equatable {
  const BilanEvent();

  @override
  List<Object?> get props => [];
}

class LoadBilans extends BilanEvent {}

class LoadBilanTypes extends BilanEvent {}

class LoadBilanById extends BilanEvent {
  final int id;

  const LoadBilanById(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadBilansByPatientId extends BilanEvent {
  final int patientId;

  const LoadBilansByPatientId(this.patientId);

  @override
  List<Object?> get props => [patientId];
}

class LoadBilansByDoctorId extends BilanEvent {
  final int doctorId;

  const LoadBilansByDoctorId(this.doctorId);

  @override
  List<Object?> get props => [doctorId];
}

class SearchBilans extends BilanEvent {
  final String query;

  const SearchBilans(this.query);

  @override
  List<Object?> get props => [query];
}

class CreateBilan extends BilanEvent {
  final Bilan bilan;

  const CreateBilan(this.bilan);

  @override
  List<Object?> get props => [bilan];
}

class UpdateBilan extends BilanEvent {
  final int id;
  final Bilan bilan;

  const UpdateBilan(this.id, this.bilan);

  @override
  List<Object?> get props => [id, bilan];
}

class DeleteBilan extends BilanEvent {
  final int id;

  const DeleteBilan(this.id);

  @override
  List<Object?> get props => [id];
}

// Bilan States
abstract class BilanState extends Equatable {
  const BilanState();

  @override
  List<Object?> get props => [];
}

class BilanInitial extends BilanState {}

class BilanLoading extends BilanState {}

class BilansLoaded extends BilanState {
  final List<Bilan> bilans;

  const BilansLoaded(this.bilans);

  @override
  List<Object?> get props => [bilans];
}

class BilanTypesLoaded extends BilanState {
  final List<BilanType> types;

  const BilanTypesLoaded(this.types);

  @override
  List<Object?> get props => [types];
}

class BilanLoaded extends BilanState {
  final Bilan bilan;

  const BilanLoaded(this.bilan);

  @override
  List<Object?> get props => [bilan];
}

class BilanError extends BilanState {
  final String message;

  const BilanError(this.message);

  @override
  List<Object?> get props => [message];
}

class BilanOperationSuccess extends BilanState {
  final String message;

  const BilanOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Bilan Cubit
class BilanCubit extends Cubit<BilanState> {
  final BilanRepository _repository;
  List<Bilan> _allBilans = [];

  BilanCubit(this._repository) : super(BilanInitial());

  /// Load all bilans
  Future<void> loadBilans() async {
    emit(BilanLoading());

    final result = await _repository.getAll();

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (bilans) {
        _allBilans = bilans;
        emit(BilansLoaded(bilans));
      },
    );
  }

  /// Load all predefined bilan types
  Future<void> loadBilanTypes() async {
    emit(BilanLoading());

    final result = await _repository.getAllBilanTypes();

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (types) => emit(BilanTypesLoaded(types)),
    );
  }

  /// Load bilan by ID
  Future<void> loadBilanById(int id) async {
    emit(BilanLoading());

    final result = await _repository.getById(id);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (bilan) => emit(BilanLoaded(bilan)),
    );
  }

  /// Load bilans by patient ID
  Future<void> loadBilansByPatientId(int patientId) async {
    emit(BilanLoading());

    final result = await _repository.getByPatientId(patientId);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (bilans) => emit(BilansLoaded(bilans)),
    );
  }

  /// Load bilans by doctor ID
  Future<void> loadBilansByDoctorId(int doctorId) async {
    emit(BilanLoading());

    final result = await _repository.getByDoctorId(doctorId);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (bilans) => emit(BilansLoaded(bilans)),
    );
  }

  /// Search bilans
  Future<void> searchBilans(String query) async {
    if (query.isEmpty) {
      emit(BilansLoaded(_allBilans));
      return;
    }

    emit(BilanLoading());

    final result = await _repository.search(query);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (bilans) => emit(BilansLoaded(bilans)),
    );
  }

  /// Create new bilan
  Future<void> createBilan(Bilan bilan) async {
    final result = await _repository.create(bilan);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (id) {
        emit(const BilanOperationSuccess('Lab order created successfully'));
        loadBilans();
      },
    );
  }

  /// Update bilan
  Future<void> updateBilan(int id, Bilan bilan) async {
    final result = await _repository.update(id, bilan);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (success) {
        if (success) {
          emit(const BilanOperationSuccess('Lab order updated successfully'));
          loadBilans();
        } else {
          emit(const BilanError('Failed to update lab order'));
        }
      },
    );
  }

  /// Delete bilan
  Future<void> deleteBilan(int id) async {
    final result = await _repository.delete(id);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (success) {
        if (success) {
          emit(const BilanOperationSuccess('Lab order deleted successfully'));
          loadBilans();
        } else {
          emit(const BilanError('Failed to delete lab order'));
        }
      },
    );
  }

  /// Get latest bilan for a patient
  Future<void> getLatestBilanByPatientId(int patientId) async {
    emit(BilanLoading());

    final result = await _repository.getLatestByPatientId(patientId);

    result.fold(
      (failure) => emit(BilanError(failure.message)),
      (bilan) {
        if (bilan != null) {
          emit(BilanLoaded(bilan));
        } else {
          emit(const BilanError('No lab orders found for this patient'));
        }
      },
    );
  }
}
