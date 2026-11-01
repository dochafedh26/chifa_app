import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/pdf_asset_helper.dart";

/// Generates the Appointment Slip / Fiche de Rendez-vous PDF for the patient.
Future<Uint8List> generateAppointmentPdf({
  required Patient patient,
  required Appointment appointment,
  PrintTemplate template = PrintTemplate.chifa,
  String? doctorName,
}) async {
  final pdf = pw.Document();
  final shortDateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  final appointmentDateStr = shortDateFormat.format(appointment.appointmentDate);
  final appointmentTimeStr = timeFormat.format(appointment.appointmentDate);
  final dateEmissionStr = shortDateFormat.format(DateTime.now());

  // Load background image & fonts
  final imageBytes = await PdfAssetHelper.loadBytes(template.assetPath);
  final regularFont = await PdfAssetHelper.loadRegularFont();
  final boldFont = await PdfAssetHelper.loadBoldFont();
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold);
  final normalStyle = pw.TextStyle(font: regularFont, fontSize: 11);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 25),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        buildBackground: (context) {
          if (context.pageNumber > 1) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: PdfColors.white),
            );
          }
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
          );
        },
      ),
      header: (context) {
        final isFirstPage = context.pageNumber == 1;
        if (isFirstPage) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 75.8267716535433),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: template == PrintTemplate.chifa
                            ? const pw.EdgeInsets.only(top: 16, left: 24)
                            : const pw.EdgeInsets.only(top: 30, left: 24),
                        child: pw.Text(
                          patient.lastName,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                      ),
                      pw.SizedBox(
                        height: template == PrintTemplate.chifa ? 26 : 0,
                      ),
                      pw.Padding(
                        padding: template == PrintTemplate.chifa
                            ? const pw.EdgeInsets.only(left: 34)
                            : const pw.EdgeInsets.only(left: 37),
                        child: pw.Text(
                          patient.firstName,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Padding(
                        padding: template == PrintTemplate.chifa
                            ? const pw.EdgeInsets.only(top: 16, right: 20)
                            : const pw.EdgeInsets.only(top: 50, right: 165),
                        child: pw.Text(
                          dateEmissionStr,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      if (template == PrintTemplate.chifa)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 40),
                          child: pw.Text(
                            patient.formattedAge != 'N/A' ? patient.formattedAge : '',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 38),
              if (template == PrintTemplate.chifa) ...[
                pw.Center(
                  child: pw.Text(
                    'FICHE DE RENDEZ-VOUS',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                      color: brandColor,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.SizedBox(
                    width: 200,
                    child: pw.Divider(color: brandColor, thickness: 1),
                  ),
                ),
              ],
              pw.SizedBox(height: 12),
            ],
          );
        }
        return pw.SizedBox();
      },
      build: (context) {
        return [
          // Appointment Date & Time Box
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              color: PdfColor.fromHex('#F8FAFC'),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'VOTRE PROCHAIN RENDEZ-VOUS EST FIXÉ LE :',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 11,
                    color: PdfColors.grey800,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: brandColor,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'Date : ',
                            style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 13),
                          ),
                          pw.Text(
                            appointmentDateStr,
                            style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#0F172A'),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'Heure : ',
                            style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 13),
                          ),
                          pw.Text(
                            appointmentTimeStr,
                            style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (appointment.notes != null && appointment.notes!.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Note / Remarque :', style: boldStyle),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      appointment.notes!,
                      style: normalStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Instructions for patient
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFFBEB'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromHex('#FCD34D'), width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Consignes importantes :',
                  style: pw.TextStyle(font: boldFont, fontSize: 10.5, color: PdfColor.fromHex('#92400E')),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '• Veuillez vous présenter 10 à 15 minutes avant l\'heure fixée.',
                  style: pw.TextStyle(font: regularFont, fontSize: 9.5, color: PdfColor.fromHex('#78350F')),
                ),
                pw.Text(
                  '• En cas d\'empêchement, merci d\'annuler ou de reporter au moins 24h à l\'avance.',
                  style: pw.TextStyle(font: regularFont, fontSize: 9.5, color: PdfColor.fromHex('#78350F')),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Signature & Cachet', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                  pw.SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ];
      },
    ),
  );

  return pdf.save();
}
