import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/pdf_asset_helper.dart";

Future<Uint8List> generateInterpretationEcgPdf({
  required Patient patient,
  required InterpretationEcg ecg,
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
  final redAccent = PdfColor.fromHex('#C53030');

  final pdfImage = pw.MemoryImage(imageBytes);

  // ───── Text styles ─────
  final boldStyle = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);
  const normalStyle = pw.TextStyle(fontSize: 9.5);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 30),
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
                    'COMPTE RENDU D\'ÉLECTROCARDIOGRAMME',
                    style: pw.TextStyle(
                      fontSize: 14,
                      font: boldFont,
                      color: redAccent,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'INTERPRÉTATION ÉLECTRIQUE (ECG 12 DÉRIVATIONS)',
                    style: pw.TextStyle(
                      fontSize: 10,
                      font: boldFont,
                      color: brandColor,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.SizedBox(
                    width: 250,
                    child: pw.Divider(color: brandColor, thickness: 1),
                  ),
                ),
              ],
              pw.SizedBox(height: 6),
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
                  'Compte Rendu ECG — ${patient.fullName}',
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
        pw.SizedBox(height: 10),

        // Indication / Motif
        if (ecg.motif != null && ecg.motif!.trim().isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Row(
              children: [
                pw.Text('Indication / Motif : ', style: boldStyle),
                pw.Expanded(
                  child: pw.Text(
                    ecg.motif!.trim(),
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: brandColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
        ],

        // Paramètres Électrocardiographiques (Tableau structuré)
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PARAMÈTRES ÉLECTROCARDIOGRAPHIQUES', style: boldStyle),
                    pw.Text('VALEURS & CONSTATATIONS', style: boldStyle),
                  ],
                ),
              ),
              pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey300),

              // Rows
              _buildTableRow('Rythme cardiaque', ecg.rythme, isBoldVal: true),
              _buildTableRow('Fréquence cardiaque', '${ecg.frequenceCardiaque} bpm', isBoldVal: true),
              _buildTableRow('Axe électrique QRS', ecg.axeQrs),
              _buildTableRow('Onde P (auriculogramme)', ecg.ondeP),
              _buildTableRow('Intervalle PR (conduction AV)', ecg.espacePr),
              _buildTableRow('Complexe QRS (ventriculogramme)', ecg.complexeQrs),
              _buildTableRow('Segment ST (repolarisation précoce)', ecg.segmentSt),
              _buildTableRow('Onde T (repolarisation ventriculaire)', ecg.ondeT),
              _buildTableRow('Intervalle QT / QTc', ecg.intervalleQt),
            ],
          ),
        ),

        pw.SizedBox(height: 12),

        // Cadre Conclusion (Mise en avant clinique)
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: brandColor, width: 1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'CONCLUSION ÉLECTROCARDIOGRAPHIQUE :',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: brandColor,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                ecg.conclusion,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        if (ecg.remarques != null && ecg.remarques!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: 'Remarques / Conduite à tenir : ', style: boldStyle),
                  pw.TextSpan(text: ecg.remarques!.trim(), style: normalStyle),
                ],
              ),
            ),
          ),
        ],

        pw.SizedBox(height: 20),

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

pw.Widget _buildTableRow(String label, String value, {bool isBoldVal = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
    ),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 170,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBoldVal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );
}

