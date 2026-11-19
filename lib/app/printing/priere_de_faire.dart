import "package:chifa/services/db/models/models.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/pdf_asset_helper.dart";

/// Generates the "PRIÈRE DE FAIRE" PDF using the ordonnance background template.
Future<Uint8List> generatePriereDeFairePdf({
  required Patient patient,
  String? weight,
  required String demandText,
  PrintTemplate template = PrintTemplate.chifa,
  bool includeDate = true,
  DateTime? date,
}) async {
  final pdf = pw.Document();
  final printDate = date ?? DateTime.now();
  final dateStr =
      '${printDate.day.toString().padLeft(2, '0')}/${printDate.month.toString().padLeft(2, '0')}/${printDate.year}';

  // Load template background image and Unicode-safe fonts
  final imageBytes = await PdfAssetHelper.loadBytes(template.assetPath);
  final regularFont = await PdfAssetHelper.loadRegularFont();
  final boldFont = await PdfAssetHelper.loadBoldFont();
  final brandColor = PdfColor.fromHex('#1A7CC5');
  final titleColor =
      template == PrintTemplate.chifa ? brandColor : PdfColors.black;

  final pdfImage = pw.MemoryImage(imageBytes);
  final normalizedWeight = weight != null && weight.trim().isNotEmpty
      ? '${weight.trim()} kg'
      : '';

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 50),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        buildBackground: (context) {
          if (context.pageNumber == 1) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
            );
          }
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
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
                      pw.Opacity(
                        opacity: includeDate ? 1.0 : 0.0,
                        child: pw.Padding(
                          padding: template == PrintTemplate.chifa
                              ? const pw.EdgeInsets.only(top: 16, right: 20)
                              : const pw.EdgeInsets.only(top: 50, right: 175),
                          child: pw.Text(
                            dateStr,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
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
                          normalizedWeight,
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
              pw.Center(
                child: pw.Text(
                  'PRIÈRE DE FAIRE',
                  style: pw.TextStyle(
                    fontSize: template == PrintTemplate.chifa ? 22 : 18,
                    font: boldFont,
                    color: titleColor,
                  ),
                ),
              ),
              pw.Center(
                child: pw.SizedBox(
                  width: template == PrintTemplate.chifa ? 200 : 170,
                  child: pw.Divider(color: titleColor, thickness: 1),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'PRIÈRE DE FAIRE — ${patient.firstName} ${patient.lastName}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: titleColor,
                    ),
                    maxLines: 1,
                  ),
                ),
                pw.Row(
                  children: [
                    pw.Text(
                      'Age: ${patient.formattedAge}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    pw.Opacity(
                      opacity: includeDate ? 1.0 : 0.0,
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 20),
                          pw.Text(
                            'Date: $dateStr',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: titleColor, thickness: 1),
            pw.SizedBox(height: 10),
          ],
        );
      },
      build: (context) {
        final lines = demandText
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n');
        final widgets = <pw.Widget>[pw.SizedBox(height: 10)];

        for (final rawLine in lines) {
          if (rawLine.trim().isEmpty) {
            widgets.add(pw.SizedBox(height: 8));
            continue;
          }

          final trimmedLeft = rawLine.trimLeft();
          final bulletMatch = RegExp(r'^[\-\*•]\s+').firstMatch(trimmedLeft);

          if (bulletMatch != null) {
            final itemText = trimmedLeft.substring(bulletMatch.end).trimRight();
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 12,
                      child: pw.Text(
                        '•',
                        style: pw.TextStyle(
                          fontSize: 11,
                          font: boldFont,
                          color: titleColor,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        itemText,
                        style: pw.TextStyle(
                          fontSize: 11,
                          font: regularFont,
                          lineSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Text(
                  rawLine.trimRight(),
                  style: pw.TextStyle(
                    fontSize: 11,
                    font: regularFont,
                    lineSpacing: 3,
                  ),
                ),
              ),
            );
          }
        }

        return widgets;
      },
    ),
  );

  return pdf.save();
}
