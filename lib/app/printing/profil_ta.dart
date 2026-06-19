import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:io";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

Future<Uint8List> generateProfilTAPdf({
  required Patient patient,
  required DateTime dateCreation,
  PrintTemplate template = PrintTemplate.chifa,
}) async {
  final pdf = pw.Document();
  final dateFormat = DateFormat('dd/MM/yyyy');
  final dateStr = dateFormat.format(dateCreation);

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

  final brandColor = PdfColor.fromHex('#E04141'); // Crimson Red for Cardio/BP
  final lightBgColor = PdfColor.fromHex('#FFF5F5');

  final boldStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont);
  final headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont, color: PdfColors.white);
  final normalStyle = pw.TextStyle(fontSize: 10, font: regularFont);
  final smallStyle = pw.TextStyle(fontSize: 8, font: regularFont, color: PdfColors.grey700);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      template == PrintTemplate.eph ? 'E.P.H. DE MÉDÉA' : 'CLINIQUE CHIFA',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: brandColor, font: boldFont),
                    ),
                    pw.Text(
                      template == PrintTemplate.eph ? 'Wilaya de Médéa' : 'Route d\'Alger, Médéa',
                      style: smallStyle,
                    ),
                    pw.Text(
                      template == PrintTemplate.eph ? 'Service de Médecine' : 'Tél : 025 78 54 12',
                      style: smallStyle,
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('FICHE DE SUIVI DE LA TENSION ARTÉRIELLE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: brandColor, font: boldFont)),
                    pw.Text('Date d\'émission : $dateStr', style: smallStyle),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: brandColor, thickness: 1.5),
            pw.SizedBox(height: 15),

            // Patient Info Block
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightBgColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: brandColor, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      style: normalStyle,
                      children: [
                        const pw.TextSpan(text: 'Nom & Prénom : '),
                        pw.TextSpan(text: patient.fullName, style: boldStyle),
                      ],
                    ),
                  ),
                  pw.RichText(
                    text: pw.TextSpan(
                      style: normalStyle,
                      children: [
                        const pw.TextSpan(text: 'Âge : '),
                        pw.TextSpan(text: '${patient.age} ans', style: boldStyle),
                      ],
                    ),
                  ),
                  pw.RichText(
                    text: pw.TextSpan(
                      style: normalStyle,
                      children: [
                        const pw.TextSpan(text: 'Sexe : '),
                        pw.TextSpan(
                          text: patient.gender == Gender.male
                              ? 'Masculin'
                              : (patient.gender == Gender.female
                                  ? 'Féminin'
                                  : 'Autre'),
                          style: boldStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            pw.Text(
              'Consignes de suivi : Veuillez mesurer votre tension artérielle (ex: 12/8 mmHg) et votre pouls (battements/min) le matin (avant le petit-déjeuner) et le soir (avant le coucher), après 5 minutes de repos. Notez les valeurs ci-dessous.',
              style: pw.TextStyle(fontSize: 9, font: regularFont, fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 15),

            // Grid Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // Date
                1: const pw.FlexColumnWidth(1.0), // TA Matin
                2: const pw.FlexColumnWidth(1.0), // Pouls Matin
                3: const pw.FlexColumnWidth(1.0), // TA Soir
                4: const pw.FlexColumnWidth(1.0), // Pouls Soir
                5: const pw.FlexColumnWidth(2.0), // Observations
              },
              children: [
                // Table Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: brandColor),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Date', style: headerStyle))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Tension Matin\n(mmHg)', style: headerStyle, textAlign: pw.TextAlign.center))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Pouls Matin\n(bpm)', style: headerStyle, textAlign: pw.TextAlign.center))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Tension Soir\n(mmHg)', style: headerStyle, textAlign: pw.TextAlign.center))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Pouls Soir\n(bpm)', style: headerStyle, textAlign: pw.TextAlign.center))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Observations / Activités', style: headerStyle))),
                  ],
                ),
                // 14 Blank Rows for 2 weeks of tracking
                for (int i = 0; i < 14; i++)
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 12), child: pw.Center(child: pw.Text('', style: normalStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 12), child: pw.Center(child: pw.Text('', style: normalStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 12), child: pw.Center(child: pw.Text('', style: normalStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 12), child: pw.Center(child: pw.Text('', style: normalStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 12), child: pw.Center(child: pw.Text('', style: normalStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 12), child: pw.Center(child: pw.Text('', style: normalStyle))),
                    ],
                  ),
              ],
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  template == PrintTemplate.eph
                      ? 'Fiche de suivi de la Tension Artérielle - E.P.H. de Médéa'
                      : 'Fiche de suivi de la Tension Artérielle - Clinique Chifa',
                  style: smallStyle,
                ),
                pw.Text('Signature / Cachet du Médecin', style: smallStyle),
              ],
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
