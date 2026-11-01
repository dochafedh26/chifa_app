import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/rich_text_pdf_renderer.dart";
import "package:chifa/app/printing/pdf_asset_helper.dart";

Future<Uint8List> generateCoupsEtBlessuresPdf({
  required Patient patient,
  required CertificatCoupsEtBlessures cert,
  PrintTemplate template = PrintTemplate.chifa,
}) async {
  final pdf = pw.Document();
  final dateFormat = DateFormat('dd/MM/yyyy');
  final dateConsultationStr = dateFormat.format(cert.dateConsultation);
  final heureConsultationStr = DateFormat('HH:mm').format(cert.dateConsultation);

  // ───── Load background image & fonts ─────
  final imageBytes = await PdfAssetHelper.loadBytes(template.assetPath);
  final regularFont = await PdfAssetHelper.loadRegularFont();
  final boldFont = await PdfAssetHelper.loadBoldFont();
  final customFont = boldFont;
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  // ───── Text styles ─────
  final boldStyle = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);
  const normalStyle = pw.TextStyle(fontSize: 8.5);

  final pageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 25),
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    buildBackground: (context) {
      return pw.FullPage(
        ignoreMargins: true,
        child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
      );
    },
  );

  pw.Widget buildHeader() {
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
                      cert.agePatient != null ? '${cert.agePatient} ans' : patient.formattedAge,
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
                    dateConsultationStr,
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
                      cert.agePatient != null ? '${cert.agePatient} ans' : patient.formattedAge,
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
              'CERTIFICAT MEDICAL INITIAL DE CONSTATATION',
              style: pw.TextStyle(
                fontSize: 11,
                font: customFont,
                color: brandColor,
              ),
            ),
          ),
          pw.Center(
            child: pw.Text(
              '(Coups et Blessures)',
              style: pw.TextStyle(
                fontSize: 9,
                font: regularFont,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Center(
            child: pw.SizedBox(
              width: 220,
              child: pw.Divider(color: brandColor, thickness: 0.8),
            ),
          ),
        ],
        pw.SizedBox(height: 4),
      ],
    );
  }

  // Type options
  final typesAccidentList = [
    'Coups et blessures volontaires',
    'Coups et blessures involontaires',
    'Accident de la circulation',
    'Accident de la voie publique',
    'Accident du travail',
    'Violences sexuelles',
    'Autres',
  ];

  final dateFaitsStr = cert.dateFaits != null ? dateFormat.format(cert.dateFaits!) : '...................';
  final heureFaitsStr = cert.heureFaits ?? '.........';

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      header: (context) => buildHeader(),
      build: (context) => [
        pw.SizedBox(height: 4),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Je soussigné(e), docteur en médecine, certifie avoir reçu à ma consultation, ce jour, le '),
              pw.TextSpan(text: dateConsultationStr, style: boldStyle),
              const pw.TextSpan(text: ' à '),
              pw.TextSpan(text: heureConsultationStr, style: boldStyle),
              const pw.TextSpan(text: ', un sujet qui me déclare se nommer : '),
              pw.TextSpan(text: patient.fullName, style: boldStyle),
              const pw.TextSpan(text: ', être âgé(e) de '),
              pw.TextSpan(
                text: cert.agePatient != null ? '${cert.agePatient} ans.' : '${patient.formattedAge}.',
                style: boldStyle,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Il me déclare être victime le '),
              pw.TextSpan(text: dateFaitsStr, style: boldStyle),
              const pw.TextSpan(text: ' à '),
              pw.TextSpan(text: heureFaitsStr, style: boldStyle),
              const pw.TextSpan(text: ' heures de :'),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: typesAccidentList.map((t) {
            final isChecked = cert.typeAccident.contains(t) ||
                (t == 'Autres' && cert.typeAccident == 'Autres');
            final checkStr = isChecked ? '[X]' : '[  ]';
            if (t == 'Autres') {
              final autresTxt = (cert.autresAccident != null && cert.autresAccident!.isNotEmpty)
                  ? cert.autresAccident!
                  : '...................................................';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10, top: 1),
                child: pw.Text('$checkStr Autres : $autresTxt', style: isChecked ? boldStyle : normalStyle),
              );
            }
            return pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, top: 1),
              child: pw.Text('$checkStr $t', style: isChecked ? boldStyle : normalStyle),
            );
          }).toList(),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Signes subjectifs :', style: boldStyle),
        pw.SizedBox(height: 2),
        if (cert.signesSubjectifs != null && cert.signesSubjectifs!.isNotEmpty)
          ...parseDeltaToPdfWidgets(
            text: cert.signesSubjectifs!,
            baseStyle: normalStyle,
            boldFont: boldFont,
            regularFont: regularFont,
          )
        else
          pw.Text('Néant.', style: normalStyle),
        pw.SizedBox(height: 6),
        pw.Text('Examen clinique :', style: boldStyle),
        pw.SizedBox(height: 2),
        if (cert.examenClinique != null && cert.examenClinique!.isNotEmpty)
          ...parseDeltaToPdfWidgets(
            text: cert.examenClinique!,
            baseStyle: normalStyle,
            boldFont: boldFont,
            regularFont: regularFont,
          )
        else
          pw.Text('Néant.', style: normalStyle),
        pw.SizedBox(height: 6),
        pw.Text('Son état de santé nécessite :', style: boldStyle),
        pw.SizedBox(height: 2),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10),
          child: pw.Text(
            '${cert.necessiteTraitement ? "[X]" : "[  ]"} Un traitement.',
            style: cert.necessiteTraitement ? boldStyle : normalStyle,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 1),
          child: pw.Text(
            '${cert.arretDeTravailJours != null ? "[X]" : "[  ]"} Un arrêt de travail de : ${cert.arretDeTravailJours != null ? "${cert.arretDeTravailJours} jours" : "........................"}',
            style: cert.arretDeTravailJours != null ? boldStyle : normalStyle,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 1),
          child: pw.Text(
            '${(cert.avisSpecialise != null && cert.avisSpecialise!.isNotEmpty) ? "[X]" : "[  ]"} Un avis spécialisé : ${(cert.avisSpecialise != null && cert.avisSpecialise!.isNotEmpty) ? cert.avisSpecialise! : "........................"}',
            style: (cert.avisSpecialise != null && cert.avisSpecialise!.isNotEmpty) ? boldStyle : normalStyle,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 1),
          child: pw.Text(
            '${cert.ittJours != null ? "[X]" : "[  ]"} Une incapacité temporaire totale (ITT) de : ${cert.ittJours != null ? "${cert.ittJours} jours" : "........................"}',
            style: cert.ittJours != null ? boldStyle : normalStyle,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Certificat établi à la demande de l\'intéressé(e) et remis en mains propres pour servir et valoir ce que de droit.',
          style: normalStyle,
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Fait le $dateConsultationStr', style: normalStyle),
                pw.SizedBox(height: 4),
                pw.Text('Signature et cachet du médecin', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}
