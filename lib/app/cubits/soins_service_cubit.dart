import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class SoinsServiceState extends Equatable {
  final bool isLoading;
  final List<SoinsService> services;
  final String? error;
  final String? successMessage;

  const SoinsServiceState({
    this.isLoading = false,
    this.services = const [],
    this.error,
    this.successMessage,
  });

  SoinsServiceState copyWith({
    bool? isLoading,
    List<SoinsService>? services,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccessMessage = false,
  }) {
    return SoinsServiceState(
      isLoading: isLoading ?? this.isLoading,
      services: services ?? this.services,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, services, error, successMessage];
}

class SoinsServiceCubit extends Cubit<SoinsServiceState> {
  final SoinsServiceRepository _repository;

  SoinsServiceCubit(this._repository) : super(const SoinsServiceState());

  Future<void> loadServices() async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));
    try {
      final services = await _repository.getAllSoinsServices();
      emit(state.copyWith(isLoading: false, services: services));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> createService(SoinsService service) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccessMessage: true));
    final result = await _repository.create(service);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (id) {
        emit(state.copyWith(
          isLoading: false,
          successMessage: 'Soin créé avec succès',
        ));
        loadServices();
      },
    );
  }

  Future<void> updateService(int id, SoinsService service) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccessMessage: true));
    final result = await _repository.update(id, service);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Soin mis à jour avec succès',
          ));
          loadServices();
        } else {
          emit(state.copyWith(isLoading: false, error: 'Échec de la mise à jour du soin'));
        }
      },
    );
  }

  Future<void> deleteService(int id) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccessMessage: true));
    final result = await _repository.delete(id);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Soin supprimé avec succès',
          ));
          loadServices();
        } else {
          emit(state.copyWith(isLoading: false, error: 'Échec de la suppression du soin'));
        }
      },
    );
  }
}
