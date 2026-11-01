import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/pdf_asset_helper.dart";

Future<Uint8List> generateAptitudeSportPdf({
  required Patient patient,
  required String sport,
  required String typePratique,
  String? examenClinique,
  String? remarques,
  required DateTime dateCreation,
  String? weight,
  PrintTemplate template = PrintTemplate.chifa,
}) async {
  final pdf = pw.Document();
  final dateFormat = DateFormat('dd/MM/yyyy');
  final dateStr = dateFormat.format(dateCreation);

  // ───── Load background image & fonts ─────
  final imageBytes = await PdfAssetHelper.loadBytes(template.assetPath);
  final regularFont = await PdfAssetHelper.loadRegularFont();
  final boldFont = await PdfAssetHelper.loadBoldFont();
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  // ───── Text styles ─────
  final boldStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  const normalStyle = pw.TextStyle(fontSize: 10);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 35),
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
                          ),
                        ),
                      ),
                      if (template == PrintTemplate.eph)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 65),
                          child: pw.Text(
                            patient.formattedAge,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
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
                          dateStr,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      if (template == PrintTemplate.chifa)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 40),
                          child: pw.Text(
                            patient.formattedAge,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      pw.SizedBox(height: 10),
                      pw.Padding(
                        padding: template == PrintTemplate.chifa
                            ? const pw.EdgeInsets.only(right: 40)
                            : const pw.EdgeInsets.only(top: -15, right: 175),
                        child: pw.Text(
                          weight != null && weight.isNotEmpty ? '$weight kg' : '',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
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
                    'CERTIFICAT MEDICAL D\'APTITUDE',
                    style: pw.TextStyle(
                      fontSize: 15,
                      font: boldFont,
                      color: brandColor,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'À LA PRATIQUE SPORTIVE',
                    style: pw.TextStyle(
                      fontSize: 13,
                      font: boldFont,
                      color: brandColor,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.SizedBox(
                    width: 220,
                    child: pw.Divider(color: brandColor, thickness: 1),
                  ),
                ),
              ],
              pw.SizedBox(height: 8),
            ],
          );
        }
        return pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          margin: const pw.EdgeInsets.only(bottom: 16),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Aptitude Sport — ${patient.fullName}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                '${patient.formattedAge}  •  $dateStr',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
            ],
          ),
        );
      },
      build: (context) => [
        pw.SizedBox(height: 16),

        // Identification du médecin
        pw.RichText(
          text: pw.TextSpan(
            children: [
              const pw.TextSpan(
                text: 'Je soussigné(e), Docteur, ',
                style: normalStyle,
              ),
              pw.TextSpan(
                text: template == PrintTemplate.chifa
                    ? 'DR HERHOUR MOHAMED'.toUpperCase()
                    : 'DR CHIKH TOUAMI.H',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  font: boldFont,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Certifie avoir examiné
        pw.Text(
          'Certifie avoir examiné ce jour :',
          style: normalStyle,
        ),
        pw.SizedBox(height: 8),

        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('Nom & Prénom : ', style: normalStyle),
                  pw.Text(patient.fullName, style: boldStyle),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Text('Âge : ', style: normalStyle),
                  pw.Text(patient.formattedAge, style: boldStyle),
                  pw.SizedBox(width: 16),
                  if (patient.gender != null) ...[
                    pw.Text('Sexe : ', style: normalStyle),
                    pw.Text(
                      patient.gender == Gender.male ? 'Masculin' : 'Féminin',
                      style: boldStyle,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 14),

        // Attestation
        pw.Text(
          'Et atteste que l\'examen clinique de ce jour ne révèle aucune contre-indication apparente à la pratique des activités physiques et sportives :',
          style: normalStyle,
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 12),

        // Détails de la pratique
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: brandColor, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 120,
                    child: pw.Text('Discipline sportive :', style: boldStyle),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      sport.isNotEmpty ? sport : 'Toutes disciplines sportives',
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: brandColor,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 120,
                    child: pw.Text('Type de pratique :', style: boldStyle),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      typePratique.isNotEmpty ? typePratique : 'Entraînement et Loisir',
                      style: normalStyle,
                    ),
                  ),
                ],
              ),
              if (examenClinique != null && examenClinique.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 120,
                      child: pw.Text('Examen clinique :', style: boldStyle),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        examenClinique.trim(),
                        style: normalStyle,
                      ),
                    ),
                  ],
                ),
              ],
              if (remarques != null && remarques.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 120,
                      child: pw.Text('Observations :', style: boldStyle),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        remarques.trim(),
                        style: normalStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        pw.SizedBox(height: 14),
        pw.Text(
          'Ce certificat est délivré à la demande de l\'intéressé(e) en main propre pour servir et valoir ce que de droit.',
          style: normalStyle,
        ),
        pw.SizedBox(height: 24),

        // Footer Date & Signature
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Fait le $dateStr', style: normalStyle),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Signature et cachet du médecin',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

