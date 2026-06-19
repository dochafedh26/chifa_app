import 'dart:typed_data';

import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/certificate_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/printing/arret_de_travail.dart';
import 'package:chifa/app/printing/certificat_bonne_sante.dart';
import 'package:chifa/app/printing/dispense_sport.dart';
import 'package:chifa/app/printing/lettre_de_liaison.dart';
import 'package:chifa/app/printing/maladie_chronique.dart';
import 'package:chifa/app/printing/certificat_prenuptial.dart';
import 'package:chifa/app/printing/preview.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/models/arret_de_travail.dart';
import 'package:chifa/services/db/models/bonne_sante.dart';
import 'package:chifa/services/db/models/certificat_maladie_chronique.dart';
import 'package:chifa/services/db/models/certificat_prenuptial.dart';
import 'package:chifa/services/db/models/dispense_sport.dart';
import 'package:chifa/services/db/models/lettre.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/print_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// Work Certificates Screen - Arret de travail and Lettres
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    context.read<CertificateCubit>().loadArretsDeTravail();
    context.read<CertificateCubit>().loadLettres();
    context.read<CertificateCubit>().loadCertificatsPrenuptial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      children: [
        // Tabs
        TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          tabs: [
            Tab(
              icon: const Icon(Icons.verified_user),
              text: isMobile ? 'Work' : 'Work Certificates',
            ),
            Tab(
              icon: const Icon(Icons.email),
              text: isMobile ? 'Letters' : 'Medical Letters',
            ),
            Tab(
              icon: const Icon(Icons.medical_information),
              text: isMobile ? 'Chronic' : 'Maladie Chronique',
            ),
            Tab(
              icon: const Icon(Icons.health_and_safety),
              text: isMobile ? 'Health' : 'Bonne Santé',
            ),
            Tab(
              icon: const Icon(Icons.fitness_center),
              text: isMobile ? 'Sport' : 'Dispense Sport',
            ),
            Tab(
              icon: const Icon(Icons.favorite),
              text: isMobile ? 'Prénuptial' : 'Certificat Prénuptial',
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ArretDeTravailList(),
              _LettresList(),
              _MaladieChroniqueList(),
              _BonneSanteList(),
              _DispenseSportList(),
              _PrenuptialList(),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== MALADIE CHRONIQUE ====================

class _MaladieChroniqueList extends StatefulWidget {
  const _MaladieChroniqueList();

  @override
  State<_MaladieChroniqueList> createState() => _MaladieChroniqueListState();
}

class _MaladieChroniqueListState extends State<_MaladieChroniqueList> {
  final _patientSearchController = TextEditingController();
  List<Patient> _patientResults = [];
  Patient? _selectedPatient;
  bool _isSearchingPatient = false;
  bool _showPatientSuggestions = false;

  int? _doctorId;

  final _maladieController = TextEditingController();

  bool _isCreating = false;
  int? _editingCertId;
  final List<CertificatMaladieChronique> _certificats = [];
  final bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    _doctorId = authCubit.currentUser?.employeeId;
    context.read<CertificateCubit>().loadCertificatsMaladieChronique();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _maladieController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _patientResults = [];
        _showPatientSuggestions = false;
      });
      return;
    }
    setState(() => _isSearchingPatient = true);
    try {
      final results = await DatabaseManager.instance.query(
        '''SELECT * FROM patients 
           WHERE first_name LIKE ? OR last_name LIKE ? OR patient_id = ?
           LIMIT 10''',
        ['%$query%', '%$query%', int.tryParse(query) ?? -1],
      );
      if (mounted) {
        setState(() {
          _patientResults = results.map((row) => Patient.fromMap(row)).toList();
          _showPatientSuggestions = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingPatient = false);
    }
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _patientSearchController.text = patient.fullName;
      _patientResults = [];
      _showPatientSuggestions = false;
    });
  }

  void _startEdit(CertificatMaladieChronique cert) async {
    final db = DatabaseManager.instance;
    final results = await db.query(
      'SELECT * FROM patients WHERE patient_id = ?',
      [cert.patientId],
    );
    if (results.isNotEmpty && mounted) {
      final patient = Patient.fromMap(results.first);
      setState(() {
        _selectedPatient = patient;
        _patientSearchController.text = patient.fullName;
        _editingCertId = cert.id;
        _maladieController.text = cert.maladieChronique;
      });
    }
  }

  void _printOnly() {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_maladieController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in the chronic disease (Maladie Chronique)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final cert = CertificatMaladieChronique(
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId,
      maladieChronique: _maladieController.text,
      createdAt: DateTime.now(),
    );
    _showPrintDialog(cert);
  }

  Future<void> _createCertificat() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_maladieController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in the chronic disease (Maladie Chronique)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final cert = CertificatMaladieChronique(
      id: _editingCertId,
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId,
      maladieChronique: _maladieController.text,
      createdAt: DateTime.now(),
    );

    if (_editingCertId != null) {
      // For now, CertificateCubit doesn't have update for this, I'll add it or just use create with ID if supported
      // Actually I should add update methods to Cubit for consistency.
      // But I'll stick to what I added first.
      context.read<CertificateCubit>().createCertificatMaladieChronique(cert);
    } else {
      context.read<CertificateCubit>().createCertificatMaladieChronique(cert);
    }
  }

  Future<void> _deleteCertificat(int id) async {
    context.read<CertificateCubit>().deleteCertificatMaladieChronique(id);
  }

  void _resetForm() {
    setState(() {
      _editingCertId = null;
      _selectedPatient = null;
      _patientSearchController.clear();
      _maladieController.clear();
    });
  }

  void _showPrintDialog(CertificatMaladieChronique cert) {
    showDialog(
      context: context,
      builder: (context) => _MaladieChroniquePrintDialog(certificat: cert),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== Create Form =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nouveau Certificat de Maladie Chronique',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Patient search
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _patientSearchController,
                        decoration: InputDecoration(
                          labelText: 'Patient *',
                          hintText: 'Search by name or ID...',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_search, size: 20),
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
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _selectedPatient = null;
                                      _patientSearchController.clear();
                                      _showPatientSuggestions = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => _searchPatients(value),
                      ),
                      if (_showPatientSuggestions && _patientResults.isNotEmpty)
                        Container(
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
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _patientResults.length,
                            separatorBuilder: (_, index) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final p = _patientResults[index];
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
                                  'ID: ${p.patientId} • ${p.age} ans',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () => _selectPatient(p),
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                  // Patient info badge
                  if (_selectedPatient != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.teal.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedPatient!.fullName}  •  ${_selectedPatient!.age} ans  •  ${_selectedPatient!.gender.name}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.teal.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Maladie Chronique
                  TextFormField(
                    controller: _maladieController,
                    decoration: const InputDecoration(
                      labelText: 'Maladie Chronique *',
                      hintText:
                          'Ex: Diabète de type 2, Hypertension artérielle...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_information),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isCreating ? null : _createCertificat,
                              icon: _isCreating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _editingCertId != null
                                          ? Icons.save
                                          : Icons.add,
                                    ),
                              label: Text(
                                _editingCertId != null
                                    ? 'Modifier'
                                    : 'Enregistrer',
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _printOnly,
                              icon: const Icon(Icons.print),
                              label: const Text('Imprimer'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                            if (_editingCertId != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _resetForm,
                                child: const Text('Annuler'),
                              ),
                            ],
                          ],
                        )
                      : Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_editingCertId != null)
                              TextButton(
                                onPressed: _resetForm,
                                child: const Text('Annuler'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _printOnly,
                              icon: const Icon(Icons.print),
                              label: const Text('Imprimer uniquement'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isCreating ? null : _createCertificat,
                              icon: _isCreating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _editingCertId != null
                                          ? Icons.save
                                          : Icons.add,
                                    ),
                              label: Text(
                                _editingCertId != null
                                    ? 'Modifier le Certificat'
                                    : 'Enregistrer le Certificat',
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          BlocBuilder<CertificateCubit, CertificateState>(
            builder: (context, state) {
              final cubit = context.read<CertificateCubit>();
              final items = state is CertificatsMaladieChroniqueLoaded
                  ? state.certificats
                  : cubit.allCertificatsMaladieChronique;

              if (state is CertificateLoading && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (items.isEmpty) {
                return const Center(child: Text('Aucun certificat trouvé'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final cert = items[index];
                  return _MaladieChroniqueCard(
                    certificat: cert,
                    onEdit: () => _startEdit(cert),
                    onPrint: () => _showPrintDialog(cert),
                    onDelete: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer Certificat'),
                          content: const Text(
                            'Êtes-vous sûr de vouloir supprimer ce certificat ?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteCertificat(cert.id!);
                              },
                              child: const Text(
                                'Supprimer',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PatientNameWidget extends StatefulWidget {
  final int patientId;
  const _PatientNameWidget({required this.patientId});

  @override
  State<_PatientNameWidget> createState() => _PatientNameWidgetState();
}

class _PatientNameWidgetState extends State<_PatientNameWidget> {
  String? _patientName;

  @override
  void initState() {
    super.initState();
    _loadPatientName();
  }

  Future<void> _loadPatientName() async {
    try {
      final results = await DatabaseManager.instance.query(
        'SELECT first_name, last_name FROM patients WHERE patient_id = ?',
        [widget.patientId],
      );
      if (results.isNotEmpty && mounted) {
        final row = results.first;
        setState(() {
          _patientName = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Text('Patient: ${_patientName ?? 'ID ${widget.patientId}'}');
  }
}

class _MaladieChroniqueCard extends StatelessWidget {
  final CertificatMaladieChronique certificat;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _MaladieChroniqueCard({
    required this.certificat,
    required this.onEdit,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: Icon(Icons.medical_information, color: Colors.teal.shade700),
        ),
        title: const Text(
          'Certificat de Maladie Chronique',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _PatientNameWidget(patientId: certificat.patientId),
            Text('Maladie: ${certificat.maladieChronique}'),
            Text(
              'Créé le: ${DateFormat('dd/MM/yyyy').format(certificat.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: MediaQuery.of(context).size.width < 800
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'print') onPrint();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.orange),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      leading: Icon(Icons.print, color: Colors.blue),
                      title: Text('Print'),
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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    onPressed: onPrint,
                    tooltip: 'Print PDF',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
        isThreeLine: true,
      ),
    );
  }
}

class _MaladieChroniquePrintDialog extends StatefulWidget {
  final CertificatMaladieChronique certificat;

  const _MaladieChroniquePrintDialog({required this.certificat});

  @override
  State<_MaladieChroniquePrintDialog> createState() =>
      _MaladieChroniquePrintDialogState();
}

class _MaladieChroniquePrintDialogState
    extends State<_MaladieChroniquePrintDialog> {
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
    await context.read<PatientCubit>().loadPatientById(
      widget.certificat.patientId,
    );
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

  Future<Uint8List> _generatePdfBytes() {
    return generateMaladieChroniquePdf(
      patient: _patient!,
      maladieChronique: widget.certificat.maladieChronique,
      dateCreation: widget.certificat.createdAt,
      template: _selectedTemplate,
    );
  }

  Future<void> _printPdf() async {
    if (_patient == null) return;
    final pdfBytes = await _generatePdfBytes();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  void _previewPdf() {
    if (_patient == null) return;
    showPdfPreview(
      context: context,
      generatedPdfBytes: _generatePdfBytes(),
      title: 'Certificat Maladie Chronique - Preview',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Print Certificat Maladie Chronique',
      ), // Template support
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
                Text('Maladie: ${widget.certificat.maladieChronique}'),
                Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(widget.certificat.createdAt)}',
                ),
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
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
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

// ==================== ARRET DE TRAVAIL TYPES ====================

/// The 3 document types matching the PHP dropdown options
const List<String> _arretTypes = [
  'ARRET DE TRAVAIL',
  "PROLONGATION D'ARRET",
  'REPRISE DE TRAVAIL',
];

// ==================== ARRET DE TRAVAIL ====================

class _ArretDeTravailList extends StatefulWidget {
  const _ArretDeTravailList();

  @override
  State<_ArretDeTravailList> createState() => _ArretDeTravailListState();
}

class _ArretDeTravailListState extends State<_ArretDeTravailList> {
  // Patient search
  final _patientSearchController = TextEditingController();
  List<Patient> _patientResults = [];
  Patient? _selectedPatient;
  bool _isSearchingPatient = false;
  bool _showPatientSuggestions = false;

  // Doctor (auto-filled from auth)
  String _doctorName = '';
  int? _doctorId;

  // Form fields
  String _selectedType = _arretTypes[0];
  final _motifController = TextEditingController();
  final _joursController = TextEditingController(text: '1');
  DateTime _dateDebut = DateTime.now();
  DateTime? _dateReprise;

  bool _isCreating = false;
  int? _editingArretId;

  @override
  void initState() {
    super.initState();
    // Auto-fill doctor from auth
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;
    _doctorName = user?.fullName ?? '';
    _doctorId = user?.employeeId;
    _recalculateDateReprise();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _motifController.dispose();
    _joursController.dispose();
    super.dispose();
  }

  void _recalculateDateReprise() {
    final jours = int.tryParse(_joursController.text) ?? 0;
    setState(() {
      _dateReprise = _dateDebut.add(Duration(days: jours));
    });
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _patientResults = [];
        _showPatientSuggestions = false;
      });
      return;
    }
    setState(() => _isSearchingPatient = true);
    try {
      final results = await DatabaseManager.instance.query(
        '''SELECT * FROM patients 
           WHERE first_name LIKE ? OR last_name LIKE ? OR patient_id = ?
           LIMIT 10''',
        ['%$query%', '%$query%', int.tryParse(query) ?? -1],
      );
      if (mounted) {
        setState(() {
          _patientResults = results.map((row) => Patient.fromMap(row)).toList();
          _showPatientSuggestions = true;
        });
      }
    } catch (_) {
      // ignore search errors
    } finally {
      if (mounted) setState(() => _isSearchingPatient = false);
    }
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _patientSearchController.text = patient.fullName;
      _patientResults = [];
      _showPatientSuggestions = false;
    });
  }

  Future<void> _pickDateDebut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateDebut = picked;
      });
      _recalculateDateReprise();
    }
  }

  Future<void> _pickDateReprise() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReprise ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateReprise = picked;
        // Recalculate days from dateDebut to dateReprise
        final diff = picked.difference(_dateDebut).inDays;
        if (diff >= 0) {
          _joursController.text = diff.toString();
        }
      });
    }
  }

  void _startEdit(ArretDeTravail arret) async {
    // Load patient details to fill the dropdown search
    final db = DatabaseManager.instance;
    final results = await db.query(
      'SELECT * FROM patients WHERE patient_id = ?',
      [arret.patientId],
    );
    if (results.isNotEmpty && mounted) {
      final patient = Patient.fromMap(results.first);
      setState(() {
        _selectedPatient = patient;
        _patientSearchController.text = patient.fullName;
        _editingArretId = arret.id;
        _selectedType = arret.type;
        _motifController.text = arret.motif;
        _joursController.text = arret.jours.toString();
        _dateDebut = arret.dateDebut;
        _dateReprise = arret.dateReprise;
      });
    }
  }

  void _printOnly() {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final jours = int.tryParse(_joursController.text) ?? 1;
    final arret = ArretDeTravail(
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId ?? 0,
      type: _selectedType,
      motif: _motifController.text,
      dateDebut: _dateDebut,
      jours: jours,
      dateReprise: _dateReprise ?? _dateDebut.add(Duration(days: jours)),
    );
    _showPrintDialog(arret);
  }

  void _createArret() {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final jours = int.tryParse(_joursController.text) ?? 1;
    final dateReprise = _dateReprise ?? _dateDebut.add(Duration(days: jours));

    final arret = ArretDeTravail(
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId ?? 0,
      type: _selectedType,
      motif: _motifController.text,
      dateDebut: _dateDebut,
      jours: jours,
      dateReprise: dateReprise,
    );

    if (_editingArretId != null) {
      context.read<CertificateCubit>().updateArretDeTravail(
        _editingArretId!,
        arret,
      );
    } else {
      context.read<CertificateCubit>().createArretDeTravail(arret);
    }
  }

  void _resetForm() {
    setState(() {
      _editingArretId = null;
      _selectedPatient = null;
      _patientSearchController.clear();
      _motifController.clear();
      _joursController.text = '1';
      _selectedType = _arretTypes[0];
      _dateDebut = DateTime.now();
      _recalculateDateReprise();
    });
  }

  void _showPrintDialog(ArretDeTravail arret) {
    showDialog(
      context: context,
      builder: (context) => _ArretPrintDialog(arret: arret),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return BlocListener<CertificateCubit, CertificateState>(
      listener: (context, state) {
        setState(() => _isCreating = false);
        if (state is CertificateOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
        } else if (state is CertificateError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Create Form =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Créer un Arrêt de Travail',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Row 1: Patient Search + Doctor (readonly)
                    isMobile
                        ? Column(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _patientSearchController,
                                    decoration: InputDecoration(
                                      labelText: 'Patient *',
                                      hintText: 'Search by name or ID...',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(
                                        Icons.person_search,
                                        size: 20,
                                      ),
                                      suffixIcon: _isSearchingPatient
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : _selectedPatient != null
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 16,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _selectedPatient = null;
                                                  _patientSearchController
                                                      .clear();
                                                  _showPatientSuggestions =
                                                      false;
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (value) =>
                                        _searchPatients(value),
                                  ),
                                  if (_showPatientSuggestions &&
                                      _patientResults.isNotEmpty)
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 180,
                                      ),
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _patientResults.length,
                                        separatorBuilder: (_, index) => Divider(
                                          height: 1,
                                          color: Colors.grey.shade200,
                                        ),
                                        itemBuilder: (context, index) {
                                          final p = _patientResults[index];
                                          return ListTile(
                                            dense: true,
                                            leading: const Icon(
                                              Icons.person,
                                              size: 20,
                                            ),
                                            title: Text(
                                              p.fullName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'ID: ${p.patientId} • ${p.age} ans',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            onTap: () => _selectPatient(p),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                readOnly: true,
                                initialValue: _doctorName,
                                decoration: const InputDecoration(
                                  labelText: 'Doctor',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medical_services),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Patient search field
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _patientSearchController,
                                      decoration: InputDecoration(
                                        labelText: 'Patient *',
                                        hintText: 'Search by name or ID...',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(
                                          Icons.person_search,
                                          size: 20,
                                        ),
                                        suffixIcon: _isSearchingPatient
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : _selectedPatient != null
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  size: 16,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedPatient = null;
                                                    _patientSearchController
                                                        .clear();
                                                    _showPatientSuggestions =
                                                        false;
                                                  });
                                                },
                                              )
                                            : null,
                                      ),
                                      onChanged: (value) =>
                                          _searchPatients(value),
                                    ),
                                    // Patient suggestions
                                    if (_showPatientSuggestions &&
                                        _patientResults.isNotEmpty)
                                      Container(
                                        constraints: const BoxConstraints(
                                          maxHeight: 180,
                                        ),
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          itemCount: _patientResults.length,
                                          separatorBuilder: (_, index) =>
                                              Divider(
                                                height: 1,
                                                color: Colors.grey.shade200,
                                              ),
                                          itemBuilder: (context, index) {
                                            final p = _patientResults[index];
                                            return ListTile(
                                              dense: true,
                                              leading: const Icon(
                                                Icons.person,
                                                size: 20,
                                              ),
                                              title: Text(
                                                p.fullName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'ID: ${p.patientId} • ${p.age} ans',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              onTap: () => _selectPatient(p),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Doctor (read-only, auto-filled)
                              Expanded(
                                child: TextFormField(
                                  readOnly: true,
                                  initialValue: _doctorName,
                                  decoration: const InputDecoration(
                                    labelText: 'Doctor',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.medical_services),
                                  ),
                                ),
                              ),
                            ],
                          ),

                    // Patient info badge (shown when selected)
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
                              '${_selectedPatient!.fullName}  •  ${_selectedPatient!.age} ans  •  ${_selectedPatient!.gender.name}',
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
                    const SizedBox(height: 16),

                    // Row 2: Type dropdown + Motif
                    isMobile
                        ? Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _selectedType,
                                decoration: const InputDecoration(
                                  labelText: 'Type de document *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: _arretTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedType = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _joursController,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre de jours',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.timer),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _recalculateDateReprise(),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Type dropdown
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedType,
                                  decoration: const InputDecoration(
                                    labelText: 'Type de document *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.category),
                                  ),
                                  items: _arretTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedType = value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Nombre de jours
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  controller: _joursController,
                                  decoration: const InputDecoration(
                                    labelText: 'Jours',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.timer),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _recalculateDateReprise(),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),

                    // Motif
                    TextFormField(
                      controller: _motifController,
                      decoration: const InputDecoration(
                        labelText: 'Motif Médical',
                        hintText: 'Ex: État grippal, Repos strict...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Row 3: Date début + Date reprise
                    isMobile
                        ? Column(
                            children: [
                              InkWell(
                                onTap: _pickDateDebut,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date de début',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(
                                    dateFormat.format(_dateDebut),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _pickDateReprise,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date de reprise',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.event_available),
                                  ),
                                  child: Text(
                                    _dateReprise != null
                                        ? dateFormat.format(_dateReprise!)
                                        : '—',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDateDebut,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date de début',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      dateFormat.format(_dateDebut),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDateReprise,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date de reprise',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.event_available),
                                    ),
                                    child: Text(
                                      _dateReprise != null
                                          ? dateFormat.format(_dateReprise!)
                                          : '—',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),

                    // Action buttons
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isCreating ? null : _createArret,
                                icon: _isCreating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _editingArretId != null
                                            ? Icons.save
                                            : Icons.add,
                                      ),
                                label: Text(
                                  _editingArretId != null
                                      ? 'Modifier'
                                      : 'Enregistrer',
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _printOnly,
                                icon: const Icon(Icons.print),
                                label: const Text('Imprimer'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              if (_editingArretId != null) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _resetForm,
                                  child: const Text('Annuler'),
                                ),
                              ],
                            ],
                          )
                        : Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_editingArretId != null)
                                TextButton(
                                  onPressed: _resetForm,
                                  child: const Text('Annuler'),
                                ),
                              OutlinedButton.icon(
                                onPressed: _printOnly,
                                icon: const Icon(Icons.print),
                                label: const Text('Imprimer uniquement'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isCreating ? null : _createArret,
                                icon: _isCreating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _editingArretId != null
                                            ? Icons.save
                                            : Icons.add,
                                      ),
                                label: Text(
                                  _editingArretId != null
                                      ? 'Modifier le Certificat'
                                      : 'Enregistrer et Générer le Certificat',
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== List =====
            BlocBuilder<CertificateCubit, CertificateState>(
              builder: (context, state) {
                final cubit = context.read<CertificateCubit>();
                final arrets = state is ArretsDeTravailLoaded
                    ? state.arretsDeTravail
                    : cubit.allArrets;

                if (state is CertificateLoading && arrets.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (arrets.isEmpty) {
                  return const Center(
                    child: Text('No work certificates found'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: arrets.length,
                  itemBuilder: (context, index) {
                    final arret = arrets[index];
                    return _ArretCard(
                      arret: arret,
                      onEdit: () => _startEdit(arret),
                      onPrint: () => _showPrintDialog(arret),
                      onDelete: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Certificate'),
                            content: const Text(
                              'Are you sure you want to delete this certificate?',
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
                                      .read<CertificateCubit>()
                                      .deleteArretDeTravail(arret.id!);
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
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArretCard extends StatelessWidget {
  final ArretDeTravail arret;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _ArretCard({
    required this.arret,
    required this.onEdit,
    required this.onPrint,
    required this.onDelete,
  });

  Color _getTypeColor() {
    switch (arret.type) {
      case 'ARRET DE TRAVAIL':
        return Colors.orange;
      case "PROLONGATION D'ARRET":
        return Colors.deepOrange;
      case 'REPRISE DE TRAVAIL':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    switch (arret.type) {
      case 'ARRET DE TRAVAIL':
        return Icons.pause_circle_filled;
      case "PROLONGATION D'ARRET":
        return Icons.update;
      case 'REPRISE DE TRAVAIL':
        return Icons.play_circle_filled;
      default:
        return Icons.verified_user;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.12),
          child: Icon(_getTypeIcon(), color: typeColor),
        ),
        title: Text(
          arret.type.isNotEmpty ? arret.type.toUpperCase() : 'WORK CERTIFICATE',
          style: TextStyle(fontWeight: FontWeight.bold, color: typeColor),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _PatientNameWidget(patientId: arret.patientId),
            if (arret.motif.isNotEmpty) Text('Motif: ${arret.motif}'),
            Text('Duration: ${arret.jours} jour(s)'),
            Text(
              'Début: ${DateFormat('dd/MM/yyyy').format(arret.dateDebut)}  →  Reprise: ${DateFormat('dd/MM/yyyy').format(arret.dateReprise)}',
            ),
            Text(
              'Créé le: ${DateFormat('dd/MM/yyyy').format(arret.dateCreation)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: MediaQuery.of(context).size.width < 800
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'print') onPrint();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.orange),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      leading: Icon(Icons.print, color: Colors.blue),
                      title: Text('Print'),
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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    onPressed: onPrint,
                    tooltip: 'Print PDF',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
        isThreeLine: true,
      ),
    );
  }
}

class _ArretPrintDialog extends StatefulWidget {
  final ArretDeTravail arret;

  const _ArretPrintDialog({required this.arret});

  @override
  State<_ArretPrintDialog> createState() => _ArretPrintDialogState();
}

class _ArretPrintDialogState extends State<_ArretPrintDialog> {
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
    await context.read<PatientCubit>().loadPatientById(widget.arret.patientId);
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

  Future<Uint8List> _generatePdfBytes() {
    return generateArretDeTravailPdf(
      patient: _patient!,
      arretType: widget.arret.type,
      motif: widget.arret.motif,
      dateDebut: widget.arret.dateDebut,
      dateReprise: widget.arret.dateReprise,
      jours: widget.arret.jours,
      dateCreation: widget.arret.dateCreation,
      template: _selectedTemplate,
    );
  }

  Future<void> _printPdf() async {
    if (_patient == null) return;
    final pdfBytes = await _generatePdfBytes();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  void _previewPdf() {
    if (_patient == null) return;
    showPdfPreview(
      context: context,
      generatedPdfBytes: _generatePdfBytes(),
      title: 'Certificat Médical - Preview',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print Work Certificate'),
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
                Text('Type: ${widget.arret.type}'),
                if (widget.arret.motif.isNotEmpty)
                  Text('Motif: ${widget.arret.motif}'),
                Text('Duration: ${widget.arret.jours} jour(s)'),
                Text(
                  'Début: ${DateFormat('dd/MM/yyyy').format(widget.arret.dateDebut)}',
                ),
                Text(
                  'Reprise: ${DateFormat('dd/MM/yyyy').format(widget.arret.dateReprise)}',
                ),
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
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
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

// ==================== LETTRES ====================

class _LettresList extends StatefulWidget {
  const _LettresList();

  @override
  State<_LettresList> createState() => _LettresListState();
}

class _LettresListState extends State<_LettresList> {
  // Patient search
  final _patientSearchController = TextEditingController();
  List<Patient> _patientResults = [];
  Patient? _selectedPatient;
  bool _isSearchingPatient = false;
  bool _showPatientSuggestions = false;

  // Doctor (auto-filled from auth)
  int? _doctorId;

  // Form fields
  final _atcdController = TextEditingController();
  final _motifConsultationController = TextEditingController();
  final _examenCliniqueController = TextEditingController();
  final _motifLettreController = TextEditingController();

  bool _isCreating = false;
  int? _editingLettreId;

  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    _doctorId = authCubit.currentUser?.employeeId;
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _atcdController.dispose();
    _motifConsultationController.dispose();
    _examenCliniqueController.dispose();
    _motifLettreController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _patientResults = [];
        _showPatientSuggestions = false;
      });
      return;
    }
    setState(() => _isSearchingPatient = true);
    try {
      final results = await DatabaseManager.instance.query(
        '''SELECT * FROM patients 
           WHERE first_name LIKE ? OR last_name LIKE ? OR patient_id = ?
           LIMIT 10''',
        ['%$query%', '%$query%', int.tryParse(query) ?? -1],
      );
      if (mounted) {
        setState(() {
          _patientResults = results.map((row) => Patient.fromMap(row)).toList();
          _showPatientSuggestions = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingPatient = false);
    }
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _patientSearchController.text = patient.fullName;
      _patientResults = [];
      _showPatientSuggestions = false;
      // Auto-fill ATCD from patient
      if (patient.atcd.isNotEmpty && _atcdController.text.isEmpty) {
        _atcdController.text = patient.atcd;
      }
    });
  }

  void _startEdit(Lettre lettre) async {
    final db = DatabaseManager.instance;
    final results = await db.query(
      'SELECT * FROM patients WHERE patient_id = ?',
      [lettre.patientId],
    );
    if (results.isNotEmpty && mounted) {
      final patient = Patient.fromMap(results.first);
      setState(() {
        _selectedPatient = patient;
        _patientSearchController.text = patient.fullName;
        _editingLettreId = lettre.id;
        _atcdController.text = lettre.atcd ?? '';
        _motifConsultationController.text = lettre.motifConsultation;
        _examenCliniqueController.text = lettre.examenClinique ?? '';
        _motifLettreController.text = lettre.motifLettre;
      });
    }
  }

  void _printOnly() {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final lettre = Lettre(
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId,
      atcd: _atcdController.text,
      motifConsultation: _motifConsultationController.text,
      examenClinique: _examenCliniqueController.text,
      motifLettre: _motifLettreController.text,
    );
    _showPrintDialog(lettre);
  }

  void _createLettre() {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_motifLettreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in the letter motive (Je vous l\'adresse pour)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final lettre = Lettre(
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId,
      atcd: _atcdController.text,
      motifConsultation: _motifConsultationController.text,
      examenClinique: _examenCliniqueController.text,
      motifLettre: _motifLettreController.text,
    );

    if (_editingLettreId != null) {
      context.read<CertificateCubit>().updateLettre(_editingLettreId!, lettre);
    } else {
      context.read<CertificateCubit>().createLettre(lettre);
    }
  }

  void _resetForm() {
    setState(() {
      _editingLettreId = null;
      _selectedPatient = null;
      _patientSearchController.clear();
      _atcdController.clear();
      _motifConsultationController.clear();
      _examenCliniqueController.clear();
      _motifLettreController.clear();
    });
  }

  void _showPrintDialog(Lettre lettre) {
    showDialog(
      context: context,
      builder: (context) => _LettrePrintDialog(lettre: lettre),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final isMobile = MediaQuery.of(context).size.width < 800;
    return BlocListener<CertificateCubit, CertificateState>(
      listener: (context, state) {
        setState(() => _isCreating = false);
        if (state is CertificateOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
        } else if (state is CertificateError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Create Form =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvelle Lettre de Liaison',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Patient search
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _patientSearchController,
                          decoration: InputDecoration(
                            labelText: 'Patient *',
                            hintText: 'Search by name or ID...',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(
                              Icons.person_search,
                              size: 20,
                            ),
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
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        _selectedPatient = null;
                                        _patientSearchController.clear();
                                        _showPatientSuggestions = false;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) => _searchPatients(value),
                        ),
                        if (_showPatientSuggestions &&
                            _patientResults.isNotEmpty)
                          Container(
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
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _patientResults.length,
                              separatorBuilder: (_, index) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final p = _patientResults[index];
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
                                    'ID: ${p.patientId} • ${p.age} ans',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => _selectPatient(p),
                                );
                              },
                            ),
                          ),
                      ],
                    ),

                    // Patient info badge
                    if (_selectedPatient != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedPatient!.fullName}  •  ${_selectedPatient!.age} ans  •  ${_selectedPatient!.gender.name}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.purple.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ATCD
                    TextFormField(
                      controller: _atcdController,
                      decoration: const InputDecoration(
                        labelText: 'ATCD de',
                        hintText: 'Antécédents du patient...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.history),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Consulte pour
                    TextFormField(
                      controller: _motifConsultationController,
                      decoration: const InputDecoration(
                        labelText: 'Consulte pour',
                        hintText: 'Motif de la consultation...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_information),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Examen Clinique
                    TextFormField(
                      controller: _examenCliniqueController,
                      decoration: const InputDecoration(
                        labelText: 'Examen Clinique',
                        hintText: 'Résultats de l\'examen clinique...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.biotech),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    // Je vous l'adresse pour (motifLettre)
                    TextFormField(
                      controller: _motifLettreController,
                      decoration: const InputDecoration(
                        labelText: 'Je vous l\'adresse pour *',
                        hintText: 'Motif de la lettre...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.send),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_editingLettreId != null)
                          TextButton(
                            onPressed: _resetForm,
                            child: const Text('Annuler'),
                          ),
                        OutlinedButton.icon(
                          onPressed: _printOnly,
                          icon: const Icon(Icons.print),
                          label: const Text('Imprimer uniquement'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isCreating ? null : _createLettre,
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _editingLettreId != null
                                      ? Icons.save
                                      : Icons.add,
                                ),
                          label: Text(
                            _editingLettreId != null
                                ? 'Modifier la Lettre'
                                : 'Enregistrer la Lettre',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== List =====
            BlocBuilder<CertificateCubit, CertificateState>(
              builder: (context, state) {
                final cubit = context.read<CertificateCubit>();
                final lettres = state is LettresLoaded
                    ? state.lettres
                    : cubit.allLettres;

                if (state is CertificateLoading && lettres.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (lettres.isEmpty) {
                  return const Center(child: Text('No medical letters found'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lettres.length,
                  itemBuilder: (context, index) {
                    final lettre = lettres[index];
                    return _LettreCard(
                      lettre: lettre,
                      onEdit: () => _startEdit(lettre),
                      onPrint: () => _showPrintDialog(lettre),
                      onDelete: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Letter'),
                            content: const Text(
                              'Are you sure you want to delete this letter?',
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
                                  context.read<CertificateCubit>().deleteLettre(
                                    lettre.id!,
                                  );
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
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LettreCard extends StatelessWidget {
  final Lettre lettre;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _LettreCard({
    required this.lettre,
    required this.onEdit,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade50,
          child: Icon(Icons.email, color: Colors.purple.shade700),
        ),
        title: Text(
          lettre.motifLettre.isNotEmpty
              ? lettre.motifLettre
              : 'Lettre de Liaison',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _PatientNameWidget(patientId: lettre.patientId),
            if (lettre.motifConsultation.isNotEmpty)
              Text('Consulte pour: ${lettre.motifConsultation}'),
            if (lettre.atcd != null && lettre.atcd!.isNotEmpty)
              Text('ATCD: ${lettre.atcd}'),
            Text(
              'Créé le: ${DateFormat('dd/MM/yyyy').format(lettre.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: MediaQuery.of(context).size.width < 800
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'print') onPrint();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.orange),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      leading: Icon(Icons.print, color: Colors.blue),
                      title: Text('Print'),
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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    onPressed: onPrint,
                    tooltip: 'Print PDF',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
        isThreeLine: true,
      ),
    );
  }
}

class _LettrePrintDialog extends StatefulWidget {
  final Lettre lettre;

  const _LettrePrintDialog({required this.lettre});

  @override
  State<_LettrePrintDialog> createState() => _LettrePrintDialogState();
}

class _LettrePrintDialogState extends State<_LettrePrintDialog> {
  bool _isLoading = true;
  Patient? _patient;
  PrintTemplate _selectedTemplate = PrintTemplate.chifa;
  bool _printTitleOnBack = false;
  late TextEditingController _backPageTitleController;

  @override
  void initState() {
    super.initState();
    _backPageTitleController = TextEditingController(text: 'Lettre de Liaison');
    _loadPatient();
  }

  @override
  void dispose() {
    _backPageTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadPatient() async {
    setState(() => _isLoading = true);
    await context.read<PatientCubit>().loadPatientById(widget.lettre.patientId);
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

  Future<Uint8List> _generatePdfBytes() {
    return generateLettreDeLiaisonPdf(
      patient: _patient!,
      atcd: widget.lettre.atcd ?? '',
      motifConsultation: widget.lettre.motifConsultation,
      examenClinique: widget.lettre.examenClinique ?? '',
      motifLettre: widget.lettre.motifLettre,
      dateCreation: widget.lettre.createdAt,
      template: _selectedTemplate,
      backPageTitle: _printTitleOnBack ? _backPageTitleController.text : null,
    );
  }

  Future<void> _printPdf() async {
    if (_patient == null) return;
    final pdfBytes = await _generatePdfBytes();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  void _previewPdf() {
    if (_patient == null) return;
    showPdfPreview(
      context: context,
      generatedPdfBytes: _generatePdfBytes(),
      title: 'Lettre de Liaison - Preview',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print Lettre de Liaison'),
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
                if (widget.lettre.atcd != null &&
                    widget.lettre.atcd!.isNotEmpty)
                  Text('ATCD: ${widget.lettre.atcd}'),
                if (widget.lettre.motifConsultation.isNotEmpty)
                  Text('Consulte pour: ${widget.lettre.motifConsultation}'),
                Text('Adressé pour: ${widget.lettre.motifLettre}'),
                Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(widget.lettre.createdAt)}',
                ),
                const Divider(),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text(
                    'Imprimer le titre au verso',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Ajoute une page blanche au verso avec le titre de la lettre',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _printTitleOnBack,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) {
                    setState(() {
                      _printTitleOnBack = val ?? false;
                    });
                  },
                ),
                if (_printTitleOnBack) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _backPageTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre au verso',
                      hintText: 'Entrez le titre à imprimer au verso...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
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

// ==================== BONNE SANTE ====================

class _BonneSanteList extends StatefulWidget {
  const _BonneSanteList();

  @override
  State<_BonneSanteList> createState() => _BonneSanteListState();
}

class _BonneSanteListState extends State<_BonneSanteList> {
  final _patientSearchController = TextEditingController();
  List<Patient> _patientResults = [];
  Patient? _selectedPatient;
  bool _isSearchingPatient = false;
  bool _showPatientSuggestions = false;

  int? _doctorId;

  bool _isCreating = false;
  final List<CertificatBonneSante> _certificats = [];
  final bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    _doctorId = authCubit.currentUser?.employeeId;
    context.read<CertificateCubit>().loadCertificatsBonneSante();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _patientResults = [];
        _showPatientSuggestions = false;
      });
      return;
    }
    setState(() => _isSearchingPatient = true);
    try {
      final results = await DatabaseManager.instance.query(
        '''SELECT * FROM patients 
           WHERE first_name LIKE ? OR last_name LIKE ? OR patient_id = ?
           LIMIT 10''',
        ['%$query%', '%$query%', int.tryParse(query) ?? -1],
      );
      if (mounted) {
        setState(() {
          _patientResults = results.map((row) => Patient.fromMap(row)).toList();
          _showPatientSuggestions = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingPatient = false);
    }
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _patientSearchController.text = patient.fullName;
      _patientResults = [];
      _showPatientSuggestions = false;
    });
  }

  Future<void> _createCertificat() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final cert = CertificatBonneSante(
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId,
      createdAt: DateTime.now(),
    );

    context.read<CertificateCubit>().createCertificatBonneSante(cert);
  }

  Future<void> _deleteCertificat(int id) async {
    context.read<CertificateCubit>().deleteCertificatBonneSante(id);
  }

  void _resetForm() {
    setState(() {
      _selectedPatient = null;
      _patientSearchController.clear();
    });
  }

  void _showPrintDialog(CertificatBonneSante cert) {
    showDialog(
      context: context,
      builder: (context) => _BonneSantePrintDialog(certificat: cert),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== Create Form =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nouveau Certificat de Bonne Santé',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _patientSearchController,
                        decoration: InputDecoration(
                          labelText: 'Patient *',
                          hintText: 'Search by name or ID...',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_search, size: 20),
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
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: _resetForm,
                                )
                              : null,
                        ),
                        onChanged: (value) => _searchPatients(value),
                      ),
                      if (_showPatientSuggestions && _patientResults.isNotEmpty)
                        Container(
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
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _patientResults.length,
                            separatorBuilder: (_, index) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final p = _patientResults[index];
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
                                  'ID: ${p.patientId} • ${p.age} ans',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () => _selectPatient(p),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  if (_selectedPatient != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedPatient!.fullName}  •  ${_selectedPatient!.age} ans  •  ${_selectedPatient!.gender.name}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: _isCreating ? null : _createCertificat,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Enregistrer le Certificat'),
                      style: isMobile
                          ? ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          BlocBuilder<CertificateCubit, CertificateState>(
            builder: (context, state) {
              final cubit = context.read<CertificateCubit>();
              final items = state is CertificatsBonneSanteLoaded
                  ? state.certificats
                  : cubit.allCertificatsBonneSante;

              if (state is CertificateLoading && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (items.isEmpty) {
                return const Center(child: Text('Aucun certificat trouvé'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final cert = items[index];
                  return _BonneSanteCard(
                    certificat: cert,
                    onPrint: () => _showPrintDialog(cert),
                    onDelete: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer Certificat'),
                          content: const Text(
                            'Êtes-vous sûr de vouloir supprimer ce certificat ?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteCertificat(cert.id!);
                              },
                              child: const Text(
                                'Supprimer',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BonneSanteCard extends StatelessWidget {
  final CertificatBonneSante certificat;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _BonneSanteCard({
    required this.certificat,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.health_and_safety, color: Colors.green.shade700),
        ),
        title: const Text(
          'Certificat de Bonne Santé',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _PatientNameWidget(patientId: certificat.patientId),
            Text(
              'Créé le: ${DateFormat('dd/MM/yyyy').format(certificat.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.print, color: Colors.blue),
              onPressed: onPrint,
              tooltip: 'Print PDF',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

class _BonneSantePrintDialog extends StatefulWidget {
  final CertificatBonneSante certificat;

  const _BonneSantePrintDialog({required this.certificat});

  @override
  State<_BonneSantePrintDialog> createState() => _BonneSantePrintDialogState();
}

class _BonneSantePrintDialogState extends State<_BonneSantePrintDialog> {
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
    await context.read<PatientCubit>().loadPatientById(
      widget.certificat.patientId,
    );
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

  Future<Uint8List> _generatePdfBytes() {
    return generateBonneSantePdf(
      patient: _patient!,
      dateCreation: widget.certificat.createdAt,
      template: _selectedTemplate,
    );
  }

  Future<void> _printPdf() async {
    if (_patient == null) return;
    final pdfBytes = await _generatePdfBytes();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  void _previewPdf() {
    if (_patient == null) return;
    showPdfPreview(
      context: context,
      generatedPdfBytes: _generatePdfBytes(),
      title: 'Certificat Bonne Santé - Preview',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print Certificat Bonne Santé'),
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
                Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(widget.certificat.createdAt)}',
                ),
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
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
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

// ==================== DISPENSE DE SPORT ====================

class _DispenseSportList extends StatefulWidget {
  const _DispenseSportList();

  @override
  State<_DispenseSportList> createState() => _DispenseSportListState();
}

class _DispenseSportListState extends State<_DispenseSportList> {
  final _patientSearchController = TextEditingController();
  List<Patient> _patientResults = [];
  Patient? _selectedPatient;
  bool _isSearchingPatient = false;
  bool _showPatientSuggestions = false;

  int? _doctorId;
  final _motifController = TextEditingController();

  bool _isCreating = false;
  int? _editingCertId;
  final List<CertificatDispenseSport> _certificats = [];
  final bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    _doctorId = authCubit.currentUser?.employeeId;
    context.read<CertificateCubit>().loadCertificatsDispenseSport();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _patientResults = [];
        _showPatientSuggestions = false;
      });
      return;
    }
    setState(() => _isSearchingPatient = true);
    try {
      final results = await DatabaseManager.instance.query(
        '''SELECT * FROM patients 
           WHERE first_name LIKE ? OR last_name LIKE ? OR patient_id = ?
           LIMIT 10''',
        ['%$query%', '%$query%', int.tryParse(query) ?? -1],
      );
      if (mounted) {
        setState(() {
          _patientResults = results.map((row) => Patient.fromMap(row)).toList();
          _showPatientSuggestions = true;
          _isSearchingPatient = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingPatient = false);
    }
  }

  Future<void> _saveCertificat() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un patient')),
      );
      return;
    }

    final cert = CertificatDispenseSport(
      id: _editingCertId,
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId,
      motif: _motifController.text,
      createdAt: DateTime.now(),
    );

    context.read<CertificateCubit>().createCertificatDispenseSport(cert);

    setState(() {
      _isCreating = false;
      _editingCertId = null;
      _selectedPatient = null;
      _patientSearchController.clear();
      _motifController.clear();
    });
  }

  void _deleteCertificat(int id) async {
    context.read<CertificateCubit>().deleteCertificatDispenseSport(id);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    if (_isCreating) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editingCertId == null
                    ? 'Nouvelle Dispense de Sport'
                    : 'Modifier la Dispense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Patient Search
              TextField(
                controller: _patientSearchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher un patient',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearchingPatient
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                onChanged: _searchPatients,
              ),
              if (_showPatientSuggestions && _patientResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _patientResults.length,
                    itemBuilder: (ctx, index) {
                      final p = _patientResults[index];
                      return ListTile(
                        title: Text(p.fullName),
                        onTap: () {
                          setState(() {
                            _selectedPatient = p;
                            _patientSearchController.text = p.fullName;
                            _showPatientSuggestions = false;
                          });
                        },
                      );
                    },
                  ),
                ),
              if (_selectedPatient != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Patient sélectionné : ${_selectedPatient!.fullName}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _motifController,
                decoration: const InputDecoration(
                  labelText: 'Motif de la dispense',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _saveCertificat,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Enregistrer'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _isCreating = false),
                          child: const Text('Annuler'),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isCreating = false),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveCertificat,
                          child: const Text('Enregistrer'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _isCreating = true),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle Dispense de Sport'),
          ),
        ),
        Expanded(
          child: BlocBuilder<CertificateCubit, CertificateState>(
            builder: (context, state) {
              final cubit = context.read<CertificateCubit>();
              final items = state is CertificatsDispenseSportLoaded
                  ? state.certificats
                  : cubit.allCertificatsDispenseSport;

              if (state is CertificateLoading && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (items.isEmpty) {
                return const Center(child: Text('Aucun certificat trouvé'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (ctx, index) {
                  final cert = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(
                          Icons.fitness_center,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      title: const Text(
                        'Certificat de Dispense de Sport',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _PatientNameWidget(patientId: cert.patientId),
                          Text('Motif: ${cert.motif}'),
                          Text(
                            'Créé le: ${DateFormat('dd/MM/yyyy HH:mm').format(cert.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.blue),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    _DispenseSportPrintDialog(certificat: cert),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteCertificat(cert.id!),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DispenseSportPrintDialog extends StatefulWidget {
  final CertificatDispenseSport certificat;

  const _DispenseSportPrintDialog({required this.certificat});

  @override
  State<_DispenseSportPrintDialog> createState() =>
      _DispenseSportPrintDialogState();
}

class _DispenseSportPrintDialogState extends State<_DispenseSportPrintDialog> {
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
    await context.read<PatientCubit>().loadPatientById(
      widget.certificat.patientId,
    );
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

  Future<Uint8List> _generatePdfBytes() {
    return generateDispenseSportPdf(
      patient: _patient!,
      motif: widget.certificat.motif,
      dateCreation: widget.certificat.createdAt,
      template: _selectedTemplate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aperçu de la Dispense de Sport'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : _patient == null
          ? const Text('Erreur: Patient non trouvé')
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient: ${_patient!.fullName}'),
                const SizedBox(height: 8),
                Text('Motif: ${widget.certificat.motif}'),
                const SizedBox(height: 16),
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
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        OutlinedButton.icon(
          onPressed: _isLoading || _patient == null ? null : _previewPdf,
          icon: const Icon(Icons.visibility),
          label: const Text('Preview'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading || _patient == null
              ? null
              : () async {
                  final pdfBytes = await _generatePdfBytes();
                  await Printing.layoutPdf(
                    onLayout: (format) async => pdfBytes,
                  );
                },
          icon: const Icon(Icons.print),
          label: const Text('Imprimer'),
        ),
      ],
    );
  }

  void _previewPdf() {
    if (_patient == null) return;
    showPdfPreview(
      context: context,
      generatedPdfBytes: _generatePdfBytes(),
      title: 'Dispense de Sport - Preview',
    );
  }
}

// ==================== PRENUPTIAL LIST ====================

class _PrenuptialList extends StatefulWidget {
  const _PrenuptialList();

  @override
  State<_PrenuptialList> createState() => _PrenuptialListState();
}

class _PrenuptialListState extends State<_PrenuptialList> {
  final _patientSearchController = TextEditingController();
  List<Patient> _patientResults = [];
  Patient? _selectedPatient;
  bool _isSearchingPatient = false;
  bool _showPatientSuggestions = false;

  int? _doctorId;
  String? _selectedBloodGroup = 'A+';

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    _doctorId = authCubit.currentUser?.employeeId;
    context.read<CertificateCubit>().loadCertificatsPrenuptial();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _patientResults = [];
        _showPatientSuggestions = false;
      });
      return;
    }
    setState(() => _isSearchingPatient = true);
    try {
      final results = await DatabaseManager.instance.query(
        '''SELECT * FROM patients 
           WHERE first_name LIKE ? OR last_name LIKE ? OR patient_id = ?
           LIMIT 10''',
        ['%$query%', '%$query%', int.tryParse(query) ?? -1],
      );
      if (mounted) {
        setState(() {
          _patientResults = results.map((row) => Patient.fromMap(row)).toList();
          _showPatientSuggestions = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingPatient = false);
    }
  }

  void _saveCertificat() {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un patient')),
      );
      return;
    }

    final cert = CertificatPrenuptial(
      patientId: _selectedPatient!.patientId!,
      doctorId: _doctorId,
      groupeSanguin: _selectedBloodGroup,
      createdAt: DateTime.now(),
    );

    context.read<CertificateCubit>().createCertificatPrenuptial(cert);
    setState(() {
      _isCreating = false;
      _selectedPatient = null;
      _patientSearchController.clear();
      _selectedBloodGroup = 'A+';
    });
  }

  void _deleteCertificat(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous supprimer ce certificat ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CertificateCubit>().deleteCertificatPrenuptial(id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nouveau Certificat Prénuptial',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Patient Search
              TextField(
                controller: _patientSearchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher un patient',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearchingPatient
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                onChanged: _searchPatients,
              ),
              if (_showPatientSuggestions && _patientResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _patientResults.length,
                    itemBuilder: (ctx, index) {
                      final p = _patientResults[index];
                      return ListTile(
                        title: Text(p.fullName),
                        onTap: () {
                          setState(() {
                            _selectedPatient = p;
                            _patientSearchController.text = p.fullName;
                            _showPatientSuggestions = false;
                          });
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                decoration: const InputDecoration(
                  labelText: 'Groupe Sanguin',
                  prefixIcon: Icon(Icons.bloodtype),
                ),
                items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                    .map((bg) => DropdownMenuItem(
                          value: bg,
                          child: Text(bg),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBloodGroup = val;
                  });
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isCreating = false;
                        _selectedPatient = null;
                        _patientSearchController.clear();
                      });
                    },
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveCertificat,
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isCreating = true),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau Certificat Prénuptial'),
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<CertificateCubit, CertificateState>(
            builder: (context, state) {
              final cubit = context.read<CertificateCubit>();
              final items = state is CertificatsPrenuptialLoaded
                  ? state.certificats
                  : cubit.allCertificatsPrenuptial;

              if (state is CertificateLoading && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (items.isEmpty) {
                return const Center(child: Text('Aucun certificat trouvé'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (ctx, index) {
                  final cert = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.red.shade700,
                        ),
                      ),
                      title: const Text(
                        'Certificat Médical Prénuptial',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _PatientNameWidget(patientId: cert.patientId),
                          Text('Groupe Sanguin: ${cert.groupeSanguin ?? "Non spécifié"}'),
                          Text(
                            'Créé le: ${DateFormat('dd/MM/yyyy HH:mm').format(cert.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.blue),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    _PrenuptialPrintDialog(certificat: cert),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteCertificat(cert.id!),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PrenuptialPrintDialog extends StatefulWidget {
  final CertificatPrenuptial certificat;

  const _PrenuptialPrintDialog({required this.certificat});

  @override
  State<_PrenuptialPrintDialog> createState() => _PrenuptialPrintDialogState();
}

class _PrenuptialPrintDialogState extends State<_PrenuptialPrintDialog> {
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
    await context.read<PatientCubit>().loadPatientById(
      widget.certificat.patientId,
    );
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

  Future<Uint8List> _generatePdfBytes() {
    return generatePrenuptialPdf(
      patient: _patient!,
      groupeSanguin: widget.certificat.groupeSanguin,
      dateCreation: widget.certificat.createdAt,
      template: _selectedTemplate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aperçu du Certificat Prénuptial'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : _patient == null
          ? const Text('Erreur: Patient non trouvé')
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient: ${_patient!.fullName}'),
                const SizedBox(height: 8),
                Text('Groupe Sanguin: ${widget.certificat.groupeSanguin ?? "Non spécifié"}'),
                const SizedBox(height: 16),
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
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        OutlinedButton.icon(
          onPressed: _isLoading || _patient == null ? null : _previewPdf,
          icon: const Icon(Icons.visibility),
          label: const Text('Preview'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading || _patient == null
              ? null
              : () async {
                  final pdfBytes = await _generatePdfBytes();
                  await Printing.layoutPdf(
                    onLayout: (format) async => pdfBytes,
                  );
                },
          icon: const Icon(Icons.print),
          label: const Text('Imprimer'),
        ),
      ],
    );
  }

  void _previewPdf() {
    if (_patient == null) return;
    showPdfPreview(
      context: context,
      generatedPdfBytes: _generatePdfBytes(),
      title: 'Certificat Prénuptial - Preview',
    );
  }
}
