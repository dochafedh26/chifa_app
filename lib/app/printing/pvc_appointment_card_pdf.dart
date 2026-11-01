import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:chifa/services/db/models/models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PVC Card Dimensions
enum PvcCardSize {
  /// Standard ID-1 / CR-80 (Credit card size): 85.60 mm x 53.98 mm (6 appointment slots)
  cr80(
    name: 'CR-80 Standard (85.6 × 54 mm)',
    widthMm: 85.60,
    heightMm: 53.98,
    slotsCount: 6,
  ),

  /// Large PVC / CR-100 format: 98.50 mm x 67.00 mm (8 appointment slots)
  cr100(
    name: 'CR-100 Grand Format (98.5 × 67 mm)',
    widthMm: 98.50,
    heightMm: 67.00,
    slotsCount: 8,
  ),

  /// A7 Badge Format: 105.00 mm x 74.00 mm (10 appointment slots)
  a7Badge(
    name: 'A7 Badge Médical (105 × 74 mm)',
    widthMm: 105.00,
    heightMm: 74.00,
    slotsCount: 10,
  );

  final String name;
  final double widthMm;
  final double heightMm;
  final int slotsCount;

  const PvcCardSize({
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.slotsCount,
  });

  PdfPageFormat get pageFormat => PdfPageFormat(
        widthMm * PdfPageFormat.mm,
        heightMm * PdfPageFormat.mm,
        marginAll: 0,
      );
}

/// Printing mode for the PVC card
enum PvcPrintMode {
  /// Both Recto (Patient & QR) and Verso (First appointment on virgin card)
  both,

  /// Recto only (e.g. Card creation or card replacement)
  frontOnly,

  /// Verso only: prints ONLY the targeted slot (e.g. Slot 2, 3, 4) at the exact vertical coordinate.
  /// The rest of the card is left pure blank to avoid overwriting existing data.
  backSlotOnly,

  /// Verso with full grid and all appointments up to target slot.
  backFull,
}

/// Helper model representing an appointment entry on the back of the card
class PvcCardAppointmentEntry {
  final int slotIndex;
  final DateTime date;
  final String? reason;
  final String doctorName;
  final bool isAlreadyPrinted;

  const PvcCardAppointmentEntry({
    required this.slotIndex,
    required this.date,
    this.reason,
    required this.doctorName,
    this.isAlreadyPrinted = false,
  });
}

/// Main service for generating PVC Appointment Card PDFs
class PvcAppointmentCardPdf {
  /// Generate the PDF Document according to the chosen card format and print mode
  static Future<Uint8List> generate({
    required Patient patient,
    required Appointment currentAppointment,
    List<Appointment> previousAppointments = const [],
    PvcCardSize cardSize = PvcCardSize.cr80,
    PvcPrintMode printMode = PvcPrintMode.both,
    int targetSlotIndex = 1,
    String clinicName = 'CLINIQUE MÉDICALE CHIFA',
    String clinicAddress = 'Cabinet Médical Chifa',
    String clinicPhone = '05 50 00 00 00',
    String doctorName = 'Dr. Médecin Traitant',
  }) async {
    final pdf = pw.Document();

    // Fonts setup
    pw.Font baseFont = pw.Font.helvetica();
    pw.Font boldFont = pw.Font.helveticaBold();

    try {
      final regData = await rootBundle.load(
        'assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Regular.ttf',
      );
      final bldData = await rootBundle.load(
        'assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Bold.ttf',
      );
      baseFont = pw.Font.ttf(regData);
      boldFont = pw.Font.ttf(bldData);
    } catch (_) {
      try {
        const regPath =
            'assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Regular.ttf';
        const bldPath =
            'assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Bold.ttf';

        final regFile = File(regPath);
        final bldFile = File(bldPath);
        if (await regFile.exists() && await bldFile.exists()) {
          final regBytes = await regFile.readAsBytes();
          final bldBytes = await bldFile.readAsBytes();
          baseFont = pw.Font.ttf(regBytes.buffer.asByteData());
          boldFont = pw.Font.ttf(bldBytes.buffer.asByteData());
        }
      } catch (_) {
        // Fallback to standard Helvetica if custom font loading fails
      }
    }

    // Build the list of appointment entries for the slots
    final List<PvcCardAppointmentEntry?> slots = List.filled(
      cardSize.slotsCount,
      null,
      growable: false,
    );

    // Map historical appointments to slots before the target slot
    final sortedPast = List<Appointment>.from(previousAppointments)
      ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

    int slotIdx = 1;
    for (final pastApp in sortedPast) {
      if (pastApp.appointmentId == currentAppointment.appointmentId) continue;
      if (slotIdx >= targetSlotIndex || slotIdx > cardSize.slotsCount) break;

      slots[slotIdx - 1] = PvcCardAppointmentEntry(
        slotIndex: slotIdx,
        date: pastApp.appointmentDate,
        reason: pastApp.notes,
        doctorName: doctorName,
        isAlreadyPrinted: true,
      );
      slotIdx++;
    }

    // Assign current appointment to the target slot
    final safeTargetSlot = targetSlotIndex.clamp(1, cardSize.slotsCount);
    slots[safeTargetSlot - 1] = PvcCardAppointmentEntry(
      slotIndex: safeTargetSlot,
      date: currentAppointment.appointmentDate,
      reason: currentAppointment.notes,
      doctorName: doctorName,
      isAlreadyPrinted: false,
    );

    // 1. RECTO (FRONT) PAGE
    if (printMode == PvcPrintMode.both || printMode == PvcPrintMode.frontOnly) {
      pdf.addPage(
        pw.Page(
          pageFormat: cardSize.pageFormat,
          build: (context) => _buildFrontPage(
            patient: patient,
            clinicName: clinicName,
            clinicAddress: clinicAddress,
            clinicPhone: clinicPhone,
            cardSize: cardSize,
            baseFont: baseFont,
            boldFont: boldFont,
          ),
        ),
      );
    }

    // 2. VERSO (BACK) PAGE
    if (printMode == PvcPrintMode.both ||
        printMode == PvcPrintMode.backSlotOnly ||
        printMode == PvcPrintMode.backFull) {
      pdf.addPage(
        pw.Page(
          pageFormat: cardSize.pageFormat,
          build: (context) => _buildBackPage(
            cardSize: cardSize,
            slots: slots,
            targetSlotIndex: safeTargetSlot,
            selectiveSlotOnly: printMode == PvcPrintMode.backSlotOnly,
            clinicPhone: clinicPhone,
            baseFont: baseFont,
            boldFont: boldFont,
          ),
        ),
      );
    }

    return pdf.save();
  }

  /// Front Side of the PVC Card (Patient ID, Detailed Profile & QR Code)
  static pw.Widget _buildFrontPage({
    required Patient patient,
    required String clinicName,
    required String clinicAddress,
    required String clinicPhone,
    required PvcCardSize cardSize,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isLarge = cardSize != PvcCardSize.cr80;

    // Premium Medical Palette
    const primaryNavy = PdfColor.fromInt(0xFF0C4A7E); // Deep Navy Blue
    const primaryMedium = PdfColor.fromInt(0xFF0F5B9E); // Chifa Blue
    const accentCyan = PdfColor.fromInt(0xFF0284C7); // Sky Accent
    const accentGreen = PdfColor.fromInt(0xFF10B981); // Emerald Green Accent
    const darkText = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const mediumText = PdfColor.fromInt(0xFF334155); // Slate 700
    const mutedText = PdfColor.fromInt(0xFF64748B); // Slate 500
    const borderColor = PdfColor.fromInt(0xFFCBD5E1); // Slate 300
    const lightBg = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const pillBg = PdfColor.fromInt(0xFFF1F5F9); // Slate 100

    // Initials for Patient Avatar
    final initialFirst = patient.firstName.trim().isNotEmpty
        ? patient.firstName.trim()[0].toUpperCase()
        : '';
    final initialLast = patient.lastName.trim().isNotEmpty
        ? patient.lastName.trim()[0].toUpperCase()
        : '';
    final initials = (initialFirst + initialLast).isEmpty
        ? 'P'
        : (initialFirst + initialLast);

    // QR Data: Structured JSON for clinic scanner
    final qrPayload = jsonEncode({
      'chifa_id': patient.patientId,
      'nom': patient.lastName,
      'prenom': patient.firstName,
      'sexe': patient.gender == Gender.male ? 'M' : 'F',
      'dob': dateFormat.format(patient.dateOfBirth),
      'tel': patient.phone ?? '',
      'nin': patient.nationalId ?? '',
      'adresse': patient.address ?? '',
      'portal_url':
          'https://medevsync.com/chifa/?phone=${patient.phone ?? patient.patientId}&pin=${patient.dateOfBirth.year}',
      'uuid': patient.uuid ?? '',
      'cree_le': dateFormat.format(patient.createdAt),
    });

    final qrSize = isLarge ? 50.0 : 40.0;
    final patientNameSize = isLarge ? 11.0 : 9.0;
    final labelSize = isLarge ? 5.6 : 4.6;
    final valueSize = isLarge ? 6.8 : 5.8;

    final genderLabel = patient.gender == Gender.male
        ? 'Homme'
        : patient.gender == Gender.female
            ? 'Femme'
            : 'Autre';

    final hasNationalId =
        patient.nationalId != null && patient.nationalId!.trim().isNotEmpty;
    final hasPhone = patient.phone != null && patient.phone!.trim().isNotEmpty;
    final hasAddress =
        patient.address != null && patient.address!.trim().isNotEmpty;
    final hasAtcd = patient.atcd.trim().isNotEmpty;
    final hasSuivi = patient.suiviPathologies != null &&
        patient.suiviPathologies!.trim().isNotEmpty;

    return pw.Container(
      padding: pw.EdgeInsets.all(isLarge ? 7.5 : 5.5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: borderColor, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. HEADER STRIP
          pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: isLarge ? 8 : 6,
              vertical: isLarge ? 4.5 : 3.0,
            ),
            decoration: const pw.BoxDecoration(
              color: primaryNavy,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    // Stylized Medical Cross Emblem
                    pw.Container(
                      width: isLarge ? 13 : 10,
                      height: isLarge ? 13 : 10,
                      margin: const pw.EdgeInsets.only(right: 5),
                      decoration: const pw.BoxDecoration(
                        color: accentCyan,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '+',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: isLarge ? 8.5 : 7.0,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          clinicName.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: isLarge ? 8.5 : 7.2,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                        pw.Text(
                          'CARTE DE SANTÉ & RENDEZ-VOUS',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFFE2E8F0),
                            fontSize: isLarge ? 5.2 : 4.4,
                            font: baseFont,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Dossier ID Capsule Badge
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(
                    horizontal: isLarge ? 5.5 : 4.0,
                    vertical: isLarge ? 2.2 : 1.5,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2.5)),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'DOSSIER ',
                        style: pw.TextStyle(
                          color: mutedText,
                          fontSize: isLarge ? 5.2 : 4.4,
                          fontWeight: pw.FontWeight.bold,
                          font: boldFont,
                        ),
                      ),
                      pw.Text(
                        '#${patient.patientId?.toString().padLeft(4, '0') ?? '0000'}',
                        style: pw.TextStyle(
                          color: primaryNavy,
                          fontSize: isLarge ? 7.0 : 6.0,
                          fontWeight: pw.FontWeight.bold,
                          font: boldFont,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Double Accent Stripe (Cyan + Emerald)
          pw.Container(
            height: 1.5,
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(color: accentCyan),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Container(color: accentGreen),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: isLarge ? 3.5 : 2.5),

          // 2. MAIN BODY (Patient details left, QR code right)
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Left Column: Comprehensive Patient Details
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Patient Header (Avatar + Name + Pills)
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Initials Avatar Circle
                          pw.Container(
                            width: isLarge ? 22 : 18,
                            height: isLarge ? 22 : 18,
                            decoration: const pw.BoxDecoration(
                              color: primaryMedium,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                initials,
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: isLarge ? 9.0 : 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  font: boldFont,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 4.5),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  '${patient.lastName.toUpperCase()} ${patient.firstName}',
                                  style: pw.TextStyle(
                                    color: primaryNavy,
                                    fontSize: patientNameSize,
                                    fontWeight: pw.FontWeight.bold,
                                    font: boldFont,
                                  ),
                                  maxLines: 1,
                                ),
                                pw.SizedBox(height: 1.5),
                                pw.Row(
                                  children: [
                                    _buildPillTag(
                                      text: genderLabel.toUpperCase(),
                                      bgColor: pillBg,
                                      textColor: mediumText,
                                      fontSize: isLarge ? 5.2 : 4.4,
                                      boldFont: boldFont,
                                    ),
                                    pw.SizedBox(width: 3),
                                    _buildPillTag(
                                      text: patient.formattedAge.toUpperCase(),
                                      bgColor: pillBg,
                                      textColor: mediumText,
                                      fontSize: isLarge ? 5.2 : 4.4,
                                      boldFont: boldFont,
                                    ),
                                    pw.SizedBox(width: 3),
                                    _buildPillTag(
                                      text: hasNationalId ? 'ASSURÉ' : 'ACTIF',
                                      bgColor:
                                          const PdfColor.fromInt(0xFFECFDF5),
                                      textColor:
                                          const PdfColor.fromInt(0xFF047857),
                                      fontSize: isLarge ? 5.2 : 4.4,
                                      boldFont: boldFont,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Divider
                      pw.Container(
                        height: 0.5,
                        color: const PdfColor.fromInt(0xFFE2E8F0),
                        margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      ),

                      // 2-Column Info Grid
                      // Row 1: Date of Birth | National ID (NIN)
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: _buildDetailCell(
                              label: 'NÉ(E) LE',
                              value:
                                  '${dateFormat.format(patient.dateOfBirth)} (${patient.formattedAge})',
                              labelSize: labelSize,
                              valueSize: valueSize,
                              baseFont: baseFont,
                              boldFont: boldFont,
                              darkText: darkText,
                              mutedText: mutedText,
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Expanded(
                            child: _buildDetailCell(
                              label: 'N° IDENTIFIANT (NIN)',
                              value: hasNationalId
                                  ? patient.nationalId!
                                  : 'Non renseigné',
                              labelSize: labelSize,
                              valueSize: valueSize,
                              baseFont: baseFont,
                              boldFont: boldFont,
                              darkText: darkText,
                              mutedText: mutedText,
                            ),
                          ),
                        ],
                      ),

                      // Row 2: Telephone | Address
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: _buildDetailCell(
                              label: 'TÉLÉPHONE',
                              value:
                                  hasPhone ? patient.phone! : 'Non renseigné',
                              labelSize: labelSize,
                              valueSize: valueSize,
                              baseFont: baseFont,
                              boldFont: boldFont,
                              darkText: primaryNavy,
                              mutedText: mutedText,
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Expanded(
                            child: _buildDetailCell(
                              label: 'ADRESSE / VILLE',
                              value: hasAddress
                                  ? patient.address!
                                  : (patient.email?.isNotEmpty == true
                                      ? patient.email!
                                      : 'Non renseignée'),
                              labelSize: labelSize,
                              valueSize: valueSize,
                              baseFont: baseFont,
                              boldFont: boldFont,
                              darkText: darkText,
                              mutedText: mutedText,
                            ),
                          ),
                        ],
                      ),

                      // Row 3: Registered Since | Medical Notes/ATCD
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: _buildDetailCell(
                              label: 'INSCRIT LE',
                              value: dateFormat.format(patient.createdAt),
                              labelSize: labelSize,
                              valueSize: valueSize,
                              baseFont: baseFont,
                              boldFont: boldFont,
                              darkText: darkText,
                              mutedText: mutedText,
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Expanded(
                            child: _buildDetailCell(
                              label: 'ATCD / OBSERVATIONS',
                              value: hasAtcd
                                  ? patient.atcd
                                  : (hasSuivi
                                      ? patient.suiviPathologies!
                                      : 'Aucun antécédent noté'),
                              labelSize: labelSize,
                              valueSize: valueSize,
                              baseFont: baseFont,
                              boldFont: boldFont,
                              darkText: hasAtcd
                                  ? const PdfColor.fromInt(0xFFDC2626)
                                  : const PdfColor.fromInt(0xFF16A34A),
                              mutedText: mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 5),

                // Right Column: Stylized QR Container
                pw.Container(
                  width: isLarge ? 58 : 48,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    border: pw.Border.all(color: borderColor, width: 0.7),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(3.5)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'SCAN RAPIDE',
                        style: pw.TextStyle(
                          color: primaryNavy,
                          fontSize: isLarge ? 5.2 : 4.4,
                          fontWeight: pw.FontWeight.bold,
                          font: boldFont,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrPayload,
                        width: qrSize,
                        height: qrSize,
                        color: darkText,
                        drawText: false,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 2.5,
                          vertical: 1,
                        ),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(2)),
                        ),
                        child: pw.Text(
                          'ID: #${patient.patientId ?? 0} • PIN: ${patient.dateOfBirth.year}',
                          style: pw.TextStyle(
                            color: mutedText,
                            fontSize: isLarge ? 4.6 : 3.8,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: isLarge ? 2.5 : 1.5),

          // 3. FOOTER
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Tél: $clinicPhone | $clinicAddress',
                  style: pw.TextStyle(
                    color: mutedText,
                    fontSize: isLarge ? 5.2 : 4.3,
                    font: baseFont,
                  ),
                ),
                pw.Text(
                  'Carte personnelle - À présenter à l\'accueil',
                  style: pw.TextStyle(
                    color: primaryMedium,
                    fontSize: isLarge ? 5.0 : 4.2,
                    fontWeight: pw.FontWeight.bold,
                    font: boldFont,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPillTag({
    required String text,
    required PdfColor bgColor,
    required PdfColor textColor,
    required double fontSize,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          font: boldFont,
        ),
      ),
    );
  }

  static pw.Widget _buildDetailCell({
    required String label,
    required String value,
    required double labelSize,
    required double valueSize,
    required pw.Font baseFont,
    required pw.Font boldFont,
    required PdfColor darkText,
    required PdfColor mutedText,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: mutedText,
            fontSize: labelSize,
            font: boldFont,
          ),
        ),
        pw.SizedBox(height: 0.5),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: darkText,
            fontSize: valueSize,
            fontWeight: pw.FontWeight.bold,
            font: boldFont,
          ),
          maxLines: 1,
        ),
      ],
    );
  }

  /// Back Side of the PVC Card (Multi-Row Appointment Schedule)
  /// If [selectiveSlotOnly] is true: ONLY the row at [targetSlotIndex] is rendered!
  /// Everything else on the card is pure blank white to avoid overwriting previously printed slots.
  static pw.Widget _buildBackPage({
    required PvcCardSize cardSize,
    required List<PvcCardAppointmentEntry?> slots,
    required int targetSlotIndex,
    required bool selectiveSlotOnly,
    required String clinicPhone,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final isLarge = cardSize != PvcCardSize.cr80;

    const primaryColor = PdfColor.fromInt(0xFF0F5B9E);
    const darkText = PdfColor.fromInt(0xFF1E293B);
    const mutedText = PdfColor.fromInt(0xFF64748B);
    const borderColor = PdfColor.fromInt(0xFFCBD5E1);

    final titleSize = isLarge ? 7.5 : 6.5;
    final headerColSize = isLarge ? 6.2 : 5.0;
    final rowTextSize = isLarge ? 6.5 : 5.5;

    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: isLarge ? 8 : 6,
        vertical: isLarge ? 6 : 4,
      ),
      decoration: const pw.BoxDecoration(
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HEADER (Rendered only on full print; blank spacer if selective)
          if (!selectiveSlotOnly) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PROCHAINS RENDEZ-VOUS',
                  style: pw.TextStyle(
                    color: primaryColor,
                    fontSize: titleSize,
                    fontWeight: pw.FontWeight.bold,
                    font: boldFont,
                  ),
                ),
                pw.Text(
                  'En cas d\'empêchement, prévenir au : $clinicPhone',
                  style: pw.TextStyle(
                    color: mutedText,
                    fontSize: isLarge ? 5.2 : 4.4,
                    font: baseFont,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            // Table Column Headers
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderColor, width: 0.8),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 14,
                    child: pw.Text(
                      'N°',
                      style: pw.TextStyle(
                        fontSize: headerColSize,
                        fontWeight: pw.FontWeight.bold,
                        font: boldFont,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: isLarge ? 62 : 54,
                    child: pw.Text(
                      'DATE & HEURE',
                      style: pw.TextStyle(
                        fontSize: headerColSize,
                        fontWeight: pw.FontWeight.bold,
                        font: boldFont,
                        color: darkText,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'MOTIF / OBSERVATION',
                      style: pw.TextStyle(
                        fontSize: headerColSize,
                        fontWeight: pw.FontWeight.bold,
                        font: boldFont,
                        color: darkText,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: isLarge ? 64 : 56,
                    child: pw.Text(
                      'MÉDECIN / VISA',
                      style: pw.TextStyle(
                        fontSize: headerColSize,
                        fontWeight: pw.FontWeight.bold,
                        font: boldFont,
                        color: darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Keep identical vertical spacing for selective slot pass
            pw.SizedBox(height: isLarge ? 18.0 : 15.0),
          ],

          // 2. APPOINTMENT ROWS (Equally distributed across card height)
          pw.Expanded(
            child: pw.Column(
              children: List.generate(cardSize.slotsCount, (index) {
                final slotNumber = index + 1;
                final entry = slots[index];

                // If selective mode is on, ONLY draw the target slot, leave others as pure empty sized box
                if (selectiveSlotOnly && slotNumber != targetSlotIndex) {
                  return pw.Expanded(child: pw.Container());
                }

                // If not selective, or this is the target slot in selective mode:
                final isCurrentTarget = slotNumber == targetSlotIndex;
                final dateFormat = DateFormat('dd/MM/yyyy');
                final timeFormat = DateFormat('HH:mm');

                return pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      // In selective mode, avoid re-drawing borders over previously printed ones
                      border: selectiveSlotOnly
                          ? null
                          : const pw.Border(
                              bottom: pw.BorderSide(
                                color: borderColor,
                                width: 0.5,
                              ),
                            ),
                      color: (!selectiveSlotOnly && isCurrentTarget)
                          ? const PdfColor.fromInt(0xFFF8FAFC)
                          : null,
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Slot number
                        pw.SizedBox(
                          width: 14,
                          child: pw.Text(
                            '#$slotNumber',
                            style: pw.TextStyle(
                              fontSize: rowTextSize,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                              color: isCurrentTarget
                                  ? primaryColor
                                  : mutedText,
                            ),
                          ),
                        ),

                        // Date & Hour
                        pw.SizedBox(
                          width: isLarge ? 62 : 54,
                          child: entry != null
                              ? pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      dateFormat.format(entry.date),
                                      style: pw.TextStyle(
                                        fontSize: rowTextSize,
                                        fontWeight: pw.FontWeight.bold,
                                        font: boldFont,
                                        color: darkText,
                                      ),
                                    ),
                                    pw.Text(
                                      'à ${timeFormat.format(entry.date)}',
                                      style: pw.TextStyle(
                                        fontSize: rowTextSize - 0.8,
                                        font: baseFont,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                )
                              : pw.Text(
                                  '.... / .... / ........',
                                  style: pw.TextStyle(
                                    fontSize: rowTextSize - 1.0,
                                    color: PdfColor.fromInt(0xFFCBD5E1),
                                    font: baseFont,
                                  ),
                                ),
                        ),

                        // Reason / Motif
                        pw.Expanded(
                          child: entry != null
                              ? pw.Text(
                                  entry.reason?.isNotEmpty == true
                                      ? entry.reason!
                                      : 'Consultation',
                                  style: pw.TextStyle(
                                    fontSize: rowTextSize,
                                    font: baseFont,
                                    color: darkText,
                                  ),
                                  maxLines: 2,
                                  overflow: pw.TextOverflow.clip,
                                )
                              : pw.Text(
                                  '..................................................',
                                  style: pw.TextStyle(
                                    fontSize: rowTextSize - 1.0,
                                    color: PdfColor.fromInt(0xFFE2E8F0),
                                    font: baseFont,
                                  ),
                                ),
                        ),

                        // Doctor & Signature
                        pw.SizedBox(
                          width: isLarge ? 64 : 56,
                          child: entry != null
                              ? pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      entry.doctorName,
                                      style: pw.TextStyle(
                                        fontSize: rowTextSize - 0.6,
                                        fontWeight: pw.FontWeight.bold,
                                        font: boldFont,
                                        color: darkText,
                                      ),
                                      maxLines: 1,
                                    ),
                                    pw.Text(
                                      '[ Cachet ]',
                                      style: pw.TextStyle(
                                        fontSize: rowTextSize - 1.4,
                                        font: baseFont,
                                        color: mutedText,
                                      ),
                                    ),
                                  ],
                                )
                              : pw.Text(
                                  '........................',
                                  style: pw.TextStyle(
                                    fontSize: rowTextSize - 1.0,
                                    color: PdfColor.fromInt(0xFFE2E8F0),
                                    font: baseFont,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // 3. BOTTOM FOOTER (Rendered only on full print)
          if (!selectiveSlotOnly) ...[
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Prière de respecter les horaires de rendez-vous.',
                    style: pw.TextStyle(
                      color: mutedText,
                      fontSize: isLarge ? 5.2 : 4.4,
                      font: baseFont,
                    ),
                  ),
                  pw.Text(
                    'Application Chifa',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: isLarge ? 5.2 : 4.4,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            pw.SizedBox(height: isLarge ? 9.0 : 7.0),
          ],
        ],
      ),
    );
  }
}
