import 'package:flutter_test/flutter_test.dart';
import 'package:chifa/services/formatters/formatters.dart';
import 'package:chifa/services/db/models/patient.dart';

void main() {
  group('Age Calculation and Formatting Tests', () {
    final fixedNow = DateTime(2026, 9, 5);

    test('Under 1 year (< 1 year): displays months and days', () {
      // 0 days (born today)
      expect(
        Formatters.formatAge(DateTime(2026, 9, 5), now: fixedNow),
        '0 jour',
      );

      // 1 day old
      expect(
        Formatters.formatAge(DateTime(2026, 9, 4), now: fixedNow),
        '1 jour',
      );

      // 15 days old (same month)
      expect(
        Formatters.formatAge(DateTime(2026, 8, 21), now: fixedNow),
        '15 jours',
      );

      // Exactly 2 months (0 days)
      expect(
        Formatters.formatAge(DateTime(2026, 7, 5), now: fixedNow),
        '2 mois',
      );

      // 5 months and 12 days
      expect(
        Formatters.formatAge(DateTime(2026, 3, 24), now: fixedNow),
        '5 mois 12 jours',
      );

      // 11 months and 29 days
      expect(
        Formatters.formatAge(DateTime(2025, 9, 7), now: fixedNow),
        '11 mois 29 jours',
      );
    });

    test('Between 1 and 3 years (1 <= age < 3): displays years, months and days', () {
      // Exactly 1 year
      expect(
        Formatters.formatAge(DateTime(2025, 9, 5), now: fixedNow),
        '1 an',
      );

      // 1 year, 0 months, 5 days
      expect(
        Formatters.formatAge(DateTime(2025, 8, 31), now: fixedNow),
        '1 an 5 jours',
      );

      // 1 year, 2 months, 0 days
      expect(
        Formatters.formatAge(DateTime(2025, 7, 5), now: fixedNow),
        '1 an 2 mois',
      );

      // 1 year, 6 months, 13 days (2026-09-05 - 2025-02-23)
      expect(
        Formatters.formatAge(DateTime(2025, 2, 23), now: fixedNow),
        '1 an 6 mois 13 jours',
      );

      // Exactly 2 years
      expect(
        Formatters.formatAge(DateTime(2024, 9, 5), now: fixedNow),
        '2 ans',
      );

      // 2 years, 3 months, 15 days
      expect(
        Formatters.formatAge(DateTime(2024, 5, 21), now: fixedNow),
        '2 ans 3 mois 15 jours',
      );
    });

    test('Between 3 and 15 years (3 <= age < 15): displays years and months', () {
      // Exactly 3 years
      expect(
        Formatters.formatAge(DateTime(2023, 9, 5), now: fixedNow),
        '3 ans',
      );

      // 3 years, 2 months, 10 days -> displays only years and months
      expect(
        Formatters.formatAge(DateTime(2023, 6, 26), now: fixedNow),
        '3 ans 2 mois',
      );

      // 7 years, 11 months
      expect(
        Formatters.formatAge(DateTime(2018, 9, 15), now: fixedNow),
        '7 ans 11 mois',
      );

      // 14 years, 11 months
      expect(
        Formatters.formatAge(DateTime(2011, 10, 1), now: fixedNow),
        '14 ans 11 mois',
      );
    });

    test('15 years and above (age >= 15): displays years only', () {
      // Exactly 15 years
      expect(
        Formatters.formatAge(DateTime(2011, 9, 5), now: fixedNow),
        '15 ans',
      );

      // 15 years and 4 months
      expect(
        Formatters.formatAge(DateTime(2011, 5, 1), now: fixedNow),
        '15 ans',
      );

      // 30 years
      expect(
        Formatters.formatAge(DateTime(1996, 3, 10), now: fixedNow),
        '30 ans',
      );
    });

    test('Sentinel placeholder year returns N/A', () {
      expect(
        Formatters.formatAge(DateTime(1800, 1, 1), now: fixedNow),
        'N/A',
      );
    });

    test('Patient model getters integration', () {
      final infant = Patient(
        firstName: 'Baby',
        lastName: 'Doe',
        gender: Gender.male,
        dateOfBirth: DateTime.now().subtract(const Duration(days: 45)),
      );

      expect(infant.age, 0);
      expect(infant.formattedAge, contains('mois'));

      final child = Patient(
        firstName: 'Kid',
        lastName: 'Doe',
        gender: Gender.female,
        dateOfBirth: DateTime(2021, 5, 10),
      );

      expect(child.age, greaterThanOrEqualTo(3));
      expect(child.formattedAge, contains('ans'));
    });
  });
}
