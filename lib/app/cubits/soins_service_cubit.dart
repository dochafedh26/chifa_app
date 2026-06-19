import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class SoinsServiceState extends Equatable {
  final bool isLoading;
  final List<SoinsService> services;
  final String? error;

  const SoinsServiceState({
    this.isLoading = false,
    this.services = const [],
    this.error,
  });

  SoinsServiceState copyWith({
    bool? isLoading,
    List<SoinsService>? services,
    String? error,
  }) {
    return SoinsServiceState(
      isLoading: isLoading ?? this.isLoading,
      services: services ?? this.services,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, services, error];
}

class SoinsServiceCubit extends Cubit<SoinsServiceState> {
  final SoinsServiceRepository _repository;

  SoinsServiceCubit(this._repository) : super(const SoinsServiceState());

  Future<void> loadServices() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final services = await _repository.getAllSoinsServices();
      emit(state.copyWith(isLoading: false, services: services));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
