import "package:chifa/services/db/models/models.dart";
import "dart:io";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;


/// Generates an empty ordonnance PDF — background only, no patient data, no prescription
Future<Uint8List> generateEmptyOrdonnancePdf({
  PrintTemplate template = PrintTemplate.chifa,
}) async {
  final pdf = pw.Document();

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

  final pdfImage = pw.MemoryImage(imageBytes);

  pdf.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.zero,
        buildBackground: (context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
          );
        },
      ),
      build: (context) => pw.SizedBox(),
    ),
  );

  return pdf.save();
}

/// Generates the ordonnance PDF and returns the bytes
Future<Uint8List> generateOrdonnancePdf({
  required Patient patient,
  String? weight,
  required String prescriptionText,
  PrintTemplate template = PrintTemplate.chifa,
  bool includeDate = true,
  DateTime? date,
}) async {
  final pdf = pw.Document();
  final printDate = date ?? DateTime.now();
  final dateStr =
      '${printDate.day.toString().padLeft(2, '0')}/${printDate.month.toString().padLeft(2, '0')}/${printDate.year}';

  // Load the template background image
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

  // Load custom font
  final Uint8List fontBytes;
  try {
    const fontPath =
        'assets/fonts/Bricolage-Grotesque/BricolageGrotesque-Bold.ttf';
    final possibleFontPaths = [fontPath, '${Directory.current.path}/$fontPath'];
    File? fontFile;
    for (final path in possibleFontPaths) {
      final f = File(path);
      if (await f.exists()) {
        fontFile = f;
        break;
      }
    }
    if (fontFile == null) throw Exception('Font file not found');
    fontBytes = await fontFile.readAsBytes();
  } catch (e) {
    rethrow;
  }
  final customFont = pw.Font.ttf(fontBytes.buffer.asByteData());
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
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${patient.firstName} ${patient.lastName}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: brandColor,
                    ),
                  ),
                  pw.Row(
                    children: [
                      pw.Text(
                        'Age: ${patient.age} ans',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: brandColor,
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
                                color: brandColor,
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
              pw.Divider(color: brandColor, thickness: 1),
              pw.SizedBox(height: 10),
            ],
          );
        }
      },
      build: (context) {
        final List<String> prescriptionList = prescriptionText.split('\n');
        return prescriptionList.asMap().entries.map((entry) {
          int index = entry.key;
          String prescription = entry.value;

          if (prescription.trim().isNotEmpty) {
            try {
              String medicName = '';
              String dci = '';
              String posology = '';
              String duration = '';

              final dciStart = prescription.indexOf('[');
              final dciEnd = prescription.indexOf(']');

              if (dciStart != -1 && dciEnd > dciStart) {
                medicName = prescription.substring(0, dciStart).trim();
                final rawDci = prescription.substring(dciStart + 1, dciEnd).trim();
                if (rawDci.isNotEmpty) {
                  final cleaned = rawDci.toLowerCase();
                  dci = cleaned[0].toUpperCase() + cleaned.substring(1);
                }
              } else {
                medicName = prescription.split(',').first.trim();
              }

              final parts = prescription.split(',');
              if (parts.length > 1) {
                final details = parts[1].split('........');
                if (details.isNotEmpty) {
                  posology = details[0].trim();
                }
                if (details.length > 1) {
                  duration = details[1].trim();
                }
              }

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
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
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            medicName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (dci.isNotEmpty)
                            pw.Text(
                              dci,
                              style: pw.TextStyle(
                                color: PdfColors.grey,
                                fontSize: 9,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          if (posology.isNotEmpty)
                            pw.Text(
                              posology,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12),
                      child: pw.Text(
                        textAlign: pw.TextAlign.left,
                        duration,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } catch (e) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '${index + 1}. $prescription',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
                ),
              );
            }
          }
          return pw.SizedBox();
        }).toList();
      },
    ),
  );

  return pdf.save();
}