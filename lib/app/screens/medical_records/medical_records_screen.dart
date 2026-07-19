import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/screens/medical_records/medical_record_form_dialog.dart';
import 'package:chifa/app/screens/medical_records/medical_record_form_dialog_for_patient.dart';
import 'package:chifa/services/db/models/medical_record.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/repositories/medical_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:chifa/app/widgets/rich_text_viewer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Medical Records Screen - Displays consultations and medical records
class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _motifController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedDoctorId;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    context.read<MedicalRecordCubit>().loadMedicalRecords();
    context.read<MedicalRecordCubit>().loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _patientController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    context.read<MedicalRecordCubit>().filterMedicalRecords(
      startDate: _startDate,
      endDate: _endDate,
      doctorId: _selectedDoctorId,
      patientQuery: _patientController.text,
      motifQuery: _motifController.text,
    );
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedDoctorId = null;
      _patientController.clear();
      _motifController.clear();
      _searchController.clear();
    });
    context.read<MedicalRecordCubit>().loadMedicalRecords();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      _applyFilters();
    } else {
      context.read<MedicalRecordCubit>().searchMedicalRecords(query);
    }
  }

  void _showCreateDialog() {
    final tabId = 'new_medical_record_${DateTime.now().millisecondsSinceEpoch}';
    context.read<WorkspaceCubit>().openTab(
      WorkspaceTab(
        id: tabId,
        title: 'New Record',
        content: BlocProvider(
          create: (context) =>
              MedicalRecordCubit(context.read<MedicalRecordRepository>()),
          child: MedicalRecordFormDialog(tabId: tabId),
        ),
      ),
    );
  }

  void _showDetailsDialog(MedicalRecord record) {
    showDialog(
      context: context,
      builder: (context) => MedicalRecordDetailsDialog(record: record),
    );
  }

  void _showEditDialog(MedicalRecord record) {
    final patient = context.read<PatientCubit>().state.patients.firstWhere(
      (patient) => patient.patientId == record.patientId,
      orElse: () => Patient(
        patientId: record.patientId,
        firstName: record.patientFirstName ?? 'Unknown',
        lastName: record.patientLastName ?? 'Patient',
        gender: Gender.other,
        dateOfBirth: DateTime.now(),
      ),
    );
    final tabId = 'edit_medical_record_${record.id}';
    context.read<WorkspaceCubit>().openTab(
      WorkspaceTab(
        id: tabId,
        title: 'Edit: ${patient.fullName}',
        content: BlocProvider(
          create: (context) =>
              MedicalRecordCubit(context.read<MedicalRecordRepository>()),
          child: MedicalRecordFormDialogForPatient(
            patient: patient,
            recordToEdit: record,
            tabId: tabId,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(MedicalRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this medical record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (record.id != null) {
                context.read<MedicalRecordCubit>().deleteMedicalRecord(
                  record.id!,
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Action Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: isMobile
              ? Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showCreateDialog,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            label: const Text('Filters'),
                            selected: _showFilters,
                            onSelected: (val) =>
                                setState(() => _showFilters = val),
                            avatar: Icon(
                              Icons.filter_list,
                              size: 18,
                              color: _showFilters ? Colors.white : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            context
                                .read<MedicalRecordCubit>()
                                .loadMedicalRecords();
                            context.read<MedicalRecordCubit>().loadDoctors();
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Quick search (motif, patient)...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: _showFilters ? 'Hide Filters' : 'Show Filters',
                      child: FilterChip(
                        label: const Text('Filters'),
                        selected: _showFilters,
                        onSelected: (val) => setState(() => _showFilters = val),
                        avatar: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: _showFilters ? Colors.white : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        context.read<MedicalRecordCubit>().loadMedicalRecords();
                        context.read<MedicalRecordCubit>().loadDoctors();
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('New Record'),
                    ),
                  ],
                ),
        ),

        // Collapsible Filter Bar
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildFilterBar(),
          crossFadeState: _showFilters
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),

        const SizedBox(height: 16),

        // Records list
        Expanded(
          child: BlocBuilder<MedicalRecordCubit, MedicalRecordState>(
            builder: (context, state) {
              if (state.isLoading && state.medicalRecords.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.error != null && state.medicalRecords.isEmpty) {
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
                      Text('Error: ${state.error}'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context
                            .read<MedicalRecordCubit>()
                            .loadMedicalRecords(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state.medicalRecords.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No medical records found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: state.medicalRecords.length,
                itemBuilder: (context, index) {
                  final record = state.medicalRecords[index];
                  return _MedicalRecordCard(
                    record: record,
                    onTap: () => _showDetailsDialog(record),
                    onEdit: () => _showEditDialog(record),
                    onDelete: () => _confirmDelete(record),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return BlocBuilder<MedicalRecordCubit, MedicalRecordState>(
      builder: (context, state) {
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isMobile
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateFilter(
                              context,
                              'From',
                              _startDate,
                              (d) => setState(() => _startDate = d),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDateFilter(
                              context,
                              'To',
                              _endDate,
                              (d) => setState(() => _endDate = d),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDoctorFilter(state),
                      const SizedBox(height: 12),
                      _buildPatientFilter(),
                      const SizedBox(height: 12),
                      _buildMotifFilter(),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Filters'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildDateFilter(
                              context,
                              'From',
                              _startDate,
                              (d) => setState(() => _startDate = d),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: _buildDateFilter(
                              context,
                              'To',
                              _endDate,
                              (d) => setState(() => _endDate = d),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildDoctorFilter(state)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildPatientFilter()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildMotifFilter()),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: IconButton(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Reset Filters',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildDateFilter(
    BuildContext context,
    String label,
    DateTime? date,
    Function(DateTime) onPicked,
  ) {
    return _FilterItem(
      label: label,
      child: OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            initialDate: date ?? DateTime.now(),
          );
          if (picked != null) {
            onPicked(picked);
            _applyFilters();
          }
        },
        icon: const Icon(Icons.calendar_today, size: 14),
        label: Text(
          date == null ? 'Select' : DateFormat('dd/MM').format(date),
          style: const TextStyle(fontSize: 10),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildDoctorFilter(MedicalRecordState state) {
    return _FilterItem(
      label: 'Doctor',
      child: DropdownButtonFormField<int>(
        initialValue: _selectedDoctorId,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(),
        ),
        hint: const Text('All Doctors', style: TextStyle(fontSize: 12)),
        items: [
          const DropdownMenuItem<int>(
            value: null,
            child: Text('All Doctors', style: TextStyle(fontSize: 12)),
          ),
          ...state.doctors.map(
            (doc) => DropdownMenuItem<int>(
              value: doc.employeeId,
              child: Text(doc.fullName, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
        onChanged: (val) {
          setState(() => _selectedDoctorId = val);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildPatientFilter() {
    return _FilterItem(
      label: 'Patient Name',
      child: TextField(
        controller: _patientController,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          hintText: 'Search patient...',
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildMotifFilter() {
    return _FilterItem(
      label: 'Motif',
      child: TextField(
        controller: _motifController,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          hintText: 'Motif/Diagnostic...',
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }
}

class _MedicalRecordCard extends StatelessWidget {
  final MedicalRecord record;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicalRecordCard({
    required this.record,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.medical_services,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.patientFirstName ?? ""} ${record.patientLastName ?? ""}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Motif: ${record.motif ?? "None"}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.indigo.shade700,
                        fontSize: 13,
                      ),
                    ),
                    if (record.diagnostic != null &&
                        record.diagnostic!.isNotEmpty)
                      Text(
                        'Diagnostic: ${record.diagnostic}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(record.recordDate),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMobile)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'view') onTap();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.visibility, color: Colors.blue),
                        title: Text('View'),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: onTap,
                      tooltip: 'View Details',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: onEdit,
                      tooltip: 'Edit Record',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                      tooltip: 'Delete Record',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Medical Record Details Dialog
class MedicalRecordDetailsDialog extends StatelessWidget {
  final MedicalRecord record;

  const MedicalRecordDetailsDialog({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Medical Record Details'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailSection(
                title: 'Consultation Information',
                children: [
                  _DetailRow(label: 'Motif', value: record.motif ?? 'N/A'),
                  _DetailRow(label: 'Details', value: record.details),
                  if (record.diagnostic != null &&
                      record.diagnostic!.isNotEmpty)
                    _DetailRow(label: 'Diagnostic', value: record.diagnostic!),
                  if (record.prescriptions != null &&
                      record.prescriptions!.isNotEmpty)
                    _DetailRow(
                      label: 'Prescriptions',
                      value: record.prescriptions!,
                    ),
                ],
              ),
              const Divider(height: 32),
              _DetailSection(
                title: 'Vitals & Metadata',
                children: [
                  _DetailRow(label: 'Patient ID', value: '${record.patientId}'),
                  _DetailRow(label: 'Doctor ID', value: '${record.doctorId}'),
                  if (record.weight != null)
                    _DetailRow(label: 'Weight', value: '${record.weight} kg'),
                  if (record.temperature != null)
                    _DetailRow(
                      label: 'Temperature',
                      value: '${record.temperature} °C',
                    ),
                  if (record.tensionArterielle != null &&
                      record.tensionArterielle!.isNotEmpty)
                    _DetailRow(
                      label: 'Blood Pressure',
                      value: record.tensionArterielle!,
                    ),
                  if (record.frequenceCardiaque != null)
                    _DetailRow(
                      label: 'Heart Rate',
                      value: '${record.frequenceCardiaque} bpm',
                    ),
                  if (record.spao2 != null)
                    _DetailRow(label: 'SpO2', value: '${record.spao2}%'),
                  _DetailRow(label: 'Timer', value: record.recordTimer),
                  _DetailRow(
                    label: 'Date',
                    value: DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(record.recordDate),
                  ),
                ],
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
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...children,
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
          Expanded(child: RichTextViewer(text: value)),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final String label;
  final Widget child;

  const _FilterItem({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
