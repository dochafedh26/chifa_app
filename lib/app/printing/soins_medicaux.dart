import "package:chifa/services/db/models/models.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/pdf_asset_helper.dart";


/// Generates the Soins Médicaux PDF and returns the bytes
Future<Uint8List> generateSoinsMedicauxPdf({
  required Patient patient,
  String? weight,
  required String soinsText,
  PrintTemplate template = PrintTemplate.chifa,
}) async {
  final pdf = pw.Document();
  final now = DateTime.now();
  final dateStr =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

  // Load the template background image and font
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
              if (template == PrintTemplate.chifa) ...[
                pw.Center(
                  child: pw.Text(
                    'Soins Médicaux',
                    style: pw.TextStyle(
                      fontSize: 24,
                      font: customFont,
                      color: brandColor,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.SizedBox(
                    width: 170, // Slightly wider for this title
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
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: brandColor, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Soins Médicaux — ${patient.firstName} ${patient.lastName}',
                  style: pw.TextStyle(fontSize: 9, color: brandColor),
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                '${patient.formattedAge}  •  $dateStr',
                style: pw.TextStyle(fontSize: 9, color: brandColor),
              ),
            ],
          ),
        );
      },

      // footer: (context) {
      //   final isLastPage = context.pageNumber == context.pagesCount;
      //   if (isLastPage) {
      //     return pw.Column(
      //       children: [
      //         pw.SizedBox(height: 30),
      //         pw.Divider(color: brandColor, thickness: 0.5),
      //         pw.SizedBox(height: 4),
      //         pw.Row(
      //           mainAxisAlignment: pw.MainAxisAlignment.end,
      //           children: [
      //             pw.Column(
      //               crossAxisAlignment: pw.CrossAxisAlignment.center,
      //               children: [
      //                 pw.Text(
      //                   'Signature et cachet',
      //                   style: pw.TextStyle(fontSize: 8, color: brandColor),
      //                 ),
      //                 pw.SizedBox(height: 20),
      //               ],
      //             ),
      //           ],
      //         ),
      //       ],
      //     );
      //   }
      //   return pw.SizedBox();
      // },
      build: (context) {
        List<String> soinsList = soinsText
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .toList();
        return soinsList.asMap().entries.map((entry) {
          int index = entry.key;
          String soin = entry.value;

          // Clean up any leading dash you might have added during selection
          final cleanSoin = soin.trim().startsWith('- ')
              ? soin.trim().substring(2)
              : soin.trim();

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${index + 1}. ',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: brandColor,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    cleanSoin,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    ),
  );

  return pdf.save();
}
