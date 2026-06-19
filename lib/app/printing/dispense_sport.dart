import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:io";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

Future<Uint8List> generateDispenseSportPdf({
  required Patient patient,
  required String motif,
  required DateTime dateCreation,
  String? weight,
  PrintTemplate template = PrintTemplate.chifa,
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
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  // ───── Text styles ─────
  final boldStyle = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
  const normalStyle = pw.TextStyle(fontSize: 11);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 40),
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
                    'CERTIFICAT DE DISPENSE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      font: boldFont,
                      color: brandColor,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'D\'ACTIVITÉS PHYSIQUES ET SPORTIVES',
                    style: pw.TextStyle(
                      fontSize: 15,
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
                  'Dispense Sport — ${patient.firstName} ${patient.lastName}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                '${patient.age} ans  •  $dateStr',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
            ],
          ),
        );
      },
      build: (context) => [
        pw.SizedBox(height: 24),

        // Main Content
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
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  font: boldFont,
                  // color: brandColor,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'L\'état de santé de : '),
              pw.TextSpan(text: patient.fullName, style: boldStyle),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Âgé(e) de : '),
              pw.TextSpan(text: '${patient.age} ans', style: boldStyle),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Nécessite une dispense d\'activités physiques et sportives.',
          style: boldStyle,
        ),
        pw.SizedBox(height: 16),
        if (motif.isNotEmpty) ...[
          pw.Text('Motif :', style: normalStyle),
          pw.SizedBox(height: 4),
          pw.Text(motif, style: boldStyle),
        ],

        pw.SizedBox(height: 20),
        pw.Text(
          'Ce certificat est délivré à la demande de l\'intéressé(e) pour servir et valoir ce que de droit.',
          style: normalStyle,
        ),
        pw.SizedBox(height: 30),

        // Footer Date
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 20),
            child: pw.Text('Fait le $dateStr', style: normalStyle),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}
