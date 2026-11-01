import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chifa/app/screens/appointments/pvc_appointment_card_dialog.dart';
import 'package:chifa/app/cubits/settings_cubit.dart';
import 'package:chifa/services/db/models/models.dart';
import 'package:chifa/services/db/repositories/auth_repository.dart';

class MockAuthRepository extends AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPatient = Patient(
    patientId: 202,
    firstName: 'Amine',
    lastName: 'Brahimi',
    gender: Gender.male,
    dateOfBirth: DateTime(1985, 3, 20),
    phone: '0661122334',
  );

  final testAppointment = Appointment(
    appointmentId: 5,
    patientId: 202,
    doctorId: 10,
    appointmentDate: DateTime(2026, 11, 25, 9, 0),
    notes: 'Suivi trimestriel',
  );

  testWidgets('PvcAppointmentCardDialog renders and displays alert when past appointments exist',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final pastAppointment = Appointment(
      appointmentId: 1,
      patientId: 202,
      doctorId: 10,
      appointmentDate: DateTime(2026, 8, 10, 10, 0),
      notes: 'Consultation initiale',
      status: AppointmentStatus.completed,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => SettingsCubit(MockAuthRepository()),
          child: Scaffold(
            body: PvcAppointmentCardDialog(
              patient: testPatient,
              appointment: testAppointment,
              previousAppointments: [pastAppointment],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify dialog title
    expect(find.text('Impression Carte PVC de Rendez-vous (ID-Card)'), findsOneWidget);

    // Verify warning alert is present because card is already printed
    expect(find.text('ATTENTION : CARTE DÉJÀ IMPRIMÉE DÉTECTÉE'), findsOneWidget);

    // Verify automatic target is Line 2
    expect(find.text('Cible : Ligne 2'), findsOneWidget);

    // Verify slot chips exist
    expect(find.text('Ligne 1'), findsOneWidget);
    expect(find.text('Ligne 2'), findsOneWidget);
    expect(find.text('Ligne 6'), findsOneWidget);
  });

  testWidgets('PvcAppointmentCardDialog opened via showDialog pumps frames cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => SettingsCubit(MockAuthRepository()),
          child: Builder(
            builder: (context) => Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  PvcAppointmentCardDialog.show(
                    context: context,
                    patient: testPatient,
                    appointment: testAppointment,
                    previousAppointments: [],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Impression Carte PVC de Rendez-vous (ID-Card)'), findsOneWidget);
  });
}
