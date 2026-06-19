import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/soins_service_cubit.dart';
import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/printing/soins_medicaux.dart';
import 'package:chifa/services/db/database.dart';
import 'package:chifa/services/db/models/medical_record.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/soins_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Medical Record Form Dialog - Create new consultation record
class MedicalRecordFormDialog extends StatefulWidget {
  final String tabId;
  const MedicalRecordFormDialog({super.key, required this.tabId});

  @override
  State<MedicalRecordFormDialog> createState() =>
      _MedicalRecordFormDialogState();
}

class _MedicalRecordFormDialogState extends State<MedicalRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _doctorIdController = TextEditingController(
    text: '41',
  ); // Default doctor ID

  final _motifController = TextEditingController();
  final _detailsController = TextEditingController();
  final _diagnosticController = TextEditingController();
  final _prescriptionsController = TextEditingController();

  final _weightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _tensionController = TextEditingController();
  final _frequenceController = TextEditingController();
  final _spao2Controller = TextEditingController();
  final _timerController = TextEditingController(text: '00:00:00');
  final _soinsController = TextEditingController();
  final _soinsSearchController = TextEditingController();

  List<SoinsService> _filteredSoins = [];
  bool _showSoinsSuggestions = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    context.read<SoinsServiceCubit>().loadServices();

    final controllers = [
      _patientIdController,
      _doctorIdController,
      _motifController,
      _detailsController,
      _diagnosticController,
      _prescriptionsController,
      _weightController,
      _temperatureController,
      _tensionController,
      _frequenceController,
      _spao2Controller,
      _soinsController,
    ];
    for (var ctrl in controllers) {
      ctrl.addListener(_markAsDirty);
    }
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _doctorIdController.dispose();
    _motifController.dispose();
    _detailsController.dispose();
    _diagnosticController.dispose();
    _prescriptionsController.dispose();
    _weightController.dispose();
    _temperatureController.dispose();
    _tensionController.dispose();
    _frequenceController.dispose();
    _spao2Controller.dispose();
    _timerController.dispose();
    _soinsController.dispose();
    _soinsSearchController.dispose();
    super.dispose();
  }

  void _markAsDirty() {
    if (mounted) {
      context.read<WorkspaceCubit>().setTabDirty(widget.tabId, true);
    }
  }

  Future<void> _requestClose() async {
    if (_isLoading) return;
    final state = context.read<WorkspaceCubit>().state;
    final tabIndex = state.tabs.indexWhere((t) => t.id == widget.tabId);

    if (tabIndex != -1 && state.tabs[tabIndex].isDirty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Modifications non enregistrées'),
          content: const Text(
            'Êtes-vous sûr de vouloir fermer ? Vos modifications seront perdues.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Fermer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (mounted) context.read<WorkspaceCubit>().closeTab(widget.tabId);
  }

  // --- Soins Médicaux Methods ---

  void _filterSoins(String query, List<SoinsService> allSoins) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredSoins = allSoins;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredSoins = allSoins.where((s) {
          return s.nom.toLowerCase().contains(lowerQuery);
        }).toList();
      }
      _showSoinsSuggestions = true;
    });
  }

  // Creates a dummy patient for preview/printing since this dialog only uses IDs
  Patient _getDummyPatient() {
    return Patient.fromMap({
      'id': int.tryParse(_patientIdController.text) ?? 0,
      'first_name': 'Patient',
      'last_name': _patientIdController.text.isNotEmpty
          ? 'ID: ${_patientIdController.text}'
          : 'Inconnu',
      'date_of_birth': DateTime.now().toIso8601String(),
      'gender': 'Unknown',
      'phone': '',
      'atcd': '',
    });
  }

  void _previewSoinsPdf() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aperçu: Soins Médicaux'),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,

          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: PdfPreview(
            build: (format) => generateSoinsMedicauxPdf(
              patient: _getDummyPatient(),
              weight: _weightController.text.trim().isNotEmpty
                  ? _weightController.text.trim()
                  : null,
              soinsText: _soinsController.text,
            ),
            allowPrinting: true,
            allowSharing: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _printSoins() async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => generateSoinsMedicauxPdf(
        patient: _getDummyPatient(),
        weight: _weightController.text.trim().isNotEmpty
            ? _weightController.text.trim()
            : null,
        soinsText: _soinsController.text,
      ),
    );
  }

  void _saveSoins([int? recordId]) async {
    if (_soinsController.text.isEmpty) {
      if (recordId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez ajouter des soins avant de sauvegarder.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (recordId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les soins seront sauvegardés automatiquement lors de la création du dossier médical.',
          ),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    try {
      await DatabaseService().query(
        'INSERT INTO soins_medicaux (patient_id, doctor_id, medicalrecord_id, soins, created_at) VALUES (?, ?, ?, ?, NOW())',
        [
          int.tryParse(_patientIdController.text) ?? 0,
          int.tryParse(_doctorIdController.text) ?? 0,
          recordId,
          _soinsController.text,
        ],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_doctorIdController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Doctor ID is required')));
      return;
    }

    setState(() => _isLoading = true);

    final record = MedicalRecord(
      patientId: int.parse(_patientIdController.text),
      doctorId: int.parse(_doctorIdController.text),
      motif: _motifController.text.isEmpty ? null : _motifController.text,
      details: _detailsController.text,
      diagnostic: _diagnosticController.text.isEmpty
          ? null
          : _diagnosticController.text,
      prescriptions: _prescriptionsController.text.isEmpty
          ? null
          : _prescriptionsController.text,
      weight: _weightController.text.isEmpty
          ? null
          : double.tryParse(_weightController.text),
      temperature: _temperatureController.text.isEmpty
          ? null
          : double.tryParse(_temperatureController.text),
      tensionArterielle: _tensionController.text.isEmpty
          ? null
          : _tensionController.text,
      frequenceCardiaque: _frequenceController.text.isEmpty
          ? null
          : int.tryParse(_frequenceController.text),
      spao2: _spao2Controller.text.isEmpty
          ? null
          : int.tryParse(_spao2Controller.text),
      recordTimer: _timerController.text,
    );

    context.read<MedicalRecordCubit>().createMedicalRecord(record);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MedicalRecordCubit, MedicalRecordState>(
      listener: (context, state) {
        // Guard against state pollution from other tabs/dialogs
        if (!_isLoading) return;

        if (!state.isLoading) {
          setState(() => _isLoading = false);
        }

        if (state.successMessage != null) {
          if (_soinsController.text.isNotEmpty && state.lastCreatedId != null) {
            _saveSoins(state.lastCreatedId);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
          context.read<MedicalRecordCubit>().clearSuccessMessage();
          if (context.mounted) {
            context.read<WorkspaceCubit>().closeTab(widget.tabId);
          }
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
          context.read<MedicalRecordCubit>().clearError();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Medical Record',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _requestClose,
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? double.infinity
                                  : (MediaQuery.of(context).size.width - 100) /
                                        2,
                              child: TextFormField(
                                controller: _patientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Patient ID *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Must be a valid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? double.infinity
                                  : (MediaQuery.of(context).size.width - 100) /
                                        2,
                              child: TextFormField(
                                controller: _doctorIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Doctor ID *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medical_services),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Must be a valid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _motifController,
                          decoration: const InputDecoration(
                            labelText: 'Motif de Consultation',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.question_mark),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _detailsController,
                          decoration: const InputDecoration(
                            labelText: 'Détails de Consultation *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes),
                          ),
                          maxLines: 4,
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Détails is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? double.infinity
                                  : (MediaQuery.of(context).size.width - 100) /
                                        3,
                              child: TextFormField(
                                controller: _weightController,
                                decoration: const InputDecoration(
                                  labelText: 'Poids (kg)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.scale),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? (MediaQuery.of(context).size.width - 40) / 2
                                  : (MediaQuery.of(context).size.width - 100) /
                                        3,
                              child: TextFormField(
                                controller: _temperatureController,
                                decoration: const InputDecoration(
                                  labelText: 'Température (°C)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.thermostat),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? (MediaQuery.of(context).size.width - 40) / 2
                                  : (MediaQuery.of(context).size.width - 100) /
                                        3,
                              child: TextFormField(
                                controller: _tensionController,
                                decoration: const InputDecoration(
                                  labelText: 'Tension Artérielle',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.favorite),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? (MediaQuery.of(context).size.width - 40) / 2
                                  : (MediaQuery.of(context).size.width - 80) /
                                        2,
                              child: TextFormField(
                                controller: _frequenceController,
                                decoration: const InputDecoration(
                                  labelText: 'Fréq. Cardiaque (bpm)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.monitor_heart),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? (MediaQuery.of(context).size.width - 40) / 2
                                  : (MediaQuery.of(context).size.width - 80) /
                                        2,
                              child: TextFormField(
                                controller: _spao2Controller,
                                decoration: const InputDecoration(
                                  labelText: 'SpO2 (%)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.air),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _diagnosticController,
                          decoration: const InputDecoration(
                            labelText: 'Diagnostic',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.health_and_safety),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _prescriptionsController,
                          decoration: const InputDecoration(
                            labelText: 'Prescriptions',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_pharmacy),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text(
                          'Soins Médicaux',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        BlocBuilder<SoinsServiceCubit, SoinsServiceState>(
                          builder: (context, state) {
                            final allSoins = state.services;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _soinsSearchController,
                                  decoration: InputDecoration(
                                    labelText: 'Rechercher un soin / service',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                    ),
                                    suffixIcon:
                                        _soinsSearchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 16,
                                            ),
                                            onPressed: () {
                                              _soinsSearchController.clear();
                                              setState(() {
                                                _showSoinsSuggestions = false;
                                                _filteredSoins = [];
                                              });
                                            },
                                          )
                                        : null,
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (value) =>
                                      _filterSoins(value, allSoins),
                                  onTap: () {
                                    if (_soinsSearchController.text.isEmpty) {
                                      _filterSoins('', allSoins);
                                    }
                                  },
                                ),
                                if (_showSoinsSuggestions &&
                                    _filteredSoins.isNotEmpty)
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    margin: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _filteredSoins.length,
                                      itemBuilder: (context, index) {
                                        final soin = _filteredSoins[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            soin.nom,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          trailing: const Icon(
                                            Icons.add_circle_outline,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          onTap: () {
                                            setState(() {
                                              final currentText =
                                                  _soinsController.text;
                                              final newText = '- ${soin.nom}';
                                              _soinsController.text =
                                                  currentText.isEmpty
                                                  ? newText
                                                  : '$currentText\n$newText';
                                              _soinsSearchController.clear();
                                              _showSoinsSuggestions = false;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _soinsController,
                          decoration: const InputDecoration(
                            labelText: 'Services / Soins Administrés',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.medical_information),
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _previewSoinsPdf,
                              icon: const Icon(Icons.preview),
                              label: const Text('Aperçu PDF'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _printSoins,
                              icon: const Icon(Icons.print),
                              label: const Text('Imprimer'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _saveSoins,
                              icon: const Icon(Icons.save),
                              label: const Text('Sauvegarder Soins'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _requestClose,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Record'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
