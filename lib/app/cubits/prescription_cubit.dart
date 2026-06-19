import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Prescription Events
abstract class PrescriptionEvent extends Equatable {
  const PrescriptionEvent();

  @override
  List<Object?> get props => [];
}

class LoadPrescriptions extends PrescriptionEvent {}

class LoadPrescriptionById extends PrescriptionEvent {
  final int id;

  const LoadPrescriptionById(this.id);

  @override
  List<Object?> get props => [id];
}

class SearchPrescriptions extends PrescriptionEvent {
  final String query;

  const SearchPrescriptions(this.query);

  @override
  List<Object?> get props => [query];
}

class CreatePrescription extends PrescriptionEvent {
  final Prescription prescription;

  const CreatePrescription(this.prescription);

  @override
  List<Object?> get props => [prescription];
}

class UpdatePrescription extends PrescriptionEvent {
  final int id;
  final Prescription prescription;

  const UpdatePrescription(this.id, this.prescription);

  @override
  List<Object?> get props => [id, prescription];
}

class DeletePrescription extends PrescriptionEvent {
  final int id;

  const DeletePrescription(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadCommonPrescriptions extends PrescriptionEvent {}

// Prescription States
abstract class PrescriptionState extends Equatable {
  const PrescriptionState();

  @override
  List<Object?> get props => [];
}

class PrescriptionInitial extends PrescriptionState {}

class PrescriptionLoading extends PrescriptionState {}

class PrescriptionsLoaded extends PrescriptionState {
  final List<Prescription> prescriptions;

  const PrescriptionsLoaded(this.prescriptions);

  @override
  List<Object?> get props => [prescriptions];
}

class PrescriptionLoaded extends PrescriptionState {
  final Prescription prescription;

  const PrescriptionLoaded(this.prescription);

  @override
  List<Object?> get props => [prescription];
}

class PrescriptionError extends PrescriptionState {
  final String message;

  const PrescriptionError(this.message);

  @override
  List<Object?> get props => [message];
}

class PrescriptionOperationSuccess extends PrescriptionState {
  final String message;

  const PrescriptionOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class PrescriptionTypesLoaded extends PrescriptionState {
  final List<PrescriptionType> types;

  const PrescriptionTypesLoaded(this.types);

  @override
  List<Object?> get props => [types];
}


// Prescription Cubit
class PrescriptionCubit extends Cubit<PrescriptionState> {
  final PrescriptionRepository _repository;

  PrescriptionCubit(this._repository) : super(PrescriptionInitial());

  /// Load all prescriptions
  Future<void> loadPrescriptions() async {
    emit(PrescriptionLoading());

    final result = await _repository.getAll();

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (prescriptions) => emit(PrescriptionsLoaded(prescriptions)),
    );
  }

  /// Load prescription by ID
  Future<void> loadPrescriptionById(int id) async {
    emit(PrescriptionLoading());

    final result = await _repository.getById(id);

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (prescription) => emit(PrescriptionLoaded(prescription)),
    );
  }

  /// Search prescriptions
  Future<void> searchPrescriptions(String query) async {
    if (query.isEmpty) {
      await loadCommonPrescriptions();
      return;
    }

    emit(PrescriptionLoading());

    final result = await _repository.search(query);

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (prescriptions) => emit(PrescriptionsLoaded(prescriptions)),
    );
  }

  /// Create new prescription
  Future<void> createPrescription(Prescription prescription) async {
    final result = await _repository.create(prescription);

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (id) async {
        emit(const PrescriptionOperationSuccess('Prescription created successfully'));
        await loadCommonPrescriptions();
      },
    );
  }

  /// Update prescription
  Future<void> updatePrescription(int id, Prescription prescription) async {
    final result = await _repository.update(id, prescription);

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (success) async {
        if (success) {
          emit(const PrescriptionOperationSuccess('Prescription updated successfully'));
          await loadCommonPrescriptions();
        } else {
          emit(const PrescriptionError('Failed to update prescription'));
        }
      },
    );
  }

  /// Delete prescription
  Future<void> deletePrescription(int id) async {
    final result = await _repository.delete(id);

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (success) async {
        if (success) {
          emit(const PrescriptionOperationSuccess('Prescription deleted successfully'));
          await loadCommonPrescriptions();
        } else {
          emit(const PrescriptionError('Failed to delete prescription'));
        }
      },
    );
  }

  /// Load common prescriptions (templates)
  Future<void> loadCommonPrescriptions() async {
    emit(PrescriptionLoading());

    final result = await _repository.getCommonPrescriptions();

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (prescriptions) => emit(PrescriptionsLoaded(prescriptions)),
    );
  }

  /// Load all prescription types (named templates)
  Future<void> loadPrescriptionTypes() async {
    emit(PrescriptionLoading());

    final result = await _repository.getAllPrescriptionTypes();

    result.fold(
      (failure) => emit(PrescriptionError(failure.message)),
      (types) => emit(PrescriptionTypesLoaded(types)),
    );
  }
}

