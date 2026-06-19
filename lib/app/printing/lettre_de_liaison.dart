import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:io";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;


/// Generates the Lettre de Liaison (Medical Liaison Letter) PDF using the
/// ordonnance.jpg background template, with text overlaid to match the
/// printed "Lettre de Liaison" layout.
Future<Uint8List> generateLettreDeLiaisonPdf({
  required Patient patient,
  required String atcd,
  required String motifConsultation,
  required String examenClinique,
  required String motifLettre,
  required DateTime dateCreation,
  String? weight,
  PrintTemplate template = PrintTemplate.chifa,
  String? backPageTitle,
}) async {
  final pdf = pw.Document();
  final dateFormat = DateFormat('dd/MM/yyyy');
  final dateStr = dateFormat.format(dateCreation);

  // ───── Load background image ─────
  final Uint8List imageBytes;
  try {
    final assetPath = template.assetPath;
    final possiblePaths = [
      assetPath,
      Directory.current.path.endsWith('build')
          ? assetPath
          : '${Directory.current.path}/$assetPath',
    ];

    File? imageFile;
    for (final path in possiblePaths) {
      final f = File(path);
      if (await f.exists()) {
        imageFile = f;
        break;
      }
    }

    if (imageFile == null) {
      throw Exception('Ordonnance template image not found');
    }
    imageBytes = await imageFile.readAsBytes();
  } catch (e) {
    rethrow;
  }

  // ───── Load custom fonts ─────
  final Uint8List regularFontBytes;
  final Uint8List boldFontBytes;
  try {
    const regularFontPath =
        'assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Regular.ttf';
    const boldFontPath =
        'assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Bold.ttf';

    Future<File?> getFontFile(String path) async {
      final possiblePaths = [path, '${Directory.current.path}/$path'];
      for (final p in possiblePaths) {
        final f = File(p);
        if (await f.exists()) return f;
      }
      return null;
    }

    final regularFile = await getFontFile(regularFontPath);
    final boldFile = await getFontFile(boldFontPath);

    if (regularFile == null) throw Exception('Regular font file not found');
    if (boldFile == null) throw Exception('Bold font file not found');

    regularFontBytes = await regularFile.readAsBytes();
    boldFontBytes = await boldFile.readAsBytes();
  } catch (e) {
    rethrow;
  }

  final regularFont = pw.Font.ttf(regularFontBytes.buffer.asByteData());
  final boldFont = pw.Font.ttf(boldFontBytes.buffer.asByteData());
  final customFont = boldFont;
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  // ───── Text styles ─────
  final boldStyle = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
  const normalStyle = pw.TextStyle(fontSize: 11);
  const dottedLine =
      '......................................................................';

  // ───── Build PDF ─────
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 25),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        buildBackground: (context) {
          // Only show the ordonnance background on the first page
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
                            '${patient.age} ans',
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
                            '${patient.age} ans',
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
                    'Lettre de Liaison',
                    style: pw.TextStyle(
                      fontSize: 22,
                      font: customFont,
                      color: brandColor,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.SizedBox(
                    width: 160,
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
                  'Lettre de Liaison — ${patient.firstName} ${patient.lastName}',
                  style: pw.TextStyle(fontSize: 9, color: brandColor),
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                '${patient.age} ans  •  $dateStr',
                style: pw.TextStyle(fontSize: 9, color: brandColor),
              ),
            ],
          ),
        );
      },
      footer: (context) {
        if (context.pageNumber == 1) {
          return pw.SizedBox(height: 25);
        }
        return pw.Container(
          height: 25,
          alignment: pw.Alignment.bottomCenter,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        );
      },
      build: (context) => [
        pw.SizedBox(height: 14),

        // ───── Letter body ─────

        // "Cher Confrère, Consœur;"
        pw.Text('Cher Confrère, Consœur;', style: normalStyle),
        pw.SizedBox(height: 12),

        // "- Je me permet de vous adresser le (la) patient(e) susnommé(e)"
        pw.Text(
          '- Je me permet de vous adresser le (la) patient(e) susnommé(e)',
          style: normalStyle,
        ),
        pw.SizedBox(height: 12),

        // "- ATCD de: ......"
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: '- ATCD de: '),
              pw.TextSpan(
                text: atcd.isNotEmpty ? atcd : 'Aucun',
                style: atcd.isNotEmpty ? boldStyle : normalStyle,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // "- Consulte pour: ......"
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: '- Consulte pour: '),
              pw.TextSpan(
                text: motifConsultation.isNotEmpty
                    ? motifConsultation
                    : dottedLine,
                style: motifConsultation.isNotEmpty ? boldStyle : normalStyle,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // "- Examen Clinique:"
        pw.Text('- Examen Clinique:', style: normalStyle),
        pw.SizedBox(height: 4),
        if (examenClinique.isNotEmpty)
          ...examenClinique
              .split('\n')
              .expand(
                (line) => [
                  pw.Text(line, style: boldStyle),
                  pw.SizedBox(height: 2),
                ],
              )
        else
          ...List.generate(
            5,
            (_) => pw.Column(
              children: [
                pw.Text(dottedLine, style: normalStyle),
                pw.SizedBox(height: 2),
              ],
            ),
          ),
        pw.SizedBox(height: 12),

        // "Je vous l'adresse pour: ......"
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Je vous l\'adresse pour: '),
              pw.TextSpan(
                text: motifLettre.isNotEmpty ? motifLettre : dottedLine,
                style: motifLettre.isNotEmpty ? boldStyle : normalStyle,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 40),

        // "Confraternellement"
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 20),
            child: pw.Text(
              'Confraternellement',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 30),

        // // ───── Footer: Signature ─────
        // pw.Divider(color: brandColor, thickness: 0.5),
        // pw.SizedBox(height: 4),
        // pw.Row(
        //   mainAxisAlignment: pw.MainAxisAlignment.end,
        //   children: [
        //     pw.Column(
        //       crossAxisAlignment: pw.CrossAxisAlignment.center,
        //       children: [
        //         pw.Text(
        //           'Signature et cachet',
        //           style: pw.TextStyle(fontSize: 8, color: brandColor),
        //         ),
        //         pw.SizedBox(height: 20),
        //       ],
        //     ),
        //   ],
        // ),
      ],
    ),
  );

  if (backPageTitle != null && backPageTitle.isNotEmpty) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) {
          return pw.Container(
            color: PdfColors.white,
            child: pw.Text(
              backPageTitle,
              style: pw.TextStyle(
                fontSize: 20,
                font: boldFont,
                fontWeight: pw.FontWeight.bold,
                color: brandColor,
              ),
            ),
          );
        },
      ),
    );
  }

  return pdf.save();
}
