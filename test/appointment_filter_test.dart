import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/app/cubits/appointment_cubit.dart';
import 'package:chifa/services/db/models/models.dart';
import 'package:chifa/services/db/repositories/appointment_repository.dart';
import 'package:chifa/services/db/repositories/base_repository.dart';
import 'package:dartz/dartz.dart';

class FakeAppointmentRepository implements AppointmentRepository {
  DateTime? lastQueryStart;
  DateTime? lastQueryEnd;
  DateTime? lastQueryDate;
  bool getAllCalled = false;
  bool autoCancelCalled = false;

  final List<Appointment> mockAppointments = [
    Appointment(
      appointmentId: 1,
      patientId: 10,
      doctorId: 1,
      appointmentDate: DateTime(2026, 9, 15, 10, 0),
      notes: 'Consultation Septembre',
    ),
    Appointment(
      appointmentId: 2,
      patientId: 20,
      doctorId: 1,
      appointmentDate: DateTime(2026, 11, 20, 14, 30),
      notes: 'Consultation Novembre',
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Either<Failure, List<Appointment>>> getByDate(DateTime date) async {
    lastQueryDate = date;
    return Right(mockAppointments);
  }

  @override
  Future<Either<Failure, List<Appointment>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    lastQueryStart = start;
    lastQueryEnd = end;
    return Right(mockAppointments);
  }

  @override
  Future<Either<Failure, List<Appointment>>> getAll() async {
    getAllCalled = true;
    return Right(mockAppointments);
  }

  @override
  Future<Either<Failure, int>> autoCancelPastAppointments() async {
    autoCancelCalled = true;
    return const Right(0);
  }
}

void main() {
  group('AppointmentDateFilterMode enum', () {
    test('contains day, month, year, and allTime', () {
      expect(AppointmentDateFilterMode.values, [
        AppointmentDateFilterMode.day,
        AppointmentDateFilterMode.month,
        AppointmentDateFilterMode.year,
        AppointmentDateFilterMode.allTime,
      ]);
    });
  });

  group('AppointmentCubit Date Filtering', () {
    late FakeAppointmentRepository fakeRepo;
    late AppointmentCubit cubit;

    setUp(() {
      fakeRepo = FakeAppointmentRepository();
      cubit = AppointmentCubit(fakeRepo);
    });

    tearDown(() {
      cubit.close();
    });

    test('loadAppointmentsByDate sets day mode and queries date', () async {
      final testDate = DateTime(2026, 9, 8);
      await cubit.loadAppointmentsByDate(testDate);

      expect(cubit.currentFilterMode, AppointmentDateFilterMode.day);
      expect(cubit.currentDate, testDate);
      expect(fakeRepo.lastQueryDate, testDate);
      expect(cubit.state, isA<AppointmentsLoaded>());
    });

    test('loadAppointmentsByMonth sets month mode and queries start to end of month', () async {
      final testDate = DateTime(2026, 9, 15);
      await cubit.loadAppointmentsByMonth(testDate);

      expect(cubit.currentFilterMode, AppointmentDateFilterMode.month);
      expect(cubit.currentDate, testDate);
      expect(fakeRepo.lastQueryStart, DateTime(2026, 9, 1));
      expect(fakeRepo.lastQueryEnd, DateTime(2026, 9, 30, 23, 59, 59));
      expect(cubit.state, isA<AppointmentsLoaded>());
    });

    test('loadAppointmentsByYear sets year mode and queries full year range', () async {
      await cubit.loadAppointmentsByYear(2026);

      expect(cubit.currentFilterMode, AppointmentDateFilterMode.year);
      expect(fakeRepo.lastQueryStart, DateTime(2026, 1, 1));
      expect(fakeRepo.lastQueryEnd, DateTime(2026, 12, 31, 23, 59, 59));
      expect(cubit.state, isA<AppointmentsLoaded>());
    });

    test('loadAllAppointments sets allTime mode and calls getAll', () async {
      await cubit.loadAllAppointments();

      expect(cubit.currentFilterMode, AppointmentDateFilterMode.allTime);
      expect(fakeRepo.getAllCalled, isTrue);
      expect(cubit.state, isA<AppointmentsLoaded>());
    });

    test('reloadCurrentAppointments retains active mode and reloads appropriately', () async {
      // Set to month mode
      final testDate = DateTime(2026, 9, 15);
      await cubit.loadAppointmentsByMonth(testDate);

      // Reset tracker
      fakeRepo.lastQueryStart = null;
      fakeRepo.lastQueryEnd = null;

      // Reload
      await cubit.reloadCurrentAppointments();

      expect(cubit.currentFilterMode, AppointmentDateFilterMode.month);
      expect(fakeRepo.lastQueryStart, DateTime(2026, 9, 1));
      expect(fakeRepo.lastQueryEnd, DateTime(2026, 9, 30, 23, 59, 59));
    });
  });
}
