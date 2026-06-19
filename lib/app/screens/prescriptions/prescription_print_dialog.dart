import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/printing/preview.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/pdf_generation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

/// Prescription Print Dialog - Preview and print prescription PDF
class PrescriptionPrintDialog extends StatefulWidget {
  final int patientId;
  final String prescription;
  final DateTime? date;

  const PrescriptionPrintDialog({
    super.key,
    required this.patientId,
    required this.prescription,
    this.date,
  });

  @override
  State<PrescriptionPrintDialog> createState() =>
      _PrescriptionPrintDialogState();
}

class _PrescriptionPrintDialogState extends State<PrescriptionPrintDialog> {
  bool _isLoading = true;
  Patient? _patient;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    setState(() => _isLoading = true);

    try {
      await context.read<PatientCubit>().loadPatientById(widget.patientId);
      if (!context.mounted) return;
      final state = context.read<PatientCubit>().state;

      if (state.selectedPatient != null) {
        setState(() {
          _patient = state.selectedPatient;
          _isLoading = false;
        });
      } else if (state.error != null) {
        setState(() {
          _error = state.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load patient: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _previewPdf() async {
    if (_patient == null) return;

    final pdfService = PdfGenerationService(
      clinicName: 'Clinic Médicale',
      clinicAddress: 'Adresse de la clinique',
      clinicPhone: '01 23 45 67 89',
      clinicEmail: 'contact@clinique.com',
      doctorName: 'Dr. Nom Prénom',
      doctorSpecialization: 'Médecine Générale',
    );

    final generatedPdf = pdfService.generatePrescription(
      patient: _patient!,
      prescription: widget.prescription,
      date: widget.date ?? DateTime.now(),
    );

    if (mounted) {
      await showPdfPreview(
        context: context,
        generatedPdfBytes: generatedPdf.then((doc) => doc.save()),
        title: 'Prescription Preview',
      );
    }
  }

  Future<void> _printPdf() async {
    if (_patient == null) return;

    final pdfService = PdfGenerationService(
      clinicName: 'Clinic Médicale',
      clinicAddress: 'Adresse de la clinique',
      clinicPhone: '01 23 45 67 89',
      clinicEmail: 'contact@clinique.com',
      doctorName: 'Dr. Nom Prénom',
      doctorSpecialization: 'Médecine Générale',
    );

    final doc = await pdfService.generatePrescription(
      patient: _patient!,
      prescription: widget.prescription,
      date: widget.date ?? DateTime.now(),
    );

    // Generate PDF and print it
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print Prescription'),
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
            : _patient == null
            ? const Center(child: Text('Patient not found'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient: ${_patient!.fullName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Age: ${_patient!.age} ans'),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Prescription:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.prescription),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
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
