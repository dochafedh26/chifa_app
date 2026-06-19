import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// States
abstract class DoctorWorkingHoursState extends Equatable {
  const DoctorWorkingHoursState();
  @override
  List<Object?> get props => [];
}

class DoctorWorkingHoursInitial extends DoctorWorkingHoursState {}
class DoctorWorkingHoursLoading extends DoctorWorkingHoursState {}
class DoctorWorkingHoursLoaded extends DoctorWorkingHoursState {
  final List<DoctorWorkingHours> slots;
  const DoctorWorkingHoursLoaded(this.slots);
  @override
  List<Object?> get props => [slots];
}
class DoctorWorkingHoursError extends DoctorWorkingHoursState {
  final String message;
  const DoctorWorkingHoursError(this.message);
  @override
  List<Object?> get props => [message];
}

// Cubit
class DoctorWorkingHoursCubit extends Cubit<DoctorWorkingHoursState> {
  final DoctorWorkingHoursRepository _repository;

  DoctorWorkingHoursCubit(this._repository) : super(DoctorWorkingHoursInitial());

  Future<void> loadWorkingHours(int doctorId) async {
    emit(DoctorWorkingHoursLoading());
    final result = await _repository.getByDoctorId(doctorId);
    result.fold(
      (failure) => emit(DoctorWorkingHoursError(failure.message)),
      (slots) => emit(DoctorWorkingHoursLoaded(slots)),
    );
  }

  Future<void> addWorkingHours(DoctorWorkingHours slot) async {
    final result = await _repository.create(slot);
    result.fold(
      (failure) => emit(DoctorWorkingHoursError(failure.message)),
      (id) => loadWorkingHours(slot.doctorId),
    );
  }

  Future<void> deleteWorkingHours(int id, int doctorId) async {
    final result = await _repository.delete(id);
    result.fold(
      (failure) => emit(DoctorWorkingHoursError(failure.message)),
      (success) => loadWorkingHours(doctorId),
    );
  }

  Future<bool> checkAvailability(int doctorId, DateTime dateTime) async {
    final result = await _repository.isAvailable(doctorId, dateTime);
    return result.fold((_) => true, (available) => available);
  }
}
