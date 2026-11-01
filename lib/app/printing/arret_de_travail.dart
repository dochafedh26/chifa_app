import "package:chifa/services/db/models/models.dart";
import "package:intl/intl.dart";
import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:chifa/app/printing/pdf_asset_helper.dart";


/// Generates the Arret de Travail (Work Certificate) PDF using the
/// ordonnance.jpg background template, with text overlaid to match the
/// printed "Certificat Médical" layout.
Future<Uint8List> generateArretDeTravailPdf({
  required Patient patient,
  required String arretType,
  required String motif,
  required DateTime dateDebut,
  required DateTime dateReprise,
  required int jours,
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
  final customFont = boldFont;
  final brandColor = PdfColor.fromHex('#1A7CC5');

  final pdfImage = pw.MemoryImage(imageBytes);

  // ───── Bold & normal text styles ─────
  final boldStyle = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
  const normalStyle = pw.TextStyle(fontSize: 11);

  // ───── Build certificate body content based on type ─────
  List<pw.Widget> buildCertificateBody() {
    final dateDebutStr = dateFormat.format(dateDebut);
    final finalDateStr = dateFormat.format(dateDebut.add(Duration(days: jours - 1)));
    final dateRepriseStr = dateFormat.format(dateReprise);
    

    final widgets = <pw.Widget>[];

    // "Je soussigné ....., certifie que l'état de santé"
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(text: 'Je soussigné '),
            if (template == PrintTemplate.chifa) ...[
              pw.TextSpan(text: 'Dr HERHOUR MOHAMED', style: boldStyle),
            ] else ...[
              pw.TextSpan(text: 'Dr CHIKH TOUAMI.H', style: boldStyle),
            ],
            const pw.TextSpan(text: ', certifie que l\'état de santé'),
          ],
        ),
      ),
    );

    // "de M/Mlle/Mme: ......"
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(text: 'de M/Mlle/Mme: '),
            pw.TextSpan(
              text: '${patient.lastName} ${patient.firstName}',
              style: boldStyle,
            ),
          ],
        ),
      ),
    );

    // "né(e) le: ......"
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(text: 'né(e) le: '),
            pw.TextSpan(
              text: dateFormat.format(patient.dateOfBirth),
              style: boldStyle,
            ),
          ],
        ),
      ),
    );

    widgets.add(pw.SizedBox(height: 16));
    widgets.add(pw.Text('Nécessite:', style: normalStyle));
    widgets.add(pw.SizedBox(height: 10));

    // ───── Section 1: Arrêt de travail ─────
    final isArret = arretType == 'ARRET DE TRAVAIL';
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(
              text: '1°) Un traitement avec arrêt du travail de ',
            ),
            pw.TextSpan(
              text: isArret ? '$jours' : '........',
              style: boldStyle,
            ),
            const pw.TextSpan(text: ' jours sauf'),
          ],
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(text: 'complications à compter du: '),
            pw.TextSpan(
              text: isArret ? dateDebutStr : '..............................',
              style: boldStyle,
            ),
            const pw.TextSpan(text: ' jusqu\'au: '),
            pw.TextSpan(
              text: isArret ? finalDateStr : '..............................',
              style: boldStyle,
            ),
          ],
        ),
      ),
    );

    widgets.add(pw.SizedBox(height: 14));

    // ───── Section 2: Prolongation d'arrêt ─────
    final isProlongation = arretType == "PROLONGATION D'ARRET";
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(
              text: '2°) Une Prolongation d\'arrêt de travail de ',
            ),
            pw.TextSpan(
              text: isProlongation ? '$jours' : '........',
              style: boldStyle,
            ),
            const pw.TextSpan(text: ' jours sauf'),
          ],
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(text: 'complications du: '),
            pw.TextSpan(
              text: isProlongation
                  ? dateDebutStr
                  : '......................................................',
              style: boldStyle,
            ),
            const pw.TextSpan(text: ' jusqu\'au: '),
            pw.TextSpan(
              text: isProlongation
                  ? dateRepriseStr
                  : '......................................................',
              style: boldStyle,
            ),
          ],
        ),
      ),
    );

    widgets.add(pw.SizedBox(height: 12));

    // "* doit garder la chambre"
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 20),
        child: pw.Text('* doit garder la chambre', style: normalStyle),
      ),
    );
    widgets.add(pw.SizedBox(height: 4));
    // "* autorisé à sortir de ...h à ...h"
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 20),
        child: pw.Text(
          '* autorisé à sortir de ..............h à ..............h',
          style: normalStyle,
        ),
      ),
    );

    widgets.add(pw.SizedBox(height: 14));

    // ───── Section 3: Reprise de travail ─────
    final isReprise = arretType == 'REPRISE DE TRAVAIL';
    final showRepriseDate = isReprise || isArret || isProlongation;
    widgets.add(
      pw.RichText(
        text: pw.TextSpan(
          style: normalStyle,
          children: [
            const pw.TextSpan(
              text: '3°) lui permet de reprendre son travail le: ',
            ),
            pw.TextSpan(
              text: showRepriseDate
                  ? dateRepriseStr
                  : '..............................',
              style: boldStyle,
            ),
          ],
        ),
      ),
    );

    // // ───── Motif (if provided) ─────
    // if (motif.isNotEmpty) {
    //   widgets.add(pw.SizedBox(height: 14));
    //   widgets.add(
    //     pw.RichText(
    //       text: pw.TextSpan(
    //         style: normalStyle,
    //         children: [
    //           const pw.TextSpan(text: 'Motif: '),
    //           pw.TextSpan(text: motif, style: boldStyle),
    //         ],
    //       ),
    //     ),
    //   );
    // }

    widgets.add(pw.SizedBox(height: 14));

    // Disclaimer
    widgets.add(
      pw.Text(
        'Ce présent Certificat est établi en un seul exemplaire sans rature ni surcharge',
        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
      ),
    );

    return widgets;
  }

  // ───── Build PDF ─────
  pdf.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(16, 90, 16, 40),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        buildBackground: (context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
          );
        },
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ───── Header: Patient info fields ─────
            // Same positions as ordonnance.dart
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
                  'Certificat Médical',
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
            pw.SizedBox(height: 12),

            // ───── Certificate body ─────
            ...buildCertificateBody(),

            pw.Spacer(),

            // ───── Footer: Signature ─────
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
        );
      },
    ),
  );

  return pdf.save();
}
