import 'dart:io';
import 'dart:typed_data';

import 'package:chifa/services/db/models/invoice.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/payment.dart';
import 'package:chifa/services/db/models/print_template.dart';
import 'package:chifa/services/db/models/service.dart';
import 'package:chifa/services/db/models/treatment.dart';
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

  // ==================== PRESCRIPTION PDF ====================

  /// Generate prescription PDF
  Future<pw.Document> generatePrescription({
    required Patient patient,
    required String prescription,
    required DateTime date,
  }) async {
    final doc = pw.Document();

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
    final doc = pw.Document();

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
    final doc = pw.Document();

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
    final doc = pw.Document();

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
    final doc = pw.Document();

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
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
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
    if (birthDate.year == 1990 || birthDate.year == 1800) {
      return 'N/A';
    }
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return '$age ans';
  }

  // ==================== PRINT AND SAVE METHODS ====================

  /// Print document directly
  Future<void> printDocument(pw.Document document) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => document.save(),
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
