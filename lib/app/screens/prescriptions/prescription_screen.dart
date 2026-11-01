import 'package:chifa/services/pdf_generation_service.dart';
import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/cubits/prescription_cubit.dart';
import 'package:chifa/app/printing/ordonnance.dart';
import 'package:chifa/app/screens/prescriptions/prescription_print_dialog.dart';
import 'package:chifa/services/db/models/medical_record.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/prescription.dart';
import 'package:chifa/services/db/models/prescription_type.dart';
import 'package:chifa/services/db/repositories/medical_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:printing/printing.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _prescriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _patientSearchController = TextEditingController();

  Patient? _selectedPatient;
  MedicalRecord? _selectedRecord;
  bool _isSearchingPatient = false;
  bool _showPatientSuggestions = false;

  int? _doctorId;
  bool _isLoading = false;
  DateTime _prescriptionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    _doctorId = authCubit.currentUser?.employeeId;
    context.read<PrescriptionCubit>().loadCommonPrescriptions();
    context.read<PrescriptionCubit>().loadPrescriptionTypes();
  }

  @override
  void dispose() {
    _prescriptionController.dispose();
    _searchController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<PrescriptionCubit>().searchPrescriptions(query);
  }

  void _insertTemplate(Prescription template) {
    _prescriptionController.text = template.prescription;
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _showPatientSuggestions = false;
      });
      return;
    }
    setState(() => _isSearchingPatient = true);
    await context.read<PatientCubit>().searchPatients(query);
    if (mounted) {
      setState(() {
        _isSearchingPatient = false;
        _showPatientSuggestions = true;
      });
    }
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _patientSearchController.text = patient.fullName;
      _showPatientSuggestions = false;
      _selectedRecord = null;
      _prescriptionController.clear();
    });
    context.read<MedicalRecordCubit>().loadMedicalRecordsByPatientId(
      patient.patientId!,
    );
  }

  void _selectRecord(MedicalRecord record) {
    setState(() {
      _selectedRecord = record;
      _prescriptionController.text = record.prescriptions ?? '';
      _prescriptionDate = record.recordDate;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedRecord = null;
      _prescriptionController.clear();
      _prescriptionDate = DateTime.now();
    });
  }

  void _showPrintDialog() {
    if (_selectedPatient == null || _prescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient and enter prescription'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PrescriptionPrintDialog(
        patientId: _selectedPatient!.patientId!,
        prescription: _prescriptionController.text,
        date: _prescriptionDate,
      ),
    );
  }

  Future<void> _printBlankOrdonnance() async {
    final pdfBytes = await generateEmptyOrdonnancePdf();
    if (!mounted) return;
    await PdfGenerationService().printPdfBytes(pdfBytes, name: 'Ordonnance.pdf', context: context);
  }

  Future<void> _savePrescription() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_prescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the prescription'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    int? medicalRecordId = _selectedRecord?.id;

    if (medicalRecordId == null) {
      final repo = MedicalRecordRepository();
      final newRecord = MedicalRecord(
        patientId: _selectedPatient!.patientId!,
        doctorId: _doctorId!,
        motif: "demande d'ordonnance",
        details: "demande d'ordonnance",
        recordTimer: '00:00:00',
        recordDate: _prescriptionDate,
      );
      final result = await repo.create(newRecord);
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to create medical record: ${failure.message}',
                ),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
          }
        },
        (id) {
          medicalRecordId = id;
        },
      );
    }

    if (medicalRecordId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final record = MedicalRecord(
      id: medicalRecordId,
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId!,
      motif: _selectedRecord?.motif ?? "demande d'ordonnance",
      details: _selectedRecord?.details ?? "demande d'ordonnance",
      prescriptions: _prescriptionController.text,
      recordTimer: _selectedRecord?.recordTimer ?? '00:00:00',
      recordDate: _prescriptionDate,
    );

    if (_selectedRecord != null) {
      context.read<MedicalRecordCubit>().updateMedicalRecord(
        _selectedRecord!.id!,
        record,
      );
    } else {
      context.read<MedicalRecordCubit>().updateMedicalRecord(
        medicalRecordId!,
        record,
      );
    }
  }

  void _resetForm() {
    setState(() {
      _selectedPatient = null;
      _patientSearchController.clear();
      _prescriptionController.clear();
      _prescriptionDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return MultiBlocListener(
      listeners: [
        BlocListener<MedicalRecordCubit, MedicalRecordState>(
          listener: (context, state) {
            setState(() => _isLoading = false);
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: Colors.green,
                ),
              );
              _prescriptionController.clear();
              if (_selectedPatient != null) {
                context
                    .read<MedicalRecordCubit>()
                    .loadMedicalRecordsByPatientId(
                      _selectedPatient!.patientId!,
                    );
              }
            }
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _patientSearchController,
                      decoration: InputDecoration(
                        labelText: 'Search Patient *',
                        hintText: 'Enter patient name or ID...',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_search),
                        suffixIcon: _isSearchingPatient
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _selectedPatient != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _resetForm,
                              )
                            : null,
                      ),
                      onChanged: _searchPatients,
                    ),
                    if (_showPatientSuggestions)
                      BlocBuilder<PatientCubit, PatientState>(
                        builder: (context, patientState) {
                          final results = patientState.patients;
                          if (results.isEmpty) return const SizedBox.shrink();
                          return Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: results.length,
                                separatorBuilder: (_, index) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) {
                                  final p = results[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.person, size: 20),
                                    title: Text(
                                      p.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ID: ${p.patientId} • ${p.formattedAge}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onTap: () => _selectPatient(p),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    if (_selectedPatient != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedPatient!.fullName}  •  ${_selectedPatient!.formattedAge}  •  ${_selectedPatient!.gender.name}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Medical Records History
            if (_selectedPatient != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical Records History',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      BlocBuilder<MedicalRecordCubit, MedicalRecordState>(
                        builder: (context, state) {
                          if (state.isLoading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final records = state.medicalRecords
                              .where(
                                (r) =>
                                    r.prescriptions != null &&
                                    r.prescriptions!.isNotEmpty,
                              )
                              .toList();

                          if (records.isEmpty) {
                            return const Center(
                              child: Text(
                                'No prescription history for this patient',
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: records.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final record = records[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _selectedRecord?.id == record.id
                                      ? Colors.indigo
                                      : Colors.indigo.shade50,
                                  child: Icon(
                                    Icons.medication,
                                    color: _selectedRecord?.id == record.id
                                        ? Colors.white
                                        : Colors.indigo.shade700,
                                  ),
                                ),
                                title: _buildPrescriptionDisplay(
                                   record.prescriptions,
                                   const TextStyle(fontSize: 13),
                                 ),
                                subtitle: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(record.recordDate),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                selected: _selectedRecord?.id == record.id,
                                selectedTileColor: Colors.indigo.shade50,
                                onTap: () => _selectRecord(record),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Prescription Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedRecord != null
                              ? 'Edit Prescription'
                              : 'New Prescription',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_selectedRecord != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Editing',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _clearSelection,
                            child: const Text('Cancel Edit'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<PrescriptionCubit, PrescriptionState>(
                      builder: (context, state) {
                        List<PrescriptionType> types = [];
                        if (state is PrescriptionTypesLoaded) {
                          types = state.types;
                        }

                        return DropdownButtonFormField<PrescriptionType>(
                          decoration: const InputDecoration(
                            labelText: 'Prescription Templates',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.list_alt),
                            isDense: true,
                          ),
                          items: types.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t.title),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                if (_prescriptionController.text.isNotEmpty) {
                                  _prescriptionController.text +=
                                      '\n${val.prescription}';
                                } else {
                                  _prescriptionController.text =
                                      val.prescription;
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _prescriptionDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _prescriptionDate = pickedDate;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Prescription Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(_prescriptionDate),
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                        if (DateFormat('dd/MM/yyyy').format(_prescriptionDate) !=
                            DateFormat('dd/MM/yyyy').format(DateTime.now()))
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: IconButton(
                              icon: const Icon(Icons.restore, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _prescriptionDate = DateTime.now();
                                });
                              },
                              tooltip: 'Reset to current date',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _prescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Prescription *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medication),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                      minLines: 5,
                    ),
                    const SizedBox(height: 16),
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _savePrescription,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                  _selectedRecord != null
                                      ? 'Update Prescription'
                                      : 'Save Prescription',
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _printBlankOrdonnance,
                                icon: const Icon(Icons.note_alt_outlined),
                                label: const Text('Blank Ordonnance'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _showPrintDialog,
                                icon: const Icon(Icons.print),
                                label: const Text('Print PDF'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _printBlankOrdonnance,
                                icon: const Icon(Icons.note_alt_outlined),
                                label: const Text('Blank Ordonnance'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _showPrintDialog,
                                icon: const Icon(Icons.print),
                                label: const Text('Print PDF'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _savePrescription,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                  _selectedRecord != null ? 'Update' : 'Save',
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Templates Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Common Prescriptions (Templates)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search templates...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<PrescriptionCubit, PrescriptionState>(
                      builder: (context, state) {
                        if (state is PrescriptionLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (state is PrescriptionsLoaded) {
                          if (state.prescriptions.isEmpty) {
                            return const Center(
                              child: Text('No templates found'),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.prescriptions.length,
                            itemBuilder: (context, index) {
                              final template = state.prescriptions[index];
                              return ListTile(
                                leading: const Icon(Icons.article),
                                title: Text(
                                  template.prescription.length > 60
                                      ? '${template.prescription.substring(0, 60)}...'
                                      : template.prescription,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _insertTemplate(template),
                                  tooltip: 'Use this template',
                                ),
                              );
                            },
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
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
    // Limit displaying list to up to 3 items in the history tile to keep it compact (similar to substring limit)
    final allLines = prescriptionsText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (allLines.isEmpty) {
      return Text('N/A', style: baseStyle);
    }
    final lines = allLines.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines.map((line) => Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: _buildPrescriptionLine(line.trim(), baseStyle),
        )),
        if (allLines.length > 3)
          Text(
            '... (+${allLines.length - 3} médicaments)',
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}
