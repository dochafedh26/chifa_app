class Formatters {
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatMedicForm(String formulation) {
    if (formulation.isEmpty) return '';

    // Convert everything to uppercase for safety and remove extra spaces
    String form = formulation.toUpperCase().trim();

    // Map strict equality first where possible, or use contains
    if (form.toLowerCase().contains('comprime effervescent')) return 'CP EFF';
    if (form.toLowerCase().contains('solution injectable')) return 'SOL INJ';
    if (form.toLowerCase().contains('solution buvable')) return 'SOL BUV';
    if (form.toLowerCase().contains('comprime pellicule')) return 'CP PELL';
    if (form.toLowerCase().contains('comprime')) return 'CP';
    if (form.toLowerCase().contains('gelule')) return 'GEL';
    if (form.toLowerCase().contains('sirop')) return 'FL';
    if (form.toLowerCase().contains('injectable')) return 'INJ';
    if (form.toLowerCase().contains('ampoule')) return 'AMP';
    if (form.toLowerCase().contains('suppositoire')) return 'SUPP';
    if (form.toLowerCase().contains('pommade')) return 'POM';
    if (form.toLowerCase().contains('creme')) return 'CR';
    if (form.toLowerCase().contains('gouttes')) return 'GTTES';
    if (form.toLowerCase().contains('sachet')) return 'SACH';
    if (form.toLowerCase().contains('poudre')) return 'PDR';
    if (form.toLowerCase().contains('solution')) return 'SOL';
    if (form.toLowerCase().contains('suspension')) return 'SUSP';
    if (form.toLowerCase().contains('lotion')) return 'LOT';
    if (form.toLowerCase().contains('collyre')) return 'COLL';
    if (form.toLowerCase().contains('spray')) return 'SPRAY';
    if (form.toLowerCase().contains('flacon')) return 'FL';
    if (form.toLowerCase().contains('ovule')) return 'OV';
    if (form.toLowerCase().contains('pate')) return 'PATE';
    if (form.toLowerCase().contains('seringue')) return 'SER';

    // If no match is found, just return the first 4 characters or original
    if (form.length > 4) {
      return form.substring(0, 4);
    }

    return form;
  }

  static StringBuffer formatMedicament(
    Map<String, dynamic> medic,
    String posology,
    String duration,
  ) {
    final buffer = StringBuffer();
    buffer.write(medic['name']);
    if (medic['dosage'] != null && medic['dosage'].toString().trim().isNotEmpty) {
      buffer.write(' ${medic['dosage']}');
    }
    if (medic['formulation'] != null && medic['formulation'].toString().trim().isNotEmpty) {
      buffer.write(' ${formatMedicForm(medic['formulation'])}');
    }
    if (medic['dci'] != null && medic['dci'].toString().trim().isNotEmpty) {
      buffer.write(' [${medic['dci'].replaceAll(':', '').trim()}]');
    }
    if (posology.isNotEmpty) {
      buffer.write(', $posology'.toUpperCase());
    }
    if (duration.isNotEmpty) {
      buffer.write(' ........ $duration'.toUpperCase());
    }
    return buffer;
  }

  static Map<String, double>? parseWeightBasedPosology(String posoText) {
    if (posoText.isEmpty) return null;
    final regex = RegExp(r'(\d+)(?:-(\d+))?\s*mg/kg', caseSensitive: false);
    final match = regex.firstMatch(posoText);
    if (match != null) {
      final minVal = double.tryParse(match.group(1) ?? '');
      final maxVal = double.tryParse(match.group(2) ?? '');
      if (minVal != null) {
        return {
          'min': minVal,
          'max': maxVal ?? minVal,
        };
      }
    }
    return null;
  }

  static String? calculatePosologyProposition({
    required String posoText,
    required double weight,
  }) {
    final parsed = parseWeightBasedPosology(posoText);
    if (parsed == null) return null;
    
    final minDose = parsed['min']! * weight;
    final maxDose = parsed['max']! * weight;
    
    final minDoseStr = minDose % 1 == 0 ? minDose.toInt().toString() : minDose.toStringAsFixed(1);
    final maxDoseStr = maxDose % 1 == 0 ? maxDose.toInt().toString() : maxDose.toStringAsFixed(1);
    
    if (minDose == maxDose) {
      return '$minDoseStr mg/jour';
    } else {
      return '$minDoseStr - $maxDoseStr mg/jour';
    }
  }

  static ({int years, int months, int days}) calculateAgeComponents(
    DateTime birthDate, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    int years = current.year - birthDate.year;
    int months = current.month - birthDate.month;
    int days = current.day - birthDate.day;

    if (days < 0) {
      months--;
      final prevMonthLastDay = DateTime(current.year, current.month, 0);
      days += prevMonthLastDay.day;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years < 0) {
      return (years: 0, months: 0, days: 0);
    }

    return (years: years, months: months, days: days);
  }

  static String formatAge(DateTime birthDate, {DateTime? now}) {
    if (birthDate.year <= 1900) {
      return 'N/A';
    }

    final (:years, :months, :days) = calculateAgeComponents(birthDate, now: now);

    if (years >= 15) {
      return '$years ans';
    } else if (years >= 3) {
      if (months > 0) {
        return '$years ans $months mois';
      }
      return '$years ans';
    } else if (years >= 1) {
      final yStr = years == 1 ? '1 an' : '$years ans';
      final parts = <String>[yStr];
      if (months > 0) {
        parts.add('$months mois');
      }
      if (days > 0) {
        parts.add('$days jour${days > 1 ? 's' : ''}');
      }
      return parts.join(' ');
    } else {
      // Under 1 year: months and days
      final parts = <String>[];
      if (months > 0) {
        parts.add('$months mois');
      }
      if (days > 0) {
        parts.add('$days jour${days > 1 ? 's' : ''}');
      }
      if (parts.isEmpty) {
        return '0 jour';
      }
      return parts.join(' ');
    }
  }
}

