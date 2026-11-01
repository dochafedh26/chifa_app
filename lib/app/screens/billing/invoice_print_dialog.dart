import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/printing/preview.dart';

import 'package:chifa/services/db/models/invoice.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/payment.dart';
import 'package:chifa/services/db/models/service.dart';
import 'package:chifa/services/db/repositories/payment_repository.dart';
import 'package:chifa/services/pdf_generation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Invoice Print Dialog - Preview and print invoice PDF
class InvoicePrintDialog extends StatefulWidget {
  final Payment payment;

  const InvoicePrintDialog({super.key, required this.payment});

  @override
  State<InvoicePrintDialog> createState() => _InvoicePrintDialogState();
}

class _InvoicePrintDialogState extends State<InvoicePrintDialog> {
  bool _isLoading = true;
  Patient? _patient;
  List<Service> _services = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final patientId = widget.payment.patientId;
      if (patientId == null) {
        if (mounted) {
          setState(() {
            _error = 'Missing patient ID for this payment.';
            _isLoading = false;
          });
        }
        return;
      }

      await context.read<PatientCubit>().loadPatientById(patientId);
      if (!mounted) return;
      final patientState = context.read<PatientCubit>().state;

      Patient? patient;
      if (patientState.selectedPatient != null) {
        patient = patientState.selectedPatient;
      }

      // Load actual services if available, fallback to payment servicesText
      final services = <Service>[];
      if (widget.payment.paymentId != null) {
        final repo = PaymentRepository();
        final result = await repo.getServicesByPaymentId(widget.payment.paymentId!);
        result.fold((_) {}, (loadedServices) {
          for (final s in loadedServices) {
            services.add(
              Service(
                serviceId: s.serviceId,
                serviceName: s.serviceName,
                price: s.servicePrice,
                doctorCommission: s.doctorCommission,
              ),
            );
          }
        });
      }

      if (services.isEmpty && widget.payment.amount > 0) {
        final text = widget.payment.servicesText;
        final serviceName = (text != null && text.trim().isNotEmpty) ? text : 'Consultation';
        services.add(
          Service(
            serviceName: serviceName,
            price: widget.payment.amount,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _patient = patient;
          _services = services;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _printPdf() async {
    final patientId = widget.payment.patientId;
    if (_patient == null || patientId == null) return;

    final pdfService = PdfGenerationService(
      clinicName: 'Clinique Chifa',
      clinicAddress: 'Route d\'Alger, En face Dr Chaabane Sari - MEDEA',
      clinicPhone: '07 91 14 07 73 - 025 78 00 47',
      clinicEmail: 'contact@chifa-clinique.com',
      doctorName: 'Dr HERHOUR MOHAMED',
      doctorSpecialization: 'Médecine Générale',
    );

    final doc = await pdfService.generateInvoice(
      invoice: Invoice(
        patientId: patientId,
        totalAmount: widget.payment.amount,
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == widget.payment.paymentMethod,
          orElse: () => PaymentMethod.cash,
        ),
        issueDate: widget.payment.paymentDate,
        dueDate: widget.payment.paymentDate,
        status: InvoiceStatus.paid,
      ),
      patient: _patient!,
      services: _services,
    );

    final pdfBytes = await doc.save();
    await PdfGenerationService().printPdfBytes(pdfBytes, name: 'Facture.pdf', context: context, pageSize: 'A5');
  }

  Future<void> _previewPdf() async {
    final patientId = widget.payment.patientId;
    if (_patient == null || patientId == null) return;

    final pdfService = PdfGenerationService(
      clinicName: 'Clinique Chifa',
      clinicAddress: 'Route d\'Alger, En face Dr Chaabane Sari - MEDEA',
      clinicPhone: '07 91 14 07 73 - 025 78 00 47',
      clinicEmail: 'contact@chifa-clinique.com',
      doctorName: 'Dr HERHOUR MOHAMED',
      doctorSpecialization: 'Médecine Générale',
    );

    final generatedPdf = pdfService.generateInvoice(
      invoice: Invoice(
        patientId: patientId,
        totalAmount: widget.payment.amount,
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == widget.payment.paymentMethod,
          orElse: () => PaymentMethod.cash,
        ),
        issueDate: widget.payment.paymentDate,
        dueDate: widget.payment.paymentDate,
        status: InvoiceStatus.paid,
      ),
      patient: _patient!,
      services: _services,
    );

    if (mounted) {
      await showPdfPreview(
        context: context,
        generatedPdfBytes: generatedPdf.then((doc) => doc.save()),
        title: 'Invoice Preview',
        pageFormat: PdfPageFormat.a5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invoice Details'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(_error!),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment #${widget.payment.paymentId ?? "N/A"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PAID',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Patient Info
                    if (_patient != null) ...[
                      Text(
                        'Patient:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('  Name: ${_patient!.fullName}'),
                      Text('  Age: ${_patient!.formattedAge}'),
                      if (_patient!.phone != null &&
                          _patient!.phone!.isNotEmpty)
                        Text('  Phone: ${_patient!.phone}'),
                      const SizedBox(height: 16),
                    ],

                    // Payment Details
                    Text(
                      'Payment Details:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Date',
                      value: DateFormat(
                        'dd/MM/yyyy',
                      ).format(widget.payment.paymentDate),
                    ),
                    _DetailRow(
                      label: 'Payment Method',
                      value: widget.payment.paymentMethod ?? 'Cash',
                    ),
                    if (widget.payment.notes != null &&
                        widget.payment.notes!.isNotEmpty)
                      _DetailRow(label: 'Notes', value: widget.payment.notes!),
                    const SizedBox(height: 16),

                    // Services
                    if (_services.isNotEmpty) ...[
                      Text(
                        'Services:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _services
                              .map(
                                (service) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(service.serviceName),
                                      Text(
                                        '${service.price.toStringAsFixed(2)} DA',
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Total
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${widget.payment.amount.toStringAsFixed(2)} DA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton.icon(
          onPressed: (_isLoading || _patient == null) ? null : _previewPdf,
          icon: const Icon(Icons.visibility),
          label: const Text('Preview'),
        ),
        ElevatedButton.icon(
          onPressed: (_isLoading || _patient == null) ? null : _printPdf,
          icon: const Icon(Icons.print),
          label: const Text('Print PDF'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
