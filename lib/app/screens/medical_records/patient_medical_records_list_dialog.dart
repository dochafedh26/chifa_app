import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/printing/ordonnance.dart';
import 'package:chifa/app/printing/preview.dart';
import 'package:chifa/app/printing/soins_medicaux.dart';
import 'package:chifa/app/screens/medical_records/medical_record_form_dialog_for_patient.dart';
import 'package:chifa/services/db/models/medical_record.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/print_template.dart';
import 'package:chifa/services/db/repositories/medical_record_repository.dart';
import 'package:chifa/services/db/repositories/payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:chifa/app/widgets/rich_text_viewer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class PatientMedicalRecordsListDialog extends StatefulWidget {
  final Patient patient;

  const PatientMedicalRecordsListDialog({super.key, required this.patient});

  @override
  State<PatientMedicalRecordsListDialog> createState() =>
      _PatientMedicalRecordsListDialogState();
}

class _PatientMedicalRecordsListDialogState
    extends State<PatientMedicalRecordsListDialog> {
  /// Map of recordId -> payment amount
  Map<int, double> _paymentsByRecord = {};
  double _totalPatientPayments = 0.0;
  bool _paymentsLoaded = false;
  PrintTemplate _selectedTemplate = PrintTemplate.chifa;

  @override
  void initState() {
    super.initState();
    context.read<MedicalRecordCubit>().loadMedicalRecordsByPatientId(
      widget.patient.patientId!,
    );
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final repo = PaymentRepository();
      final result = await repo.getByPatientId(widget.patient.patientId!);
      result.fold(
        (failure) {
          // silently ignore payment loading errors
        },
        (payments) {
          final map = <int, double>{};
          double total = 0.0;
          for (final p in payments) {
            if (p.recordId != null) {
              map[p.recordId!] = (map[p.recordId!] ?? 0.0) + p.amount;
            }
            total += p.amount;
          }
          if (mounted) {
            setState(() {
              _paymentsByRecord = map;
              _totalPatientPayments = total;
              _paymentsLoaded = true;
            });
          }
        },
      );
    } catch (_) {
      // silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        padding: EdgeInsets.all(
          MediaQuery.of(context).size.width < 600 ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  MediaQuery.of(context).size.width < 600
                      ? _formatPatientNameForSmallScreen(
                          widget.patient.fullName,
                        )
                      : 'Records: ${widget.patient.fullName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                SegmentedButton<PrintTemplate>(
                  segments: const [
                    ButtonSegment<PrintTemplate>(
                      value: PrintTemplate.chifa,
                      label: Text('CHIFA'),
                      icon: Icon(Icons.description_outlined, size: 14),
                    ),
                    ButtonSegment<PrintTemplate>(
                      value: PrintTemplate.eph,
                      label: Text('EPH'),
                      icon: Icon(Icons.local_hospital_outlined, size: 14),
                    ),
                  ],
                  selected: {_selectedTemplate},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedTemplate = newSelection.first;
                    });
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    selectedBackgroundColor: Colors.blue.shade700,
                    selectedForegroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: BlocConsumer<MedicalRecordCubit, MedicalRecordState>(
                listener: (context, state) {
                  if (state.successMessage != null) {
                    context
                        .read<MedicalRecordCubit>()
                        .loadMedicalRecordsByPatientId(
                          widget.patient.patientId!,
                        );
                    _loadPayments(); // refresh payments too
                  }
                },
                builder: (context, state) {
                  if (state.isLoading && state.medicalRecords.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state.medicalRecords.isNotEmpty ||
                      !state.isLoading) {
                    if (state.medicalRecords.isEmpty) {
                      return const Center(
                        child: Text(
                          'No medical records found for this patient.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: state.medicalRecords.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final record = state.medicalRecords[index];
                        final recordPayment = record.id != null
                            ? _paymentsByRecord[record.id!]
                            : null;
                        return _buildRecordCard(record, recordPayment);
                      },
                    );
                  } else if (state.error != null) {
                    return Center(
                      child: Text(
                        'Error: ${state.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            // Total payment summary
            if (_paymentsLoaded && _totalPatientPayments > 0) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Payments',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_totalPatientPayments.toStringAsFixed(2)} DA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(MedicalRecord record, double? paymentAmount) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.motif != null && record.motif!.isNotEmpty
                        ? record.motif!
                        : 'No Motif Provided',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(record.recordDate),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.visibility,
                        size: 20,
                        color: Colors.purple,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Record Details - ${DateFormat('MMM dd, yyyy').format(record.recordDate)}',
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Motif: ${record.motif ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Diagnostic:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(record.diagnostic ?? 'N/A'),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Details:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  RichTextViewer(text: record.details),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Prescriptions:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  _buildPrescriptionDisplay(record.prescriptions, const TextStyle(fontSize: 13)),
                                  if (record.soins != null &&
                                      record.soins!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Soins Médicaux:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record.soins!),
                                  ],
                                  const Divider(),
                                  const Text(
                                    'Vitals:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Weight: ${record.weight != null ? '${record.weight} kg' : 'N/A'}',
                                  ),
                                  Text(
                                    'Temperature: ${record.temperature != null ? '${record.temperature} °C' : 'N/A'}',
                                  ),
                                  Text(
                                    'Blood Pressure: ${record.tensionArterielle ?? 'N/A'}',
                                  ),
                                  Text(
                                    'Heart Rate: ${record.frequenceCardiaque ?? 'N/A'} bpm',
                                  ),
                                  Text('SpO2: ${record.spao2 ?? 'N/A'} %'),
                                  const SizedBox(height: 8),
                                  Text('Timer: ${record.recordTimer}'),
                                  if (paymentAmount != null) ...[
                                    const Divider(),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.payments,
                                          size: 16,
                                          color: Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Payment: ${paymentAmount.toStringAsFixed(2)} DA',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.print_rounded,
                        size: 20,
                        color: Colors.green,
                      ),
                      tooltip: 'Imprimer Ordonnance',
                      onPressed: () async {
                        if (record.prescriptions == null ||
                            record.prescriptions!.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No prescription to preview for this record.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        bool includeDate = true;
                        await showDialog(
                          context: context,
                          builder: (ctx) => StatefulBuilder(
                            builder: (ctx, setDialogState) => AlertDialog(
                              title: const Text('Options d\'impression'),
                              content: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: includeDate,
                                    onChanged: (v) =>
                                        setDialogState(() => includeDate = v!),
                                  ),
                                  const Text('Afficher la date'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Aperçu'),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (!context.mounted) return;
                        showPdfPreview(
                          context: context,
                          generatedPdfBytes: generateOrdonnancePdf(
                            patient: widget.patient,
                            weight: record.weight?.toString(),
                            prescriptionText: record.prescriptions!,
                            template: _selectedTemplate,
                            includeDate: includeDate,
                            date: record.recordDate,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.medical_information,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Imprimer Soins Médicaux',
                      onPressed: () {
                        if (record.soins == null ||
                            record.soins!.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Aucun soin à imprimer pour ce dossier.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        showPdfPreview(
                          context: context,
                          generatedPdfBytes: generateSoinsMedicauxPdf(
                            patient: widget.patient,
                            weight: record.weight?.toString(),
                            soinsText: record.soins!,
                            template: _selectedTemplate,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        final tabId = 'edit_record_${record.id}';
                        context.read<WorkspaceCubit>().openTab(
                          WorkspaceTab(
                            id: tabId,
                            title: 'Edit: ${widget.patient.fullName}',
                            content: BlocProvider(
                              create: (context) => MedicalRecordCubit(
                                context.read<MedicalRecordRepository>(),
                              ),
                              child: MedicalRecordFormDialogForPatient(
                                patient: widget.patient,
                                recordToEdit: record,
                                tabId: tabId,
                              ),
                            ),
                          ),
                        );
                        Navigator.pop(context); // Close the history list dialog
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Record'),
                            content: const Text(
                              'Are you sure you want to delete this record?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context
                                      .read<MedicalRecordCubit>()
                                      .deleteMedicalRecord(record.id!);
                                },
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (record.diagnostic != null && record.diagnostic!.isNotEmpty) ...[
              Text(
                'Diagnostic:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade800,
                  fontSize: 13,
                ),
              ),
              Text(record.diagnostic!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
            ],
            if (record.prescriptions != null &&
                record.prescriptions!.isNotEmpty) ...[
              Text(
                'Prescriptions:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                  fontSize: 13,
                ),
              ),
              _buildPrescriptionDisplay(record.prescriptions, const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
            ],
            if (record.soins != null && record.soins!.isNotEmpty) ...[
              Text(
                'Soins Médicaux:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade800,
                  fontSize: 13,
                ),
              ),
              Text(record.soins!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
            ],
            Text(
              'Details:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            RichTextViewer(text: record.details, style: const TextStyle(fontSize: 14)),
            // Payment amount for this record
            if (paymentAmount != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.payments,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${paymentAmount.toStringAsFixed(2)} DA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionLine(String lineText, TextStyle baseStyle) {
    final dciStart = lineText.indexOf('[');
    final dciEnd = lineText.indexOf(']');
    String brandPart = lineText;
    String dciPart = '';
    String posologyPart = '';
    String durationPart = '';

    String capitalizeDci(String text) {
      if (text.isEmpty) return '';
      final cleaned = text.trim().toLowerCase();
      if (cleaned.isEmpty) return '';
      return cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    if (dciStart != -1 && dciEnd > dciStart) {
      brandPart = lineText.substring(0, dciStart).trim();
      dciPart = lineText.substring(dciStart + 1, dciEnd).trim();
      
      String remaining = lineText.substring(dciEnd + 1).trim();
      while (remaining.startsWith('•') || remaining.startsWith(',') || remaining.startsWith('.')) {
        remaining = remaining.substring(1).trim();
      }
      
      if (remaining.contains(' • ')) {
        final parts = remaining.split(' • ');
        posologyPart = parts.isNotEmpty ? parts[0].trim() : '';
        if (parts.length > 1) {
          durationPart = parts[1].trim();
        }
      } else if (remaining.contains('........')) {
        final parts = remaining.split('........');
        posologyPart = parts.isNotEmpty ? parts[0].trim() : '';
        if (parts.length > 1) {
          durationPart = parts[1].trim();
        }
      } else {
        posologyPart = remaining;
      }
    } else {
      if (lineText.contains(' • ')) {
        final parts = lineText.split(' • ');
        brandPart = parts[0].trim();
        posologyPart = parts.length > 1 ? parts[1].trim() : '';
        durationPart = parts.length > 2 ? parts[2].trim() : '';
      } else if (lineText.contains('........')) {
        final parts = lineText.split('........');
        final left = parts[0].trim();
        durationPart = parts.length > 1 ? parts[1].trim() : '';
        final commaIdx = left.indexOf(',');
        if (commaIdx != -1) {
          brandPart = left.substring(0, commaIdx).trim();
          posologyPart = left.substring(commaIdx + 1).trim();
        } else {
          brandPart = left;
        }
      }
    }

    final fontSize = baseStyle.fontSize ?? 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(brandPart, style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
        if (dciPart.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            capitalizeDci(dciPart),
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.normal,
              fontStyle: FontStyle.italic,
              fontSize: fontSize - 1,
            ),
          ),
        ],
        if (posologyPart.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            durationPart.isNotEmpty ? '$posologyPart ($durationPart)' : posologyPart,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: fontSize - 0.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrescriptionDisplay(String? prescriptionsText, TextStyle baseStyle) {
    if (prescriptionsText == null || prescriptionsText.trim().isEmpty) {
      return Text('N/A', style: baseStyle);
    }
    final lines = prescriptionsText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return Text('N/A', style: baseStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: _buildPrescriptionLine(line.trim(), baseStyle),
      )).toList(),
    );
  }

  String _formatPatientNameForSmallScreen(String fullName) {
    final parts = fullName.split(' ');
    if (parts.length > 1) {
      return 'Records:\n  ${parts[0]}\n ';
    }
    return 'Records:\n  $fullName\n ';
  }
}
