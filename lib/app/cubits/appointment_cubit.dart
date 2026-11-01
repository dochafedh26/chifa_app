import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
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

/// Date range filtering modes for appointments
enum AppointmentDateFilterMode {
  day,
  month,
  year,
  allTime,
}

// Appointment Cubit
class AppointmentCubit extends Cubit<AppointmentState> {
  final AppointmentRepository _repository;

  AppointmentDateFilterMode _currentFilterMode = AppointmentDateFilterMode.day;
  DateTime _currentDate = DateTime.now();

  AppointmentDateFilterMode get currentFilterMode => _currentFilterMode;
  DateTime get currentDate => _currentDate;

  AppointmentCubit(this._repository) : super(AppointmentInitial());

  Future<void> _autoCancel() async {
    await _repository.autoCancelPastAppointments();
  }

  /// Reload appointments according to the currently active filter mode and date
  Future<void> reloadCurrentAppointments() async {
    switch (_currentFilterMode) {
      case AppointmentDateFilterMode.day:
        await loadAppointmentsByDate(_currentDate);
        break;
      case AppointmentDateFilterMode.month:
        await loadAppointmentsByMonth(_currentDate);
        break;
      case AppointmentDateFilterMode.year:
        await loadAppointmentsByYear(_currentDate.year);
        break;
      case AppointmentDateFilterMode.allTime:
        await loadAllAppointments();
        break;
    }
  }

  Future<void> loadAppointments() async {
    _currentFilterMode = AppointmentDateFilterMode.allTime;
    emit(AppointmentLoading());
    await _autoCancel();
    final result = await _repository.getAll();
    result.fold((failure) => emit(AppointmentError(failure.message)), (
      appointments,
    ) {
      emit(AppointmentsLoaded(appointments));
    });
  }

  Future<void> loadAllAppointments() async {
    await loadAppointments();
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
      reloadCurrentAppointments();
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
        reloadCurrentAppointments();
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
        reloadCurrentAppointments();
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
        reloadCurrentAppointments();
      }
    });
  }

  Future<void> loadAppointmentsByDate(DateTime date) async {
    _currentFilterMode = AppointmentDateFilterMode.day;
    _currentDate = date;
    emit(AppointmentLoading());
    await _autoCancel();
    final result = await _repository.getByDate(date);
    result.fold(
      (failure) => emit(AppointmentError(failure.message)),
      (appointments) => emit(AppointmentsLoaded(appointments)),
    );
  }

  /// Load all appointments for the entire month of [date]
  Future<void> loadAppointmentsByMonth(DateTime date) async {
    _currentFilterMode = AppointmentDateFilterMode.month;
    _currentDate = date;
    emit(AppointmentLoading());
    await _autoCancel();
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    final result = await _repository.getByDateRange(startOfMonth, endOfMonth);
    result.fold(
      (failure) => emit(AppointmentError(failure.message)),
      (appointments) => emit(AppointmentsLoaded(appointments)),
    );
  }

  /// Load all appointments for the entire year [year]
  Future<void> loadAppointmentsByYear(int year) async {
    _currentFilterMode = AppointmentDateFilterMode.year;
    _currentDate = DateTime(year, _currentDate.month, _currentDate.day);
    emit(AppointmentLoading());
    await _autoCancel();
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59);
    final result = await _repository.getByDateRange(startOfYear, endOfYear);
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
    _currentFilterMode = AppointmentDateFilterMode.day;
    _currentDate = DateTime.now();
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
