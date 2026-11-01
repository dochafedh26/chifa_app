import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/pdf_asset_helper.dart";


/// Generates the Bilan (Lab Test Order) PDF using the ordonnance background template.
Future<Uint8List> generateBilanPdf({
  required Patient patient,
  required String bilanText,
  DateTime? dateCreation,
  String? weight,
  PrintTemplate template = PrintTemplate.chifa,
}) async {
  final pdf = pw.Document();
  final dateStr = DateFormat(
    'dd/MM/yyyy',
  ).format(dateCreation ?? DateTime.now());

  // ───── Load background image & font ─────
  final imageBytes = await PdfAssetHelper.loadBytes(template.assetPath);
  final customFont = await PdfAssetHelper.loadBoldFont();
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 50),
        buildBackground: (context) {
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
                            : const pw.EdgeInsets.only(top: 50, right: 175),
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
                          weight != null ? '$weight kg' : '',
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
              if (template == PrintTemplate.chifa)
                pw.Center(
                  child: pw.Text(
                    'Ordonnance',
                    style: pw.TextStyle(
                      fontSize: 24,
                      font: customFont,
                      color: brandColor,
                    ),
                  ),
                ),
              if (template == PrintTemplate.chifa)
                pw.Center(
                  child: pw.SizedBox(
                    width: 140,
                    child: pw.Divider(color: brandColor, thickness: 1),
                  ),
                ),
              pw.SizedBox(height: 8),
            ],
          );
        } else {
          return pw.Column(
            children: [
              pw.SizedBox(height: 38),
              pw.Center(
                child: pw.Text(
                  'Demande d\'Analyses (suite)',
                  style: pw.TextStyle(
                    fontSize: 18,
                    font: customFont,
                    color: brandColor,
                  ),
                ),
              ),
              pw.Center(
                child: pw.SizedBox(
                  width: 140,
                  child: pw.Divider(color: brandColor, thickness: 1),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        }
      },
      // footer: (context) {
      //   final isLastPage = context.pageNumber == context.pagesCount;
      //   if (!isLastPage) return pw.SizedBox();
      //   return pw.Column(
      //     children: [
      //       pw.SizedBox(height: 30),
      //       pw.Divider(color: brandColor, thickness: 0.5),
      //       pw.SizedBox(height: 4),
      //       pw.Row(
      //         mainAxisAlignment: pw.MainAxisAlignment.end,
      //         children: [
      //           pw.Column(
      //             crossAxisAlignment: pw.CrossAxisAlignment.center,
      //             children: [
      //               pw.Text(
      //                 'Signature et cachet',
      //                 style: pw.TextStyle(fontSize: 8, color: brandColor),
      //               ),
      //               pw.SizedBox(height: 20),
      //             ],
      //           ),
      //         ],
      //       ),
      //     ],
      //   );
      // },
      build: (context) {
        List<String> testsList = bilanText.split('\n');
        return [
          pw.SizedBox(height: 10),
          ...testsList.where((test) => test.trim().isNotEmpty).map((test) {
            int index = testsList.indexOf(test);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${index + 1}. ',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      test.trim(),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ];
      },
    ),
  );

  return pdf.save();
}
