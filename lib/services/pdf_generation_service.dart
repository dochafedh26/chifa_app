import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chifa/tunnel/services/tunnel_service.dart';

import 'package:chifa/services/db/models/invoice.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/payment.dart';
import 'package:chifa/services/db/models/service.dart';
import 'package:chifa/services/formatters/formatters.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF Generation Service for Clinic Management System
/// Generates: Prescriptions, Work Certificates, Medical Letters, Invoices, Lab Orders
class PdfGenerationService {
  // Clinic information (should be loaded from settings)
  final String clinicName;
  final String clinicAddress;
  final String clinicPhone;
  final String clinicEmail;
  final String doctorName;
  final String doctorSpecialization;

  PdfGenerationService({
    this.clinicName = 'EPH - Medea',
    this.clinicAddress = 'Adresse de la clinique',
    this.clinicPhone = '01 23 45 67 89',
    this.clinicEmail = 'contact@clinique.com',
    this.doctorName = 'Dr. Nom Prénom',
    this.doctorSpecialization = 'Médecine Générale',
  });

  static pw.ThemeData? _cachedTheme;

  /// Returns a shared theme with Cairo font for Arabic and Latin/French Unicode support.
  static Future<pw.ThemeData> getPdfTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;
    try {
      final cairoRegular = await PdfGoogleFonts.cairoRegular();
      final cairoBold = await PdfGoogleFonts.cairoBold();
      _cachedTheme = pw.ThemeData.withFont(
        base: cairoRegular,
        bold: cairoBold,
        fontFallback: [cairoRegular, cairoBold],
      );
      return _cachedTheme!;
    } catch (e) {
      debugPrint('[PdfGenerationService] Failed to load Cairo font: $e');
      return pw.ThemeData();
    }
  }

  // ==================== PRESCRIPTION PDF ====================

  /// Generate prescription PDF
  Future<pw.Document> generatePrescription({
    required Patient patient,
    required String prescription,
    required DateTime date,
  }) async {
    final theme = await getPdfTheme();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Patient Info
              _buildPatientInfo(patient),
              pw.SizedBox(height: 20),

              // Prescription Title
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.teal700, width: 2),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(10),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'ORDONNANCE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal700,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Prescription Content
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Text(
                  prescription,
                  style: const pw.TextStyle(fontSize: 14, height: 1.8),
                ),
              ),
              pw.Spacer(),

              // Footer with date and signature
              _buildFooter(date: date),
            ],
          );
        },
      ),
    );

    return doc;
  }

  // ==================== WORK CERTIFICATE (ARRET DE TRAVAIL) ====================

  /// Generate work certificate PDF
  Future<pw.Document> generateArretDeTravail({
    required Patient patient,
    required String type,
    required String motif,
    required DateTime dateDebut,
    required DateTime dateReprise,
    required int jours,
    required DateTime dateCreation,
  }) async {
    final theme = await getPdfTheme();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Patient Info
              _buildPatientInfo(patient),
              pw.SizedBox(height: 30),

              // Certificate Title
              pw.Center(
                child: pw.Text(
                  'CERTIFICAT MÉDICAL',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  type.toUpperCase().replaceAll('_', ' '),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Certificate Content
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Je soussigné(e), $doctorName, certifie que:',
                      style: const pw.TextStyle(fontSize: 14, height: 1.5),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Nom: ${patient.fullName}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Né(e) le: ${DateFormat('dd/MM/yyyy').format(patient.dateOfBirth)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Présente un état médical nécessitant un arrêt de travail.',
                      style: const pw.TextStyle(fontSize: 14, height: 1.5),
                    ),
                    pw.SizedBox(height: 10),
                    if (motif.isNotEmpty) ...[
                      pw.Text(
                        'Motif: $motif',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.SizedBox(height: 10),
                    ],
                    pw.Text(
                      'Durée: $jours jour(s)',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Date de début: ${DateFormat('dd/MM/yyyy').format(dateDebut)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Date de reprise: ${DateFormat('dd/MM/yyyy').format(dateReprise)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // Footer
              _buildMedicalFooter(date: dateCreation),
            ],
          );
        },
      ),
    );

    return doc;
  }

  // ==================== MEDICAL LETTER (LETTRE) ====================

  /// Generate medical letter PDF
  Future<pw.Document> generateLettre({
    required Patient patient,
    required String motifLettre,
    required String atcd,
    required String motifConsultation,
    required String examenClinique,
    required DateTime date,
  }) async {
    final theme = await getPdfTheme();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Date
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Fait le ${DateFormat('dd/MM/yyyy').format(date)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 30),

              // Patient Info
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Patient: ${patient.fullName}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Né(e) le: ${DateFormat('dd/MM/yyyy').format(patient.dateOfBirth)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    if (patient.phone != null && patient.phone!.isNotEmpty)
                      pw.Text(
                        'Tél: ${patient.phone}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Letter Title
              pw.Center(
                child: pw.Text(
                  'LETTRE MÉDICALE',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Letter Content
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (motifLettre.isNotEmpty) ...[
                      pw.Text(
                        'Objet: $motifLettre',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 15),
                    ],
                    if (atcd.isNotEmpty) ...[
                      pw.Text(
                        'Antécédents:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        atcd,
                        style: const pw.TextStyle(fontSize: 12, height: 1.5),
                      ),
                      pw.SizedBox(height: 15),
                    ],
                    pw.Text(
                      'Motif de consultation:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      motifConsultation,
                      style: const pw.TextStyle(fontSize: 12, height: 1.5),
                    ),
                    pw.SizedBox(height: 15),
                    if (examenClinique.isNotEmpty) ...[
                      pw.Text(
                        'Examen clinique:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        examenClinique,
                        style: const pw.TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Spacer(),

              // Footer
              _buildMedicalFooter(date: date),
            ],
          );
        },
      ),
    );

    return doc;
  }

  // ==================== INVOICE PDF ====================

  /// Generate invoice PDF
  Future<pw.Document> generateInvoice({
    required Invoice invoice,
    required Patient patient,
    required List<Service> services,
  }) async {
    final theme = await getPdfTheme();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(compact: true),
              pw.SizedBox(height: 12),

              // Invoice Title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'FACTURE',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal700,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _getStatusColor(invoice.status),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Text(
                      invoice.status.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Invoice Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'N° Facture: #${invoice.invoiceId ?? "N/A"}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(invoice.issueDate)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Échéance: ${DateFormat('dd/MM/yyyy').format(invoice.dueDate)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Patient:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        patient.fullName,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Services Table
              _buildServicesTable(services, compact: true),
              pw.SizedBox(height: 8),

              // Total
              _buildInvoiceTotal(invoice, compact: true),
              pw.Spacer(),

              // Payment Info
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Mode de paiement: ${_formatPaymentMethod(invoice.paymentMethod)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Merci de régler la facture avant la date d\'échéance.',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  // ==================== LAB ORDER (BILAN) PDF ====================

  /// Generate lab order PDF
  Future<pw.Document> generateBilan({
    required Patient patient,
    required String bilans,
    required DateTime date,
  }) async {
    final theme = await getPdfTheme();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Patient Info
              _buildPatientInfo(patient),
              pw.SizedBox(height: 30),

              // Title
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue700, width: 2),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(10),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'ORDONNANCE DE LABORATOIRE',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Lab Tests
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Analyses prescrites:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      bilans,
                      style: const pw.TextStyle(fontSize: 13, height: 1.8),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // Footer
              _buildMedicalFooter(date: date),
            ],
          );
        },
      ),
    );

    return doc;
  }



  // ==================== BILLING LIST PDF ====================

  /// Generate billing list PDF
  Future<pw.Document> generateBillingList({
    required List<Payment> payments,
    required DateTime startDate,
    required DateTime endDate,
    String? doctorName,
  }) async {
    final theme = await getPdfTheme();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 40),
        ),
        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          );
        },
        build: (context) {
          return [
            pw.Column(
              children: [
                // Header
                _buildHeader(),
                pw.SizedBox(height: 20),

                // Title
                pw.Center(
                  child: pw.Text(
                    'LISTE DES PAIEMENTS',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),

                // Date Range
                pw.Center(
                  child: pw.Text(
                    'Période: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),

                // Doctor filter if specified
                if (doctorName != null && doctorName.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'Médecin: $doctorName',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                pw.SizedBox(height: 16),

                // Summary
                _buildBillingSummary(payments),
                pw.SizedBox(height: 16),
              ],
            ),
            // Payments Table
            _buildPaymentsTable(payments),
          ];
        },
      ),
    );

    return doc;
  }

  /// Build billing summary
  pw.Widget _buildBillingSummary(List<Payment> payments) {
    final totalAmount = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final totalPayments = payments.length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.teal, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text(
                'Nombre de paiements',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                totalPayments.toString(),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
            ],
          ),
          pw.Container(width: 1, height: 40, color: PdfColors.teal200),
          pw.Column(
            children: [
              pw.Text(
                'Montant total',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                '${totalAmount.toStringAsFixed(2)} DA',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build payments table
  pw.Widget _buildPaymentsTable(List<Payment> payments) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(1), // Date
        1: const pw.FlexColumnWidth(2), // Patient
        2: const pw.FlexColumnWidth(2), // Service
        3: const pw.FlexColumnWidth(1), // Amount
        4: const pw.FlexColumnWidth(1), // Method
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.teal50),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Date',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Patient',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Service',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Montant',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Paiement',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        // Data rows
        ...payments.map(
          (payment) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  DateFormat('dd/MM/yyyy').format(payment.paymentDate),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  '${payment.patientName ?? ""} ${payment.patientSurname ?? ""}'
                      .trim(),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  payment.servicesText ?? 'Consultation',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  '${payment.amount.toStringAsFixed(2)} DA',
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  payment.paymentMethod ?? 'Espèces',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HELPER METHODS ====================

  /// Build header with clinic info
  pw.Widget _buildHeader({bool compact = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(compact ? 12 : 20),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(compact ? 8 : 10)),
        border: pw.Border.all(color: PdfColors.teal, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                clinicName,
                style: pw.TextStyle(
                  fontSize: compact ? 14 : 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
              pw.SizedBox(height: compact ? 3 : 5),
              pw.Text(
                doctorName,
                style: pw.TextStyle(
                  fontSize: compact ? 11 : 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                doctorSpecialization,
                style: pw.TextStyle(fontSize: compact ? 9 : 12),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(clinicAddress, style: pw.TextStyle(fontSize: compact ? 8 : 11)),
              pw.Text(
                'Tél: $clinicPhone',
                style: pw.TextStyle(fontSize: compact ? 8 : 11),
              ),
              pw.Text(
                'Email: $clinicEmail',
                style: pw.TextStyle(fontSize: compact ? 8 : 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build patient info section
  pw.Widget _buildPatientInfo(Patient patient) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informations du Patient',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Nom: ${patient.fullName}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Né(e) le: ${DateFormat('dd/MM/yyyy').format(patient.dateOfBirth)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Âge: ${_formatAge(patient.dateOfBirth)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (patient.phone != null && patient.phone!.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Tél: ${patient.phone}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    if (patient.address != null && patient.address!.isNotEmpty)
                      pw.Text(
                        'Adresse: ${patient.address}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build footer with date and signature placeholder
  pw.Widget _buildFooter({required DateTime date}) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Fait le ${DateFormat('dd/MM/yyyy').format(date)}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 20,
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Signature et Cachet',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(doctorName, style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build medical footer
  pw.Widget _buildMedicalFooter({required DateTime date}) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              children: [
                pw.Text(
                  'Fait le ${DateFormat('dd/MM/yyyy').format(date)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 50),
                pw.Text(
                  doctorName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  doctorSpecialization,
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Signature et Cachet',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Build services table for invoice
  pw.Widget _buildServicesTable(List<Service> services, {bool compact = false}) {
    final paddingVal = compact ? 5.0 : 8.0;
    final fontSizeVal = compact ? 10.0 : 12.0;
    final dataFontSizeVal = compact ? 9.0 : 11.0;
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.teal50),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(paddingVal),
              child: pw.Text(
                'Service',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSizeVal),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(paddingVal),
              child: pw.Text(
                'Prix',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSizeVal),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        ...services.map(
          (service) => pw.TableRow(
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(paddingVal),
                child: pw.Text(service.serviceName, style: pw.TextStyle(fontSize: dataFontSizeVal)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(paddingVal),
                child: pw.Text(
                  '${service.price.toStringAsFixed(2)} DA',
                  style: pw.TextStyle(fontSize: dataFontSizeVal),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build invoice total section
  pw.Widget _buildInvoiceTotal(Invoice invoice, {bool compact = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(compact ? 10 : 15),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(compact ? 6 : 8)),
        border: pw.Border.all(color: PdfColors.teal, width: compact ? 1.5 : 2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'Total à payer: ',
            style: pw.TextStyle(fontSize: compact ? 12 : 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${invoice.totalAmount.toStringAsFixed(2)} DA',
            style: pw.TextStyle(
              fontSize: compact ? 14 : 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal900,
            ),
          ),
        ],
      ),
    );
  }

  /// Get status color for invoice
  PdfColor _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return PdfColors.green;
      case InvoiceStatus.unpaid:
        return PdfColors.red;
      case InvoiceStatus.pending:
        return PdfColors.orange;
    }
  }

  /// Format payment method
  String _formatPaymentMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.creditCard:
        return 'Carte Bancaire';
      case PaymentMethod.insurance:
        return 'Assurance';
    }
  }

  /// Format age from birth date, returning "N/A" for sentinel fallback years
  String _formatAge(DateTime birthDate) {
    return Formatters.formatAge(birthDate);
  }

  // ==================== PRINT AND SAVE METHODS ====================

  /// Print document directly over TCP Tunnel (or fallback to local Printing)
  Future<void> printDocument(
    pw.Document document, {
    String name = 'Document.pdf',
    BuildContext? context,
    String? pageSize,
    String? orientation,
    Future<Uint8List> Function(String pageSize, String orientation)? onGeneratePdf,
  }) async {
    final pdfBytes = await document.save();
    await printPdfBytes(
      pdfBytes,
      name: name,
      context: context,
      pageSize: pageSize,
      orientation: orientation,
      onGeneratePdf: onGeneratePdf,
    );
  }

  /// Print raw PDF bytes (remote target printer check, or fallback to local Printing)
  Future<void> printPdfBytes(
    Uint8List pdfBytes, {
    String name = 'Document.pdf',
    BuildContext? context,
    String? pageSize,
    String? orientation,
    Future<Uint8List> Function(String pageSize, String orientation)? onGeneratePdf,
  }) async {
    Uint8List finalPdfBytes = pdfBytes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tunnelService = TunnelService.instance;
      final selectedPrinter = prefs.getString('selected_remote_printer') ?? '';

      if (tunnelService != null && tunnelService.isConnected && tunnelService.peerConnected && selectedPrinter.isNotEmpty) {
        String targetPageSize = pageSize ?? prefs.getString('remote_print_paper_size') ?? 'A4';
        String targetOrientation = orientation ?? prefs.getString('remote_print_orientation') ?? 'portrait';

        if (context != null && context.mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => StatefulBuilder(
              builder: (ctx, setOptionState) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF0F1629),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF1A2340)),
                  ),
                  title: Row(
                    children: [
                      const Icon(Icons.print_rounded, color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Impression - $selectedPrinter',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Document: $name', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        const Text('Format du papier:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F38),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF263359)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: targetPageSize,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF161F38),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: ['A4', 'A5', 'Letter', 'Legal'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) {
                                if (val != null) setOptionState(() => targetPageSize = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Orientation:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Portrait', style: TextStyle(color: Colors.white, fontSize: 12))),
                                selected: targetOrientation == 'portrait',
                                selectedColor: Colors.blueAccent,
                                backgroundColor: const Color(0xFF161F38),
                                onSelected: (_) => setOptionState(() => targetOrientation = 'portrait'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Paysage', style: TextStyle(color: Colors.white, fontSize: 12))),
                                selected: targetOrientation == 'landscape',
                                selectedColor: Colors.blueAccent,
                                backgroundColor: const Color(0xFF161F38),
                                onSelected: (_) => setOptionState(() => targetOrientation = 'landscape'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                      label: const Text('Imprimer', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            ),
          );

          if (confirm != true) return;

          await prefs.setString('remote_print_paper_size', targetPageSize);
          await prefs.setString('remote_print_orientation', targetOrientation);
        }

        if (onGeneratePdf != null) {
          try {
            finalPdfBytes = await onGeneratePdf(targetPageSize, targetOrientation);
          } catch (e) {
            debugPrint('[PdfGenerationService] Error re-generating PDF for format $targetPageSize: $e');
          }
        }

        final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
        final tempFilename = 'print_${DateTime.now().millisecondsSinceEpoch}_$safeName.pdf';

        if (context != null && context.mounted) {
          double currentProgress = 0.0;
          String statusMessage = 'Transfert du fichier PDF en cours...';
          bool isUploading = true;
          bool isDone = false;
          String? errorMsg;
          bool printSuccess = false;

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (ctx, setDialogState) {
                  void startPrintingProcess() async {
                    try {
                      await tunnelService.uploadBytes(
                        finalPdfBytes,
                        tempFilename,
                        onProgress: (p) {
                          try {
                            setDialogState(() {
                              currentProgress = p * 0.4;
                              statusMessage = 'Transfert du fichier PDF (${(p * 100).toInt()}%)...';
                            });
                          } catch (_) {}
                        },
                      );

                      try {
                        setDialogState(() {
                          isUploading = false;
                          currentProgress = 0.4;
                          statusMessage = 'Impression en cours sur $selectedPrinter...';
                        });
                      } catch (_) {}

                      await tunnelService.triggerRemotePrint(
                        tempFilename,
                        selectedPrinter,
                        deleteAfter: true,
                        pageSize: targetPageSize,
                        orientation: targetOrientation,
                        onProgress: (pct, page, total, desc) {
                          try {
                            setDialogState(() {
                              currentProgress = 0.4 + (pct * 0.6);
                              if (desc.isNotEmpty) {
                                statusMessage = desc;
                              } else {
                                statusMessage = 'Impression en cours (${(pct * 100).toInt()}%)...';
                              }
                            });
                          } catch (_) {}
                        },
                      );

                      try {
                        setDialogState(() {
                          currentProgress = 1.0;
                          isDone = true;
                          statusMessage = "Document envoyé avec succès à l'imprimante !";
                        });
                      } catch (_) {}

                      printSuccess = true;
                    } catch (e) {
                      try {
                        setDialogState(() {
                          isDone = true;
                          errorMsg = e.toString().replaceAll('Exception: ', '');
                        });
                      } catch (_) {}
                    }
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (statusMessage == 'Transfert du fichier PDF en cours...') {
                      startPrintingProcess();
                    }
                  });

                  if (errorMsg != null) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF0F1629),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.redAccent.shade700),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text("Échec de l'impression", style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                      content: Text(
                        "Impossible d'imprimer sur \"$selectedPrinter\".\n\n$errorMsg\n\nLe document va basculer en mode local.",
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('OK', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    );
                  }

                  if (isDone) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF0F1629),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.greenAccent.shade700),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent),
                          SizedBox(width: 10),
                          Text('Impression terminée', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                      content: Text(
                        "Le document \"$name\" a été envoyé avec succès à l'imprimante \"$selectedPrinter\".",
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Fermer', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    );
                  }

                  return AlertDialog(
                    backgroundColor: const Color(0xFF0F1629),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFF1A2340)),
                    ),
                    title: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.blueAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isUploading ? 'Envoi du document...' : 'Impression sur $selectedPrinter...',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: currentProgress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF161F38),
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          statusMessage,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );

          if (printSuccess) return;
        } else {
          await tunnelService.uploadBytes(finalPdfBytes, tempFilename);
          await tunnelService.triggerRemotePrint(
            tempFilename,
            selectedPrinter,
            deleteAfter: true,
            pageSize: targetPageSize,
            orientation: targetOrientation,
          );
          return;
        }
      }
    } catch (_) {}

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => finalPdfBytes,
      name: name,
    );
  }

  /// Save document to file
  Future<File> saveDocument(pw.Document document, String path) async {
    final file = File(path);
    await file.writeAsBytes(await document.save());
    return file;
  }

  /// Share document
  Future<void> shareDocument(pw.Document document, String name) async {
    await Printing.sharePdf(bytes: await document.save(), filename: name);
  }
}
