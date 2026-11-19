import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/app/printing/priere_de_faire.dart';
import 'package:chifa/services/db/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPatient = Patient(
    patientId: 101,
    uuid: 'test-patient-uuid-priere-1234',
    firstName: 'Karim',
    lastName: 'Mansouri',
    gender: Gender.male,
    dateOfBirth: DateTime(1990, 5, 15),
    phone: '0555123456',
    nationalId: '199012345678',
  );

  group('PriereDeFaire PDF Tests', () {
    test(
      'Generates CHIFA PDF with weight, date, French accents, bullets, blank lines, and clinical inequalities',
      () async {
        const demandText = '''
Prière de faire pratiquer les examens suivants :
- Échographie abdomino-pelvienne et exploration de l'œsophage
* Téléthorax face

Glycémie > 1.26 g/L, clairance < 60 ml/min [bilan rénal].
Merci confraternellement.
''';

        final pdfBytes = await generatePriereDeFairePdf(
          patient: testPatient,
          weight: '72',
          demandText: demandText,
          template: PrintTemplate.chifa,
          includeDate: true,
          date: DateTime(2026, 11, 19),
        );

        expect(pdfBytes, isNotEmpty);
        final header = utf8.decode(pdfBytes.sublist(0, 5));
        expect(header, equals('%PDF-'));
      },
    );

    test('Generates EPH PDF with includeDate false and null weight', () async {
      final pdfBytes = await generatePriereDeFairePdf(
        patient: testPatient,
        weight: null,
        demandText: '- Radiographie du genou droit (F + P)\n- Avis orthopédique',
        template: PrintTemplate.eph,
        includeDate: false,
        date: DateTime(2026, 11, 19),
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Generates multi-page PDF for long demand text (45+ lines)', () async {
      final longDemand = List.generate(
        50,
        (i) => '- Demande examen complémentaire numéro ${i + 1} avec précision clinique',
      ).join('\n');

      final pdfBytes = await generatePriereDeFairePdf(
        patient: testPatient,
        weight: '68',
        demandText: longDemand,
        template: PrintTemplate.chifa,
        includeDate: true,
        date: DateTime(2026, 11, 19),
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });
}
