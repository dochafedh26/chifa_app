import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Appointment Events
abstract class AppointmentEvent extends Equatable {
  const AppointmentEvent();
  @override
  List<Object?> get props => [];
}

class LoadAppointments extends AppointmentEvent {}

class LoadAppointmentById extends AppointmentEvent {
  final int id;
  const LoadAppointmentById(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateAppointment extends AppointmentEvent {
  final Appointment appointment;
  const CreateAppointment(this.appointment);
  @override
  List<Object?> get props => [appointment];
}

class UpdateAppointment extends AppointmentEvent {
  final int id;
  final Appointment appointment;
  const UpdateAppointment(this.id, this.appointment);
  @override
  List<Object?> get props => [id, appointment];
}

class DeleteAppointment extends AppointmentEvent {
  final int id;
  const DeleteAppointment(this.id);
  @override
  List<Object?> get props => [id];
}

class UpdateAppointmentStatus extends AppointmentEvent {
  final int id;
  final AppointmentStatus status;
  const UpdateAppointmentStatus(this.id, this.status);
  @override
  List<Object?> get props => [id, status];
}

class LoadAppointmentsByDate extends AppointmentEvent {
  final DateTime date;
  const LoadAppointmentsByDate(this.date);
  @override
  List<Object?> get props => [date];
}

// Appointment States
abstract class AppointmentState extends Equatable {
  const AppointmentState();
  @override
  List<Object?> get props => [];
}

class AppointmentInitial extends AppointmentState {}

class AppointmentLoading extends AppointmentState {}

class AppointmentsLoaded extends AppointmentState {
  final List<Appointment> appointments;
  const AppointmentsLoaded(this.appointments);
  @override
  List<Object?> get props => [appointments];
}

class AppointmentLoaded extends AppointmentState {
  final Appointment appointment;
  const AppointmentLoaded(this.appointment);
  @override
  List<Object?> get props => [appointment];
}

class AppointmentError extends AppointmentState {
  final String message;
  const AppointmentError(this.message);
  @override
  List<Object?> get props => [message];
}

class AppointmentOperationSuccess extends AppointmentState {
  final String message;
  const AppointmentOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

// Appointment Cubit
class AppointmentCubit extends Cubit<AppointmentState> {
  final AppointmentRepository _repository;

  AppointmentCubit(this._repository) : super(AppointmentInitial());

  Future<void> _autoCancel() async {
    await _repository.autoCancelPastAppointments();
  }

  Future<void> loadAppointments() async {
    emit(AppointmentLoading());
    await _autoCancel();
    final result = await _repository.getAll();
    result.fold((failure) => emit(AppointmentError(failure.message)), (
      appointments,
    ) {
      emit(AppointmentsLoaded(appointments));
    });
  }

  Future<void> loadAppointmentById(int id) async {
    emit(AppointmentLoading());
    final result = await _repository.getById(id);
    result.fold(
      (failure) => emit(AppointmentError(failure.message)),
      (appointment) => emit(AppointmentLoaded(appointment)),
    );
  }

  Future<void> createAppointment(Appointment appointment) async {
    final result = await _repository.create(appointment);
    result.fold((failure) => emit(AppointmentError(failure.message)), (id) {
      emit(
        const AppointmentOperationSuccess('Appointment created successfully'),
      );
      loadAppointments();
    });
  }

  Future<void> updateAppointment(int id, Appointment appointment) async {
    final result = await _repository.update(id, appointment);
    result.fold((failure) => emit(AppointmentError(failure.message)), (
      success,
    ) {
      if (success) {
        emit(
          const AppointmentOperationSuccess('Appointment updated successfully'),
        );
        loadAppointments();
      }
    });
  }

  Future<void> deleteAppointment(int id) async {
    final result = await _repository.delete(id);
    result.fold((failure) => emit(AppointmentError(failure.message)), (
      success,
    ) {
      if (success) {
        emit(
          const AppointmentOperationSuccess('Appointment deleted successfully'),
        );
        loadAppointments();
      }
    });
  }

  Future<void> updateAppointmentStatus(int id, AppointmentStatus status) async {
    final result = await _repository.updateStatus(id, status);
    result.fold((failure) => emit(AppointmentError(failure.message)), (
      success,
    ) {
      if (success) {
        emit(const AppointmentOperationSuccess('Status updated'));
        loadAppointments();
      }
    });
  }

  Future<void> loadAppointmentsByDate(DateTime date) async {
    emit(AppointmentLoading());
    await _autoCancel();
    final result = await _repository.getByDate(date);
    result.fold(
      (failure) => emit(AppointmentError(failure.message)),
      (appointments) => emit(AppointmentsLoaded(appointments)),
    );
  }

  Future<void> loadAppointmentsByDateRange(DateTime start, DateTime end) async {
    emit(AppointmentLoading());
    await _autoCancel();
    final result = await _repository.getByDateRange(start, end);
    result.fold(
      (failure) => emit(AppointmentError(failure.message)),
      (appointments) => emit(AppointmentsLoaded(appointments)),
    );
  }

  Future<void> loadTodayAppointments() async {
    emit(AppointmentLoading());
    await _autoCancel();
    final result = await _repository.getTodayAppointments();
    result.fold(
      (failure) => emit(AppointmentError(failure.message)),
      (appointments) => emit(AppointmentsLoaded(appointments)),
    );
  }

  Future<void> loadUpcomingAppointments() async {
    emit(AppointmentLoading());
    await _autoCancel();
    final result = await _repository.getUpcoming();
    result.fold(
      (failure) => emit(AppointmentError(failure.message)),
      (appointments) => emit(AppointmentsLoaded(appointments)),
    );
  }
}
