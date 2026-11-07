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
  final List<Prescription> prescriptions;
  final List<PrescriptionType> types;

  const PrescriptionState({
    this.prescriptions = const [],
    this.types = const [],
  });

  @override
  List<Object?> get props => [prescriptions, types];
}

class PrescriptionInitial extends PrescriptionState {
  const PrescriptionInitial({super.prescriptions, super.types});
}

class PrescriptionLoading extends PrescriptionState {
  const PrescriptionLoading({super.prescriptions, super.types});
}

class PrescriptionsLoaded extends PrescriptionState {
  const PrescriptionsLoaded(
    List<Prescription> prescriptions, {
    super.types,
  }) : super(prescriptions: prescriptions);
}

class PrescriptionLoaded extends PrescriptionState {
  final Prescription prescription;

  const PrescriptionLoaded(
    this.prescription, {
    super.prescriptions,
    super.types,
  });

  @override
  List<Object?> get props => [prescription, prescriptions, types];
}

class PrescriptionError extends PrescriptionState {
  final String message;

  const PrescriptionError(
    this.message, {
    super.prescriptions,
    super.types,
  });

  @override
  List<Object?> get props => [message, prescriptions, types];
}

class PrescriptionOperationSuccess extends PrescriptionState {
  final String message;

  const PrescriptionOperationSuccess(
    this.message, {
    super.prescriptions,
    super.types,
  });

  @override
  List<Object?> get props => [message, prescriptions, types];
}

class PrescriptionTypesLoaded extends PrescriptionState {
  const PrescriptionTypesLoaded(
    List<PrescriptionType> types, {
    super.prescriptions,
  }) : super(types: types);
}

// Prescription Cubit
class PrescriptionCubit extends Cubit<PrescriptionState> {
  final PrescriptionRepository _repository;
  List<Prescription> _cachedPrescriptions = const [];
  List<PrescriptionType> _cachedTypes = const [];

  PrescriptionCubit(this._repository) : super(const PrescriptionInitial());

  /// Load all prescriptions
  Future<void> loadPrescriptions() async {
    emit(PrescriptionLoading(
      prescriptions: _cachedPrescriptions,
      types: _cachedTypes,
    ));

    final result = await _repository.getAll();

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (prescriptions) {
        _cachedPrescriptions = prescriptions;
        emit(PrescriptionsLoaded(prescriptions, types: _cachedTypes));
      },
    );
  }

  /// Load prescription by ID
  Future<void> loadPrescriptionById(int id) async {
    emit(PrescriptionLoading(
      prescriptions: _cachedPrescriptions,
      types: _cachedTypes,
    ));

    final result = await _repository.getById(id);

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (prescription) => emit(PrescriptionLoaded(
        prescription,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
    );
  }

  /// Search prescriptions
  Future<void> searchPrescriptions(String query) async {
    if (query.trim().isEmpty) {
      await loadCommonPrescriptions();
      return;
    }

    emit(PrescriptionLoading(
      prescriptions: const [],
      types: _cachedTypes,
    ));

    final result = await _repository.search(query.trim());

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (prescriptions) {
        emit(PrescriptionsLoaded(prescriptions, types: _cachedTypes));
      },
    );
  }

  /// Create new prescription
  Future<void> createPrescription(Prescription prescription) async {
    final result = await _repository.create(prescription);

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (id) async {
        emit(PrescriptionOperationSuccess(
          'Prescription created successfully',
          prescriptions: _cachedPrescriptions,
          types: _cachedTypes,
        ));
        await loadCommonPrescriptions();
      },
    );
  }

  /// Update prescription
  Future<void> updatePrescription(int id, Prescription prescription) async {
    final result = await _repository.update(id, prescription);

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (success) async {
        if (success) {
          emit(PrescriptionOperationSuccess(
            'Prescription updated successfully',
            prescriptions: _cachedPrescriptions,
            types: _cachedTypes,
          ));
          await loadCommonPrescriptions();
        } else {
          emit(PrescriptionError(
            'Failed to update prescription',
            prescriptions: _cachedPrescriptions,
            types: _cachedTypes,
          ));
        }
      },
    );
  }

  /// Delete prescription
  Future<void> deletePrescription(int id) async {
    final result = await _repository.delete(id);

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (success) async {
        if (success) {
          emit(PrescriptionOperationSuccess(
            'Prescription deleted successfully',
            prescriptions: _cachedPrescriptions,
            types: _cachedTypes,
          ));
          await loadCommonPrescriptions();
        } else {
          emit(PrescriptionError(
            'Failed to delete prescription',
            prescriptions: _cachedPrescriptions,
            types: _cachedTypes,
          ));
        }
      },
    );
  }

  /// Load common prescriptions (templates)
  Future<void> loadCommonPrescriptions() async {
    emit(PrescriptionLoading(
      prescriptions: _cachedPrescriptions,
      types: _cachedTypes,
    ));

    final result = await _repository.getCommonPrescriptions();

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (prescriptions) {
        _cachedPrescriptions = prescriptions;
        emit(PrescriptionsLoaded(prescriptions, types: _cachedTypes));
      },
    );
  }

  /// Load all prescription types (named templates)
  Future<void> loadPrescriptionTypes() async {
    final result = await _repository.getAllPrescriptionTypes();

    result.fold(
      (failure) => emit(PrescriptionError(
        failure.message,
        prescriptions: _cachedPrescriptions,
        types: _cachedTypes,
      )),
      (types) {
        _cachedTypes = types;
        emit(PrescriptionsLoaded(_cachedPrescriptions, types: _cachedTypes));
      },
    );
  }
}

