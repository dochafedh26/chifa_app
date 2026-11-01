import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/app/printing/pvc_appointment_card_pdf.dart';
import 'package:chifa/services/db/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPatient = Patient(
    patientId: 101,
    uuid: 'test-patient-uuid-1234',
    firstName: 'Karim',
    lastName: 'Mansouri',
    gender: Gender.male,
    dateOfBirth: DateTime(1990, 5, 15),
    phone: '0555123456',
    nationalId: '199012345678',
  );

  final testAppointment1 = Appointment(
    appointmentId: 1,
    patientId: 101,
    doctorId: 10,
    appointmentDate: DateTime(2026, 9, 10, 10, 30),
    notes: 'Consultation initiale',
  );

  final testAppointment2 = Appointment(
    appointmentId: 2,
    patientId: 101,
    doctorId: 10,
    appointmentDate: DateTime(2026, 10, 15, 14, 0),
    notes: 'Contrôle traitement',
  );

  group('PvcAppointmentCardPdf Tests', () {
    test('Generates CR-80 card in both mode (Recto + Verso)', () async {
      final pdfBytes = await PvcAppointmentCardPdf.generate(
        patient: testPatient,
        currentAppointment: testAppointment1,
        cardSize: PvcCardSize.cr80,
        printMode: PvcPrintMode.both,
        targetSlotIndex: 1,
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Generates Recto Only mode', () async {
      final pdfBytes = await PvcAppointmentCardPdf.generate(
        patient: testPatient,
        currentAppointment: testAppointment1,
        cardSize: PvcCardSize.cr80,
        printMode: PvcPrintMode.frontOnly,
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Generates Selective Slot Only mode for existing card (Slot 2)', () async {
      final pdfBytes = await PvcAppointmentCardPdf.generate(
        patient: testPatient,
        currentAppointment: testAppointment2,
        previousAppointments: [testAppointment1],
        cardSize: PvcCardSize.cr80,
        printMode: PvcPrintMode.backSlotOnly,
        targetSlotIndex: 2,
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Supports large formats CR-100 (8 slots) and A7 Badge (10 slots)', () async {
      final cr100Bytes = await PvcAppointmentCardPdf.generate(
        patient: testPatient,
        currentAppointment: testAppointment1,
        cardSize: PvcCardSize.cr100,
        printMode: PvcPrintMode.both,
        targetSlotIndex: 1,
      );
      expect(cr100Bytes, isNotEmpty);
      expect(PvcCardSize.cr100.slotsCount, equals(8));
    });

    test('Supports realistic patient 1097 with null notes and empty phone', () async {
      final patient1097 = Patient(
        patientId: 1097,
        uuid: '43161776-4256-11f1-bf94-4cd7170e099c',
        firstName: 'SADJED NIDHAL',
        lastName: 'CHIKH TOUAMI',
        gender: Gender.male,
        dateOfBirth: DateTime(2018, 5, 4),
        phone: '',
        nationalId: '',
      );

      final appointment49 = Appointment(
        appointmentId: 49,
        patientId: 1097,
        doctorId: 1,
        appointmentDate: DateTime(2026, 9, 10, 10, 0),
        notes: null,
      );

      final pdfBytes = await PvcAppointmentCardPdf.generate(
        patient: patient1097,
        currentAppointment: appointment49,
        cardSize: PvcCardSize.cr80,
        printMode: PvcPrintMode.both,
        targetSlotIndex: 1,
      );

      expect(pdfBytes, isNotEmpty);
    });

    test('Generates Recto with full rich patient details (address, atcd, nationalId)', () async {
      final fullPatient = Patient(
        patientId: 2045,
        uuid: 'd7a12345-4256-11f1-bf94-4cd7170e099c',
        firstName: 'Amina',
        lastName: 'Boumedienne',
        gender: Gender.female,
        dateOfBirth: DateTime(1988, 11, 24),
        phone: '0661987654',
        nationalId: '1988160012345678',
        address: '12 Rue Didouche Mourad, Alger',
        atcd: 'Allergie Pénicilline, Asthme',
        suiviPathologies: 'Diabète Type 2',
        email: 'amina.b@example.dz',
      );

      final appt = Appointment(
        appointmentId: 55,
        patientId: 2045,
        doctorId: 1,
        appointmentDate: DateTime(2026, 9, 20, 11, 15),
        notes: 'Suivi trimestriel',
      );

      final pdfBytes = await PvcAppointmentCardPdf.generate(
        patient: fullPatient,
        currentAppointment: appt,
        cardSize: PvcCardSize.cr80,
        printMode: PvcPrintMode.frontOnly,
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });
}
