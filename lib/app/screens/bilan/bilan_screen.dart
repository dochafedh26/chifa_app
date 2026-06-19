import 'dart:typed_data';

import 'package:chifa/app/printing/bilan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:dartz/dartz.dart' hide Column, State, Function;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:printing/printing.dart';

import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/bilan_cubit.dart';
import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/printing/preview.dart';
import 'package:chifa/services/db/models/models.dart';
import 'package:chifa/services/db/repositories/bilan_repository.dart';
import 'package:chifa/services/db/repositories/medical_record_repository.dart';
import 'package:chifa/services/db/repositories/patient_repository.dart';
import 'package:chifa/app/theme/app_theme.dart';

import '../../../services/db/repositories/base_repository.dart';

/// Lab Orders (Bilan) Screen
class BilanScreen extends StatefulWidget {
  const BilanScreen({super.key});

  @override
  State<BilanScreen> createState() => _BilanScreenState();
}

class _BilanScreenState extends State<BilanScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<BilanCubit>().loadBilans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<BilanCubit>().searchBilans(query);
  }

  void _showBilanDialog([Bilan? bilan]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BilanFormDialog(bilan: bilan),
    );
  }

  void _deleteBilan(Bilan bilan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lab Order'),
        content: Text(
          'Are you sure you want to delete lab order #${bilan.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<BilanCubit>().deleteBilan(bilan.id!);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPrintDialog(Bilan bilan) {
    showDialog(
      context: context,
      builder: (context) => _BilanPrintDialog(bilan: bilan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return BlocListener<BilanCubit, BilanState>(
      listener: (context, state) {
        if (state is BilanOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is BilanError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: isMobile
                    ? Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search lab orders...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.read<BilanCubit>().loadBilans(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh List'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search lab orders...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showBilanDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('New Lab Order'),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
                              context.read<BilanCubit>().loadBilans();
                            },
                            icon: const Icon(
                              Icons.refresh,
                              size: 32,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Lab Orders List
              BlocBuilder<BilanCubit, BilanState>(
                builder: (context, state) {
                  if (state is BilanLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is BilanError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text('Error: ${state.message}'),
                        ],
                      ),
                    );
                  }

                  if (state is BilansLoaded) {
                    if (state.bilans.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.biotech,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No lab orders found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.bilans.length,
                      itemBuilder: (context, index) {
                        final bilan = state.bilans[index];
                        return _BilanCard(
                          bilan: bilan,
                          onPrint: () => _showPrintDialog(bilan),
                          onEdit: () => _showBilanDialog(bilan),
                          onDelete: () => _deleteBilan(bilan),
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
    );
  }
}

class _BilanCard extends StatelessWidget {
  final Bilan bilan;
  final VoidCallback onPrint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BilanCard({
    required this.bilan,
    required this.onPrint,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.biotech, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bilan.patientName ?? 'Patient ID: ${bilan.patientId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Lab Order #${bilan.id}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMobile)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'print') onPrint();
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'print',
                        child: ListTile(
                          leading: Icon(Icons.print, color: Colors.blue),
                          title: Text('Print'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, color: Colors.orange),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.blue),
                        onPressed: onPrint,
                        tooltip: 'Print',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: onEdit,
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: onDelete,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (bilan.doctorName != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.medical_services,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Dr. ${bilan.doctorName}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              bilan.bilans,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(bilan.createdAt),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BilanFormDialog extends StatefulWidget {
  final Bilan? bilan;

  const _BilanFormDialog({this.bilan});

  @override
  State<_BilanFormDialog> createState() => _BilanFormDialogState();
}

class _BilanFormDialogState extends State<_BilanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _testsController;
  late TextEditingController _patientSearchController;
  late TextEditingController _weightController;

  int? _selectedPatientId;
  int? _selectedMedicalRecordId;
  bool _isSaving = false;
  bool _isSearchingPatients = false;
  bool _isLoadingRecords = false;
  List<MedicalRecord> _patientRecords = [];
  PrintTemplate _selectedTemplate = PrintTemplate.chifa;

  @override
  void initState() {
    super.initState();
    _testsController = TextEditingController(text: widget.bilan?.bilans);
    _patientSearchController = TextEditingController(
      text: widget.bilan?.patientName,
    );
    _weightController = TextEditingController();
    _selectedPatientId = widget.bilan?.patientId;
    _selectedMedicalRecordId = widget.bilan?.medicalrecordId;
    if (widget.bilan != null && widget.bilan!.medicalrecordId != null) {
      _loadPatientRecords(widget.bilan!.patientId);
    }
  }

  @override
  void dispose() {
    _testsController.dispose();
    _patientSearchController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) return;

    setState(() => _isSearchingPatients = true);
    await context.read<PatientCubit>().searchPatients(query);
    if (!mounted) return;
    setState(() => _isSearchingPatients = false);
  }

  Future<void> _loadPatientRecords(int? patientId) async {
    if (patientId == null) return;
    setState(() => _isLoadingRecords = true);
    await context.read<MedicalRecordCubit>().loadMedicalRecordsByPatientId(
      patientId,
    );
    if (!mounted) return;
    final state = context.read<MedicalRecordCubit>().state;
    setState(() {
      _patientRecords = state.medicalRecords;
      _isLoadingRecords = false;
    });
  }

  Future<void> _previewPdf() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient first')),
      );
      return;
    }

    await context.read<PatientCubit>().loadPatientById(_selectedPatientId!);
    if (!mounted) return;
    final state = context.read<PatientCubit>().state;
    if (state.selectedPatient != null) {
      final patient = state.selectedPatient!;

      final pdfFuture = generateBilanPdf(
        patient: patient,
        bilanText: _testsController.text,
        dateCreation: DateTime.now(),
        weight: _weightController.text.trim().isNotEmpty
            ? _weightController.text.trim()
            : null,
        template: _selectedTemplate,
      );

      if (!mounted) return;
      showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
    }
  }

  Widget _buildMedicalRecordSelector() {
    if (_selectedPatientId == null) return const SizedBox.shrink();

    if (_isLoadingRecords) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading medical records...', style: TextStyle(fontSize: 13)),
        ],
      );
    }

    if (_selectedMedicalRecordId != null) {
      final selected = _patientRecords.cast<MedicalRecord?>().firstWhere(
        (r) => r?.id == _selectedMedicalRecordId,
        orElse: () => null,
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected != null
                    ? 'Linked to record #${selected.id} (${DateFormat('dd/MM/yyyy').format(selected.recordDate)})'
                    : 'Linked to record #$_selectedMedicalRecordId',
                style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _selectedMedicalRecordId = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    if (_patientRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No record selected — a new medical record will be created automatically with motif "demande de labo".',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Medical Record (optional)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            hintText: 'Select a medical record...',
            prefixIcon: const Icon(Icons.folder_open, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
          initialValue: _selectedMedicalRecordId,
          items: _patientRecords.map((r) {
            final label =
                '#${r.id} — ${DateFormat('dd/MM/yyyy HH:mm').format(r.recordDate)}${r.motif != null ? ' (${r.motif})' : ''}';
            return DropdownMenuItem(
              value: r.id,
              child: Text(label, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedMedicalRecordId = val),
        ),
        const SizedBox(height: 4),
        Text(
          'Leave empty to auto-create a new record',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Future<int?> _ensureMedicalRecord() async {
    final authState = context.read<AuthCubit>().state;
    final doctorId =
        (authState is AuthAuthenticated &&
            authState.employee.employeeId != null)
        ? authState.employee.employeeId!
        : 41;

    if (_selectedMedicalRecordId != null) {
      return _selectedMedicalRecordId;
    }

    final repo = MedicalRecordRepository();
    final now = DateTime.now();
    final record = MedicalRecord(
      patientId: _selectedPatientId!,
      doctorId: doctorId,
      motif: 'demande de labo',
      details: 'demande de labo',
      recordTimer: '00:00:00',
      recordDate: now,
    );

    final result = await repo.create(record);
    return result.fold((_) => null, (id) => id);
  }

  void _save(bool printAfter) async {
    if (!_formKey.currentState!.validate() || _selectedPatientId == null) {
      if (_selectedPatientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a patient')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final medicalrecordId = await _ensureMedicalRecord();
    if (medicalrecordId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create medical record'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    final authState = context.read<AuthCubit>().state;
    final doctorId = (authState is AuthAuthenticated)
        ? authState.employee.employeeId
        : 41;

    final bilan = Bilan(
      id: widget.bilan?.id,
      patientId: _selectedPatientId!,
      doctorId: doctorId,
      bilans: _testsController.text,
      medicalrecordId: medicalrecordId,
      createdAt: widget.bilan?.createdAt,
    );

    if (widget.bilan == null) {
      await context.read<BilanCubit>().createBilan(bilan);
    } else {
      await context.read<BilanCubit>().updateBilan(widget.bilan!.id!, bilan);
    }

    if (printAfter) {
      await _previewPdf();
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bilan != null;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Lab Order' : 'New Lab Order'),
      contentPadding: isMobile
          ? const EdgeInsets.fromLTRB(16, 16, 16, 0)
          : const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: SizedBox(
        width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Patient Search
                _PatientTypeAheadField(
                  suggestionsCallback: _searchPatients,
                  controller: _patientSearchController,
                  builder: (context, controller, focusNode) => TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (value) => _searchPatients(value),
                    decoration: InputDecoration(
                      labelText: 'Search Patient *',
                      prefixIcon: const Icon(Icons.person_search),
                      suffixIcon: _isSearchingPatients
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                  itemBuilder: (context, patient) => ListTile(
                    title: Text(patient.fullName),
                    subtitle: Text(
                      'ID: ${patient.patientId} | Born: ${DateFormat('dd/MM/yyyy').format(patient.dateOfBirth)}',
                    ),
                  ),
                  onSelected: (patient) {
                    setState(() {
                      _selectedPatientId = patient.patientId;
                      _patientSearchController.text = patient.fullName;
                      _selectedMedicalRecordId = null;
                      _patientRecords = [];
                    });
                    _loadPatientRecords(patient.patientId);
                  },
                ),
                const SizedBox(height: 16),
                // Medical Record selection
                _buildMedicalRecordSelector(),
                const SizedBox(height: 16),
                FutureBuilder<Either<Failure, List<BilanType>>>(
                  future: BilanRepository().getAllBilanTypes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final result = snapshot.data!;
                      return result.fold(
                        (failure) => const SizedBox.shrink(),
                        (types) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<BilanType>(
                            decoration: const InputDecoration(
                              labelText: 'Select Lab Test Template',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.list_alt),
                            ),
                            items: types.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(t.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  if (_testsController.text.isNotEmpty) {
                                    _testsController.text += '\n${val.bilans}';
                                  } else {
                                    _testsController.text = val.bilans;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      );
                    }
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
                TextFormField(
                  controller: _testsController,
                  decoration: const InputDecoration(
                    labelText: 'Lab Tests *',
                    hintText: 'Enter list of tests here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: isMobile ? 5 : 8,
                  validator: (value) =>
                      (value == null || value.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(Icons.monitor_weight),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (isMobile) const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
          : null,
      actions: isMobile
          ? [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previewPdf,
                          icon: const Icon(Icons.visibility),
                          label: const Text('Preview'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _save(true),
                    icon: const Icon(Icons.print),
                    label: const Text('Save & Print'),
                  ),
                ],
              ),
            ]
          : [
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
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton.icon(
                onPressed: _previewPdf,
                icon: const Icon(Icons.visibility),
                label: const Text('Preview'),
              ),
              ElevatedButton(
                onPressed: _isSaving ? null : () => _save(false),
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _save(true),
                icon: const Icon(Icons.print),
                label: const Text('Save & Print'),
              ),
            ],
    );
  }
}

// Simple TypeAhead helper for standard Bilan dialog
class _PatientTypeAheadField extends StatefulWidget {
  final Future<void> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, Patient) itemBuilder;
  final void Function(Patient) onSelected;
  final Widget Function(BuildContext, TextEditingController, FocusNode) builder;
  final TextEditingController controller;

  const _PatientTypeAheadField({
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.onSelected,
    required this.builder,
    required this.controller,
  });

  @override
  State<_PatientTypeAheadField> createState() => _PatientTypeAheadFieldState();
}

class _PatientTypeAheadFieldState extends State<_PatientTypeAheadField> {
  final FocusNode _focusNode = FocusNode();
  bool _hideSuggestions = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.builder(context, widget.controller, _focusNode),
        BlocBuilder<PatientCubit, PatientState>(
          builder: (context, state) {
            if (state.patients.isNotEmpty &&
                widget.controller.text.length >= 2 &&
                !_hideSuggestions) {
              return Container(
                height:
                    200, // Fixed height prevents intrinsic dimension errors in nested scrollables
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: state.patients.length,
                  itemBuilder: (context, index) {
                    final patient = state.patients[index];
                    return InkWell(
                      onTap: () {
                        setState(() => _hideSuggestions = true);
                        widget.onSelected(patient);
                      },
                      child: widget.itemBuilder(context, patient),
                    );
                  },
                ),
              );
            }
            // Reset hide flag when text is short (implies user starting fresh)
            if (widget.controller.text.length < 2 && _hideSuggestions) {
              _hideSuggestions = false;
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _BilanPrintDialog extends StatefulWidget {
  final Bilan bilan;

  const _BilanPrintDialog({required this.bilan});

  @override
  State<_BilanPrintDialog> createState() => _BilanPrintDialogState();
}

class _BilanPrintDialogState extends State<_BilanPrintDialog> {
  bool _isLoading = true;
  Patient? _patient;
  PrintTemplate _selectedTemplate = PrintTemplate.chifa;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    setState(() => _isLoading = true);
    await context.read<PatientCubit>().loadPatientById(widget.bilan.patientId);
    if (!mounted) return;
    final state = context.read<PatientCubit>().state;
    if (state.selectedPatient != null) {
      setState(() {
        _patient = state.selectedPatient;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _generatePdf() {
    return generateBilanPdf(
      patient: _patient!,
      bilanText: widget.bilan.bilans,
      dateCreation: widget.bilan.createdAt,
      template: _selectedTemplate,
    );
  }

  Future<void> _previewPdf() async {
    if (_patient == null) return;
    showPdfPreview(
      context: context,
      generatedPdfBytes: _generatePdf(),
      title: 'Lab Order Preview',
    );
  }

  Future<void> _printPdf() async {
    if (_patient == null) return;
    final pdfBytes = await _generatePdf();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print Lab Order'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patient == null
          ? const Text('Patient not found')
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
                const SizedBox(height: 8),
                const Text(
                  'Select Template:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Center(
                  child: SegmentedButton<PrintTemplate>(
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      selectedBackgroundColor: Colors.blue.shade700,
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Lab Tests:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.bilan.bilans),
                ),
              ],
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
