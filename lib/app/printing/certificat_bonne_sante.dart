import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:io";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

Future<Uint8List> generateBonneSantePdf({
  required Patient patient,
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
  final customFont = boldFont;
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  // ───── Text styles ─────
  final boldStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  const normalStyle = pw.TextStyle(fontSize: 10);

  final pageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.fromLTRB(16, 14.173228346456693, 16, 30),
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    buildBackground: (context) {
      return pw.FullPage(
        ignoreMargins: true,
        child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
      );
    },
  );

  pw.Widget buildHeader(String titleLine1, String titleLine2) {
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
              titleLine1,
              style: pw.TextStyle(
                fontSize: 14,
                font: customFont,
                color: brandColor,
              ),
            ),
          ),
          pw.Center(
            child: pw.Text(
              titleLine2,
              style: pw.TextStyle(
                fontSize: 14,
                font: customFont,
                color: brandColor,
              ),
            ),
          ),
          pw.Center(
            child: pw.SizedBox(
              width: 180,
              child: pw.Divider(color: brandColor, thickness: 1),
            ),
          ),
        ],
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ───── Page 1: Médecine Générale ─────
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      header: (context) => buildHeader('CERTIFICAT MEDICAL DE', 'MEDECINE GENERALE'),
      build: (context) => [
        pw.SizedBox(height: 15),
        pw.Text('Je soussigné(e), Docteur, certifie que :', style: normalStyle),
        pw.SizedBox(height: 12),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Le/La patient(e): '),
              pw.TextSpan(text: patient.fullName, style: boldStyle),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Âgé(e) de: '),
              pw.TextSpan(text: '${patient.age} ans', style: boldStyle),
            ],
          ),
        ),
        if (patient.address != null && patient.address!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.RichText(
            text: pw.TextSpan(
              style: normalStyle,
              children: [
                const pw.TextSpan(text: 'Demeurant à: '),
                pw.TextSpan(text: patient.address!, style: boldStyle),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 12),
        pw.Text(
          'Je déclare que l\'intéressé n\'est atteint d\'aucune maladie ou infirmité incompatible avec son état de santé. L\'examen pratiqué, orienté notamment vers la recherche de troubles mentaux, d\'affections malignes, ainsi que de troubles paralytiques, ne révèle aucune pathologie apparente.',
          style: normalStyle,
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Ce certificat est délivré à la demande de l\'intéressé(e) pour servir et valoir ce que de droit.',
          style: normalStyle,
        ),
        pw.SizedBox(height: 35),
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

  // ───── Page 2: Pneumo-Phtisiologie ─────
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      header: (context) => buildHeader('CERTIFICAT MEDICAL DE', 'PNEUMO-PHTISIOLOGIE'),
      build: (context) => [
        pw.SizedBox(height: 15),
        pw.Text('Je soussigné(e), Docteur, certifie que :', style: normalStyle),
        pw.SizedBox(height: 12),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Le/La patient(e): '),
              pw.TextSpan(text: patient.fullName, style: boldStyle),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.RichText(
          text: pw.TextSpan(
            style: normalStyle,
            children: [
              const pw.TextSpan(text: 'Âgé(e) de: '),
              pw.TextSpan(text: '${patient.age} ans', style: boldStyle),
            ],
          ),
        ),
        if (patient.address != null && patient.address!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.RichText(
            text: pw.TextSpan(
              style: normalStyle,
              children: [
                const pw.TextSpan(text: 'Demeurant à: '),
                pw.TextSpan(text: patient.address!, style: boldStyle),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 12),
        pw.Text(
          'Je déclare qu\'il (elle) est indemne ou complètement guéri(e) de la tuberculose ou de toute autre affection respiratoire.',
          style: normalStyle,
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Ce certificat est délivré à la demande de l\'intéressé(e) pour servir et valoir ce que de droit.',
          style: normalStyle,
        ),
        pw.SizedBox(height: 35),
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
