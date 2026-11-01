import 'package:chifa/services/pdf_generation_service.dart';
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:pdf/pdf.dart";
import "package:printing/printing.dart";

Future<void> showPdfPreview({
  required BuildContext context,
  required Future<Uint8List> generatedPdfBytes,
  String title = 'PDF Preview',
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) async {
  try {
    final pdfBytes = await generatedPdfBytes;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          child: Column(
            children: [
              AppBar(
                title: Text(title),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.print),
                    tooltip: 'Print',
                    onPressed: () {
                      PdfGenerationService().printPdfBytes(
                        pdfBytes,
                        name: 'document.pdf',
                        context: dialogContext,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share',
                    onPressed: () {
                      Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: 'document.pdf',
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) => pdfBytes,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  pageFormats: <String, PdfPageFormat>{'Custom': pageFormat},
                  pdfPreviewPageDecoration: BoxDecoration(
                    color: Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    // Handle error silently
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading PDF: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

