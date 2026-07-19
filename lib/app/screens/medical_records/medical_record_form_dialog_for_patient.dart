import 'dart:async';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:chifa/app/cubits/appointment_cubit.dart';
import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/bilan_cubit.dart';
import 'package:chifa/app/cubits/billing_cubit.dart';
import 'package:chifa/app/cubits/certificate_cubit.dart';
import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/cubits/prescription_cubit.dart';
import 'package:chifa/app/cubits/soins_service_cubit.dart';
import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/printing/arret_de_travail.dart';
import 'package:chifa/app/printing/bilan.dart';
import 'package:chifa/app/printing/certificat_bonne_sante.dart';
import 'package:chifa/app/printing/dispense_sport.dart';
import 'package:chifa/app/printing/lettre_de_liaison.dart';
import 'package:chifa/app/printing/maladie_chronique.dart';
import 'package:chifa/app/printing/certificat_prenuptial.dart';
import 'package:chifa/app/printing/profil_glycemique.dart';
import 'package:chifa/app/printing/profil_ta.dart';
import 'package:chifa/app/printing/ordonnance.dart';
import 'package:chifa/app/printing/preview.dart';
import 'package:chifa/app/printing/soins_medicaux.dart';
import 'package:chifa/services/db/database.dart';
import 'package:chifa/services/db/models/appointment.dart';
import 'package:chifa/services/db/models/arret_de_travail.dart';
import 'package:chifa/services/db/models/bilan.dart';
import 'package:chifa/services/db/models/bilan_type.dart';
import 'package:chifa/services/db/models/lettre.dart';
import 'package:chifa/services/db/models/medical_record.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/payment.dart';
import 'package:chifa/services/db/models/payment_service.dart';
import 'package:chifa/services/db/models/prescription.dart';
import 'package:chifa/services/db/models/prescription_type.dart';
import 'package:chifa/services/db/models/print_template.dart';
import 'package:chifa/services/db/models/service.dart';
import 'package:chifa/services/db/models/soins_service.dart';
import 'package:chifa/app/screens/medical_records/widgets/patient_history_panel.dart';
import 'package:chifa/services/db/repositories/payment_repository.dart';
import 'package:chifa/services/db/repositories/patient_repository.dart';
import 'package:chifa/services/formatters/formatters.dart';
import 'package:chifa/services/posology/posology_scraper_service.dart';
import 'package:chifa/app/widgets/pathology_search_dialog.dart';
import 'package:chifa/services/cnas/cnas_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

Timer? _debounceTimer;

/// Medical Record Form Dialog pre-filled with a specific patient's data
class MedicalRecordFormDialogForPatient extends StatefulWidget {
  final Patient patient;
  final MedicalRecord? recordToEdit;
  final String tabId;

  const MedicalRecordFormDialogForPatient({
    super.key,
    required this.patient,
    this.recordToEdit,
    required this.tabId,
  });

  @override
  State<MedicalRecordFormDialogForPatient> createState() =>
      _MedicalRecordFormDialogForPatientState();
}

class _MedicalRecordFormDialogForPatientState
    extends State<MedicalRecordFormDialogForPatient> {
  late Patient _currentPatient;
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  PrintTemplate _selectedTemplate = PrintTemplate.chifa;
  bool _includeDateInOrdonnance = true;
  final _motifController = TextEditingController();
  final _detailsController = TextEditingController();
  late quill.QuillController _detailsQuillController;
  final _diagnosticController = TextEditingController();
  final _prescriptionsFieldController = TextEditingController();
  final _doctorController = TextEditingController();
  String? _doctorId;
  final _weightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _tensionController = TextEditingController();
  final _frequenceController = TextEditingController();
  final _spao2Controller = TextEditingController();
  final _timerController = TextEditingController(text: '00:00:00');
  final _paymentNoteController = TextEditingController();
  final _serviceSearchController = TextEditingController();

  // Payment Services
  final List<Service> _selectedServices = [];
  List<Service> _filteredServices = [];
  bool _showServiceSuggestions = false;
  double _totalPaymentAmount = 0.0;
  double _totalDoctorCommission = 0.0;

  bool _isProcessingPayment = false;
  String _paymentMethod = 'Cash';

  // Template Search for prescriptions
  final _searchController = TextEditingController();

  // Advanced Medicament Search Row
  final _medicSearchController = TextEditingController();
  final _posologyController = TextEditingController();
  final _durationController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isScrapingPosology = false;
  Map<String, dynamic>? _selectedMedic;

  // Soins Medicaux Search
  final _soinsController = TextEditingController();
  final _soinsSearchController = TextEditingController();
  List<SoinsService> _filteredSoins = [];
  bool _showSoinsSuggestions = false;

  bool _isLoading = false;
  DateTime _prescriptionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentPatient = widget.patient;
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;
    _doctorController.text = user?.fullName ?? '';
    _doctorId = user?.employeeId.toString();
    context.read<PrescriptionCubit>().loadCommonPrescriptions();
    context.read<PrescriptionCubit>().loadPrescriptionTypes();
    context.read<BillingCubit>().loadServices();
    context.read<SoinsServiceCubit>().loadServices();

    if (widget.recordToEdit != null) {
      _motifController.text = widget.recordToEdit!.motif ?? '';
      _detailsController.text = widget.recordToEdit!.details;
      _diagnosticController.text = widget.recordToEdit!.diagnostic ?? '';
      _prescriptionsFieldController.text =
          widget.recordToEdit!.prescriptions ?? '';
      _prescriptionDate = widget.recordToEdit!.recordDate;
      _weightController.text = widget.recordToEdit!.weight?.toString() ?? '';
      _temperatureController.text =
          widget.recordToEdit!.temperature?.toString() ?? '';
      _tensionController.text = widget.recordToEdit!.tensionArterielle ?? '';
      _frequenceController.text =
          widget.recordToEdit!.frequenceCardiaque?.toString() ?? '';
      _spao2Controller.text = widget.recordToEdit!.spao2?.toString() ?? '';
      _soinsController.text = widget.recordToEdit!.soins ?? '';
      _timerController.text = widget.recordToEdit!.recordTimer;
      if (widget.recordToEdit!.doctorId != 0) {
        _doctorId = widget.recordToEdit!.doctorId.toString();
      }
      _loadServicesForRecord(widget.recordToEdit!.id!);
    }

    final initialDetails = widget.recordToEdit != null ? widget.recordToEdit!.details : '';
    quill.Document detailsDoc;
    final trimmedDetails = initialDetails.trim();
    if ((trimmedDetails.startsWith('[') && trimmedDetails.endsWith(']')) || 
        (trimmedDetails.startsWith('{') && trimmedDetails.endsWith('}'))) {
      try {
        final decoded = jsonDecode(trimmedDetails);
        final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);
        detailsDoc = quill.Document.fromJson(ops);
      } catch (_) {
        detailsDoc = quill.Document()..insert(0, initialDetails);
      }
    } else {
      detailsDoc = quill.Document()..insert(0, initialDetails);
    }
    _detailsQuillController = quill.QuillController(
      document: detailsDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _detailsQuillController.addListener(_markAsDirty);

    // Add listeners to mark the form as dirty when typing
    final controllers = [
      _motifController,
      _diagnosticController,
      _prescriptionsFieldController,
      _weightController,
      _temperatureController,
      _tensionController,
      _frequenceController,
      _spao2Controller,
      _soinsController,
      _paymentNoteController,
    ];
    for (var ctrl in controllers) {
      ctrl.addListener(_markAsDirty);
    }
    _weightController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadServicesForRecord(int recordId) async {
    try {
      final repo = PaymentRepository();
      
      final payResult = await repo.getByRecordId(recordId);
      payResult.fold((_) {}, (payment) {
        if (payment != null && mounted) {
          setState(() {
            _paymentMethod = payment.paymentMethod ?? 'Cash';
            _paymentNoteController.text = payment.notes ?? '';
          });
        }
      });

      final result = await repo.getServicesByRecordId(recordId);
      result.fold((_) {}, (paymentServices) {
        if (!mounted) return;
        final services = paymentServices
            .map(
              (ps) => Service(
                serviceId: ps.serviceId,
                serviceName: ps.serviceName,
                price: ps.servicePrice,
                doctorCommission: ps.doctorCommission,
              ),
            )
            .toList();
        setState(() {
          _selectedServices.clear();
          _selectedServices.addAll(services);
          _totalPaymentAmount = _selectedServices.fold(
            0.0,
            (sum, s) => sum + s.price,
          );
          _totalDoctorCommission = _selectedServices.fold(
            0.0,
            (sum, s) => sum + s.doctorCommission,
          );
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _motifController.dispose();
    _detailsController.dispose();
    _detailsQuillController.dispose();
    _diagnosticController.dispose();
    _prescriptionsFieldController.dispose();
    _doctorController.dispose();

    _weightController.dispose();
    _temperatureController.dispose();
    _tensionController.dispose();
    _frequenceController.dispose();
    _spao2Controller.dispose();
    _timerController.dispose();
    _searchController.dispose();
    _medicSearchController.dispose();
    _posologyController.dispose();
    _durationController.dispose();
    _paymentNoteController.dispose();
    _serviceSearchController.dispose();
    _soinsController.dispose();
    _soinsSearchController.dispose();
    super.dispose();
  }

  void _markAsDirty() {
    if (mounted) {
      context.read<WorkspaceCubit>().setTabDirty(widget.tabId, true);
    }
  }

  String? _validateWeight(String? value) {
    if (value == null || value.isEmpty) return null;
    final weight = double.tryParse(value);
    if (weight == null || weight <= 0 || weight > 500) {
      return 'Entrez un poids valide (1-500 kg)';
    }
    return null;
  }

  String? _validateTemperature(String? value) {
    if (value == null || value.isEmpty) return null;
    final temp = double.tryParse(value);
    if (temp == null || temp < 30 || temp > 45) {
      return 'Entrez une température valide (30-45°C)';
    }
    return null;
  }

  String? _validateHeartRate(String? value) {
    if (value == null || value.isEmpty) return null;
    final rate = int.tryParse(value);
    if (rate == null || rate < 20 || rate > 250) {
      return 'Entrez une fréquence valide (20-250)';
    }
    return null;
  }

  String? _validateSpO2(String? value) {
    if (value == null || value.isEmpty) return null;
    final spO2 = int.tryParse(value);
    if (spO2 == null || spO2 < 50 || spO2 > 100) {
      return 'Entrez une SpO2 valide (50-100%)';
    }
    return null;
  }

  String? _validateTension(String? value) {
    if (value == null || value.isEmpty) return null;
    final pattern = RegExp(r'^\d{2,3}/\d{2,3}$');
    if (!pattern.hasMatch(value)) {
      return 'Format: sys/dia (ex: 120/80)';
    }
    return null;
  }

  Widget _buildTemplateSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _includeDateInOrdonnance
              ? 'Date affichée — cliquer pour masquer'
              : 'Date masquée — cliquer pour afficher',
          child: Material(
            color: _includeDateInOrdonnance
                ? Colors.blue.shade700.withValues(alpha: 0.12)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _includeDateInOrdonnance = !_includeDateInOrdonnance),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _includeDateInOrdonnance
                          ? Icons.calendar_today
                          : Icons.calendar_today_outlined,
                      size: 14,
                      color: _includeDateInOrdonnance
                          ? Colors.blue.shade700
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _includeDateInOrdonnance ? 'Date ON' : 'Date OFF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _includeDateInOrdonnance
                            ? Colors.blue.shade700
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
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

  Future<void> _searchMedicament(String query) async {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      try {
        final results = await DatabaseService().query(
          '''SELECT id, name, dci, indication, manufacturer, category, formulation, origin, dosage, conditionnement, liste, posologie, posologie_adulte, posologie_pediatrique 
           FROM medalgeriemedics 
           WHERE name LIKE ? 
              OR dci LIKE ? 
              OR indication LIKE ? 
              OR manufacturer LIKE ? 
              OR category LIKE ? 
              OR formulation LIKE ? 
              OR origin LIKE ? 
              OR dosage LIKE ? 
              OR conditionnement LIKE ? 
              OR liste LIKE ? 
           LIMIT 20''',
          [
            '%$query%',
            '%$query%',
            '%$query%',
            '%$query%',
            '%$query%',
            '%$query%',
            '%$query%',
            '%$query%',
            '%$query%',
            '%$query%',
          ],
        );
        setState(() => _searchResults = results);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Search error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _selectMedicament(Map<String, dynamic> medic) async {
    final rawName = medic['name'] ?? '';
    final name = rawName.replaceAll(',', '.');
    final dosage = medic['dosage'] ?? '';
    final formulation = medic['formulation'] ?? '';
    
    final formattedForm = Formatters.formatMedicForm(formulation.toString());
    final parts = [
      name,
      if (dosage.toString().isNotEmpty) dosage,
      if (formattedForm.isNotEmpty) formattedForm,
    ];
    final selectedText = parts.where((p) => p.toString().isNotEmpty).join(' ');

    setState(() {
      _selectedMedic = {...medic, 'name': name};
      _searchResults = [];
      _medicSearchController.text = selectedText;
    });

    final hasAdulte = medic['posologie_adulte'] != null && medic['posologie_adulte'].toString().trim().isNotEmpty;
    final hasPediatrique = medic['posologie_pediatrique'] != null && medic['posologie_pediatrique'].toString().trim().isNotEmpty;

    if (!hasAdulte && !hasPediatrique) {
      setState(() {
        _isScrapingPosology = true;
      });
      try {
        final result = await PosologyScraperService.instance.scrapePosology(medic['id'].toString());
        if (result != null && result['status'] == 'success') {
          setState(() {
            _selectedMedic = {
              ..._selectedMedic!,
              'posologie_adulte': result['posologie_adulte'],
              'posologie_pediatrique': result['posologie_pediatrique'],
              'posologie': result['posologie'],
            };
          });
        }
      } catch (e) {
        debugPrint('Error scraping posology: $e');
      } finally {
        setState(() {
          _isScrapingPosology = false;
        });
      }
    }
  }

  Future<void> _addNewMedicament() async {
    final nameController = TextEditingController(
      text: _medicSearchController.text,
    );
    final dciController = TextEditingController();
    final formulationController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ajouter un nouveau médicament'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de marque *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dciController,
                  decoration: const InputDecoration(
                    labelText: 'DCI (Molécule)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: formulationController,
                  decoration: const InputDecoration(
                    labelText: 'Formulation (ex: comp, sirop...)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le nom du médicament est requis.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final newId = await DatabaseService().insert(
                    'INSERT INTO medalgeriemedics (name, dci, formulation, needs_sync, source_id) VALUES (?, ?, ?, 1, NULL)',
                    [
                      nameController.text.trim(),
                      dciController.text.trim(),
                      formulationController.text.trim(),
                    ],
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Médicament ajouté avec succès.'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Select the newly added medicament automatically
                    _selectMedicament({
                      'id': newId,
                      'name': nameController.text.trim().replaceAll(',', '.'),
                      'dci': dciController.text.trim(),
                      'formulation': formulationController.text.trim(),
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              label: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _addMedicToTextArea() async {
    if (_selectedMedic == null) {
      return; // Must have a selected medicament to add.
    }

    final buffer = Formatters.formatMedicament(
      _selectedMedic!,
      _posologyController.text.trim(),
      _durationController.text.trim(),
    );
    final prescriptionText = buffer.toString();

    // Check if this exact prescription already exists in modern_prescriptions table
    // Use TRIM and LOWER for robust duplicate detection
    try {
      final existingPrescriptions = await DatabaseService().query(
        'SELECT id FROM modern_prescriptions WHERE TRIM(LOWER(prescription)) = TRIM(LOWER(?)) AND is_deleted = 0',
        [prescriptionText],
      );

      if (!mounted) return;

      if (existingPrescriptions.isEmpty) {
        // Prescription doesn't exist, add it to modern_prescriptions
        final newPrescription = Prescription(prescription: prescriptionText);

        // createPrescription now internally awaits loadCommonPrescriptions()
        // so the search template list will be refreshed automatically
        await context.read<PrescriptionCubit>().createPrescription(
          newPrescription,
        );

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nouvelle prescription ajoutée aux modèles'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la vérification de la prescription: $e',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Also check if the exact same line is already in the current text field to avoid visual duplicates
    final currentLines = _prescriptionsFieldController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();

    if (!currentLines.contains(prescriptionText.trim())) {
      setState(() {
        if (_prescriptionsFieldController.text.isNotEmpty &&
            !_prescriptionsFieldController.text.endsWith('\n\n')) {
          _prescriptionsFieldController.text += '\n';
        }
        _prescriptionsFieldController.text += prescriptionText;

        _selectedMedic = null;
        _medicSearchController.clear();
        _posologyController.clear();
        _durationController.clear();
      });
    } else {
      // Clear inputs anyway since it's already in the field
      setState(() {
        _selectedMedic = null;
        _medicSearchController.clear();
        _posologyController.clear();
        _durationController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déjà ajouté à l\'ordonnance'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _savePrescriptionAsModel() async {
    if (_prescriptionsFieldController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez entrer une ordonnance avant de la sauvegarder comme modèle.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final titleController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sauvegarder comme modèle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre du modèle *',
                  hintText: 'Ex: Antibiotique standard, Douleur, etc.',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le titre est requis.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  await DatabaseService().insert(
                    'INSERT INTO ordonnance_type (prescription, title, needs_sync, source_id) VALUES (?, ?, 1, NULL)',
                    [
                      _prescriptionsFieldController.text.trim(),
                      titleController.text.trim(),
                    ],
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Modèle sauvegardé avec succès!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Refresh the prescription types dropdown
                    context.read<PrescriptionCubit>().loadPrescriptionTypes();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              label: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    context.read<PrescriptionCubit>().searchPrescriptions(query);
  }

  void _insertTemplate(Prescription template) {
    _prescriptionsFieldController.text += '\n${template.prescription}';
  }

  Future<void> _printOrdonnance() async {
    if (_prescriptionsFieldController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No prescription entered.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final weight = _weightController.text.trim().isNotEmpty
          ? _weightController.text.trim()
          : null;
      final pdfBytes = await generateOrdonnancePdf(
        patient: _currentPatient,
        weight: weight,
        prescriptionText: _prescriptionsFieldController.text,
        template: _selectedTemplate,
        includeDate: _includeDateInOrdonnance,
        date: _prescriptionDate,
      );
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name:
            'ordonnance_${_currentPatient.fullName}_${dateStr.replaceAll('/', '-')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printBlankOrdonnance() async {
    try {
      final pdfBytes = await generateEmptyOrdonnancePdf(
        template: _selectedTemplate,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'ordonnance_vierge.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _previewSoinsPdf() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aperçu: Soins Médicaux'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: PdfPreview(
            build: (format) => generateSoinsMedicauxPdf(
              patient: _currentPatient,
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
        patient: _currentPatient,
        weight: _weightController.text.trim().isNotEmpty
            ? _weightController.text.trim()
            : null,
        soinsText: _soinsController.text,
        template: _selectedTemplate,
      ),
    );
  }

  Future<void> _saveSoins([int? recordId]) async {
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

    final mId = recordId ?? widget.recordToEdit?.id;
    if (mId == null) {
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
          _currentPatient.patientId,
          int.tryParse(_doctorId ?? '') ?? 0,
          mId,
          _soinsController.text,
        ],
      );
      if (mounted && recordId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Soins sauvegardés avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditPatientDialog() {
    final firstNameController = TextEditingController(text: _currentPatient.firstName);
    final lastNameController = TextEditingController(text: _currentPatient.lastName);
    final ageController = TextEditingController(text: _currentPatient.age.toString());
    final editFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_note, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text('Personnaliser le nom/âge (impression)'),
            ],
          ),
          content: Form(
            key: editFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Le prénom est requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Le nom est requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ageController,
                  decoration: const InputDecoration(
                    labelText: 'Âge (ans) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'L\'âge est requis';
                    }
                    final parsed = int.tryParse(val);
                    if (parsed == null || parsed < 0 || parsed > 130) {
                      return 'Veuillez entrer un âge valide (0-130)';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              onPressed: () {
                if (!editFormKey.currentState!.validate()) return;

                final editedFirstName = firstNameController.text.trim();
                final editedLastName = lastNameController.text.trim();
                final editedAge = int.parse(ageController.text.trim());
                
                final birthYear = DateTime.now().year - editedAge;
                final editedDob = DateTime(
                  birthYear,
                  _currentPatient.dateOfBirth.month,
                  _currentPatient.dateOfBirth.day,
                );

                final updatedPatient = _currentPatient.copyWith(
                  firstName: editedFirstName,
                  lastName: editedLastName,
                  dateOfBirth: editedDob,
                );

                setState(() {
                  _currentPatient = updatedPatient;
                });
                Navigator.pop(ctx);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informations du patient personnalisées pour cette session d\'impression.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              label: const Text('Appliquer'),
            ),
          ],
        );
      },
    );
  }

  void _showAppointmentDialog() {
    DateTime selectedDate = DateTime.now();
    TimeOfDay? selectedTime;
    final notesCtrl = TextEditingController();
    AppointmentStatus selectedStatus = AppointmentStatus.scheduled;
    final dateFormat = DateFormat('dd/MM/yyyy');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Planifier un rendez-vous'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Patient: ${_currentPatient.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setState(() => selectedDate = d);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date du rendez-vous',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        child: Text(dateFormat.format(selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) {
                          setState(() => selectedTime = t);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Heure du rendez-vous',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time, size: 20),
                        ),
                        child: Text(
                          selectedTime != null
                              ? selectedTime!.format(context)
                              : 'Sélectionner une heure',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AppointmentStatus>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Statut',
                        border: OutlineInputBorder(),
                      ),
                      items: AppointmentStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedStatus = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez sélectionner une heure'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final appointmentDate = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    final doctorId = int.tryParse(_doctorId ?? '0') ?? 0;
                    final appointment = Appointment(
                      patientId: _currentPatient.patientId!,
                      doctorId: doctorId,
                      appointmentDate: appointmentDate,
                      status: selectedStatus,
                      notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                    );
                    context.read<AppointmentCubit>().createAppointment(appointment);
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rendez-vous créé avec succès'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Créer le rendez-vous'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showArretDeTravailDialog() {
    String selectedType = 'ARRET DE TRAVAIL';
    final motifCtrl = TextEditingController();
    final joursCtrl = TextEditingController(text: '1');
    DateTime dateDebut = DateTime.now();
    DateTime dateReprise = DateTime.now().add(const Duration(days: 1));
    DateTime dateCertificat = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void recalculateReprise() {
              final j = int.tryParse(joursCtrl.text) ?? 0;
              setState(() {
                dateReprise = dateDebut.add(Duration(days: j));
              });
            }

            return AlertDialog(
              title: const Text('Créer un Arrêt de Travail'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type de document',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const [
                                'ARRET DE TRAVAIL',
                                "PROLONGATION D'ARRET",
                                'REPRISE DE TRAVAIL',
                              ]
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedType = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: motifCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Motif Médical',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: joursCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Jours',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => recalculateReprise(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: dateDebut,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) {
                                setState(() => dateDebut = d);
                                recalculateReprise();
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date début',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dateFormat.format(dateDebut)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectedType == 'ARRET DE TRAVAIL' ||
                        selectedType == "PROLONGATION D'ARRET") ...[
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de reprise (calculée)',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue.shade700),
                          ),
                          prefixIcon: Icon(
                            Icons.event_available,
                            size: 20,
                            color: Colors.blue.shade700,
                          ),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                        child: Text(
                          dateFormat.format(dateReprise),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: dateCertificat,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setState(() => dateCertificat = d);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date du certificat',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        child: Text(dateFormat.format(dateCertificat)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    final j = int.tryParse(joursCtrl.text) ?? 1;
                    final pdfFuture = generateArretDeTravailPdf(
                      patient: _currentPatient,
                      arretType: selectedType,
                      motif: motifCtrl.text,
                      dateDebut: dateDebut,
                      dateReprise: dateReprise,
                      jours: j,
                      dateCreation: dateCertificat,
                      template: _selectedTemplate,
                    );
                    if (!mounted) return;
                    showPdfPreview(
                      context: context,
                      generatedPdfBytes: pdfFuture,
                    );
                  },
                  label: const Text('Preview'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  onPressed: () {
                    final j = int.tryParse(joursCtrl.text) ?? 1;
                    final arret = ArretDeTravail(
                      patientId: _currentPatient.patientId!,
                      doctorId: int.tryParse(_doctorId ?? '') ?? 0,
                      type: selectedType,
                      motif: motifCtrl.text,
                      dateDebut: dateDebut,
                      jours: j,
                      dateReprise: dateReprise,
                      dateCreation: dateCertificat,
                    );
                    context.read<CertificateCubit>().createArretDeTravail(
                      arret,
                    );

                    final pdfFuture = generateArretDeTravailPdf(
                      patient: _currentPatient,
                      arretType: selectedType,
                      motif: motifCtrl.text,
                      dateDebut: dateDebut,
                      dateReprise: dateReprise,
                      jours: j,
                      dateCreation: dateCertificat,
                      template: _selectedTemplate,
                    );

                    Navigator.pop(ctx);
                    if (!mounted) return;
                    showPdfPreview(
                      context: context,
                      generatedPdfBytes: pdfFuture,
                    );
                  },
                  label: const Text('Save & Print'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBilanDialog() {
    final bilanCtrl = TextEditingController();
    context.read<BilanCubit>().loadBilanTypes();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nouvelle Demande d\'Analyses (Bilan)'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BlocBuilder<BilanCubit, BilanState>(
                      builder: (context, state) {
                        List<BilanType> types = [];
                        if (state is BilanTypesLoaded) {
                          types = state.types;
                        }

                        return DropdownButtonFormField<BilanType>(
                          decoration: const InputDecoration(
                            labelText: 'Sélectionner un type de bilan',
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
                              setDialogState(() {
                                if (bilanCtrl.text.isNotEmpty) {
                                  bilanCtrl.text += '\n${val.bilans}';
                                } else {
                                  bilanCtrl.text = val.bilans;
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bilanCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Analyses demandées *',
                        hintText: 'FNS, Glycémie, Urée, Créatinine, ...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    if (bilanCtrl.text.isEmpty) return;
                    final pdfFuture = generateBilanPdf(
                      patient: _currentPatient,
                      bilanText: bilanCtrl.text,
                      dateCreation: DateTime.now(),
                      weight: _weightController.text.trim().isNotEmpty
                          ? _weightController.text.trim()
                          : null,
                      template: _selectedTemplate,
                    );
                    if (!mounted) return;
                    showPdfPreview(
                      context: context,
                      generatedPdfBytes: pdfFuture,
                    );
                  },
                  label: const Text('Preview'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  onPressed: () {
                    if (bilanCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Veuillez entrer les analyses à demander.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final bilan = Bilan(
                      patientId: _currentPatient.patientId!,
                      doctorId: int.tryParse(_doctorId ?? ''),
                      bilans: bilanCtrl.text,
                    );

                    context.read<BilanCubit>().createBilan(bilan);

                    final pdfFuture = generateBilanPdf(
                      patient: _currentPatient,
                      bilanText: bilanCtrl.text,
                      dateCreation: DateTime.now(),
                      weight: _weightController.text.trim().isNotEmpty
                          ? _weightController.text.trim()
                          : null,
                      template: _selectedTemplate,
                    );

                    Navigator.pop(ctx);
                    showPdfPreview(
                      context: context,
                      generatedPdfBytes: pdfFuture,
                    );
                  },
                  label: const Text('Save & Print'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLettreDeLiaisonDialog() {
    final detailsPlain = _detailsQuillController.document.toPlainText().trim();
    final examen =
        'Temperature: ${_temperatureController.text.isNotEmpty ? '${double.parse(_temperatureController.text).toStringAsFixed(2)}°C' : 'N/A'}\nTension: ${_tensionController.text.isNotEmpty ? _tensionController.text : 'N/A'}\nFrequence: ${_frequenceController.text.isNotEmpty ? _frequenceController.text : 'N/A'}\nSpao2: ${_spao2Controller.text.isNotEmpty ? _spao2Controller.text : 'N/A'}\n\n$detailsPlain';
    final atcdCtrl = TextEditingController(text: _currentPatient.atcd);
    final motifConsCtrl = TextEditingController(text: _motifController.text);
    
    quill.Document doc;
    if ((examen.startsWith('[') && examen.endsWith(']')) || 
        (examen.startsWith('{') && examen.endsWith('}'))) {
      try {
        final decoded = jsonDecode(examen);
        final List<dynamic> ops = decoded is List ? decoded : (decoded['ops'] ?? decoded);
        doc = quill.Document.fromJson(ops);
      } catch (_) {
        doc = quill.Document()..insert(0, examen);
      }
    } else {
      doc = quill.Document()..insert(0, examen);
    }
    final examenQuillController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final motifLettreCtrl = TextEditingController();
    final backPageTitleCtrl = TextEditingController();
    bool printTitleOnBack = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              // No hard minWidth — let the dialog adapt to the screen
              title: const Text('Nouvelle Lettre de Liaison'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: atcdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ATCD de',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: motifConsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Consulte pour',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Examen Clinique',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Column(
                        children: [
                          quill.QuillSimpleToolbar(
                            controller: examenQuillController,
                            config: const quill.QuillSimpleToolbarConfig(
                              showSearchButton: false,
                              showFontFamily: false,
                              showFontSize: false,
                              showInlineCode: false,
                              showSubscript: false,
                              showSuperscript: false,
                              showCodeBlock: false,
                              showQuote: false,
                              showIndent: false,
                              showLink: false,
                              showListCheck: false,
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: quill.QuillEditor.basic(
                              controller: examenQuillController,
                              config: const quill.QuillEditorConfig(
                                minHeight: 200,
                                scrollable: false,
                                expands: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: motifLettreCtrl,
                      decoration: const InputDecoration(
                        labelText: "Je vous l'adresse pour *",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text(
                        'Imprimer le titre au verso',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Ajoute une page blanche au verso avec le titre de la lettre',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: printTitleOnBack,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setDialogState(() {
                          printTitleOnBack = val ?? false;
                        });
                      },
                    ),
                    if (printTitleOnBack) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: backPageTitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Titre au verso',
                          hintText: 'Entrez le titre à imprimer au verso...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    if (!mounted) return;
                    final examenCliniqueJson = jsonEncode(examenQuillController.document.toDelta().toJson());
                    final pdfFuture = generateLettreDeLiaisonPdf(
                      patient: _currentPatient,
                      atcd: atcdCtrl.text,
                      motifConsultation: motifConsCtrl.text,
                      examenClinique: examenCliniqueJson,
                      motifLettre: motifLettreCtrl.text,
                      dateCreation: DateTime.now(),
                      template: _selectedTemplate,
                      backPageTitle: printTitleOnBack ? backPageTitleCtrl.text : null,
                    );
                    if (!mounted) return;
                    showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
                  },
                  label: const Text('Preview'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  onPressed: () {
                    if (motifLettreCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Le champ "Je vous l\'adresse pour" est requis.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final examenCliniqueJson = jsonEncode(examenQuillController.document.toDelta().toJson());
                    final lettre = Lettre(
                      patientId: _currentPatient.patientId!,
                      doctorId: int.tryParse(_doctorId ?? ''),
                      atcd: atcdCtrl.text,
                      motifConsultation: motifConsCtrl.text,
                      examenClinique: examenCliniqueJson,
                      motifLettre: motifLettreCtrl.text,
                    );
                    context.read<CertificateCubit>().createLettre(lettre);

                    final pdfFuture = generateLettreDeLiaisonPdf(
                      patient: _currentPatient,
                      atcd: atcdCtrl.text,
                      motifConsultation: motifConsCtrl.text,
                      examenClinique: examenCliniqueJson,
                      motifLettre: motifLettreCtrl.text,
                      dateCreation: DateTime.now(),
                      template: _selectedTemplate,
                      backPageTitle: printTitleOnBack ? backPageTitleCtrl.text : null,
                    );

                    Navigator.pop(ctx);
                    if (!mounted) return;
                    showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
                  },
                  label: const Text('Save & Print'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      atcdCtrl.dispose();
      motifConsCtrl.dispose();
      examenQuillController.dispose();
      motifLettreCtrl.dispose();
      backPageTitleCtrl.dispose();
    });
  }

  void _showMaladieChroniqueDialog() {
    final maladieCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nouveau Certificat Maladie Chronique'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: maladieCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Maladie Chronique *',
                    hintText: 'Ex: Diabète de type 2, HTA...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                if (maladieCtrl.text.isEmpty) return;
                final pdfFuture = generateMaladieChroniquePdf(
                  patient: _currentPatient,
                  maladieChronique: maladieCtrl.text,
                  dateCreation: DateTime.now(),
                  template: _selectedTemplate,
                );
                if (!mounted) return;
                showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
              },
              label: const Text('Preview'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt),
              onPressed: () async {
                if (maladieCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez entrer la maladie chronique.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                await DatabaseService().insert(
                  'INSERT INTO certificat_maladie_chronique (patient_id, doctor_id, maladie_chronique) VALUES (?, ?, ?)',
                  [
                    _currentPatient.patientId,
                    int.tryParse(_doctorId ?? '') ?? 0,
                    maladieCtrl.text,
                  ],
                );
                final pdfFuture = generateMaladieChroniquePdf(
                  patient: _currentPatient,
                  maladieChronique: maladieCtrl.text,
                  dateCreation: DateTime.now(),
                  template: _selectedTemplate,
                );
                Navigator.pop(ctx);
                if (!mounted) return;
                showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
              },
              label: const Text('Save & Print'),
            ),
          ],
        );
      },
    );
  }

  void _showDispenseSportDialog() {
    final motifCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Certificat de Dispense de Sport'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Établir une dispense d\'activités physiques pour ${_currentPatient.fullName}',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: motifCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motif (Optionnel)',
                    border: OutlineInputBorder(),
                    hintText: 'ex: Entorse, Asthme, etc.',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                final pdfFuture = generateDispenseSportPdf(
                  patient: _currentPatient,
                  motif: motifCtrl.text,
                  dateCreation: DateTime.now(),
                  template: _selectedTemplate,
                );
                if (!mounted) return;
                showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
              },
              label: const Text('Preview'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt),
              onPressed: () async {
                await DatabaseService().insert(
                  'INSERT INTO certificat_dispension_sport (patient_id, doctor_id, motif) VALUES (?, ?, ?)',
                  [
                    _currentPatient.patientId,
                    int.tryParse(_doctorId ?? '') ?? 0,
                    motifCtrl.text,
                  ],
                );
                final pdfFuture = generateDispenseSportPdf(
                  patient: _currentPatient,
                  motif: motifCtrl.text,
                  dateCreation: DateTime.now(),
                  template: _selectedTemplate,
                );
                Navigator.pop(ctx);
                if (!mounted) return;
                showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
              },
              label: const Text('Save & Print'),
            ),
          ],
        );
      },
    );
  }

  void _showBonneSanteDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nouveau Certificat de Bonne Santé'),
          content: Text(
            'Confirmez-vous la création d\'un certificat de bonne santé pour le patient ${_currentPatient.fullName} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                final pdfFuture = generateBonneSantePdf(
                  patient: _currentPatient,
                  dateCreation: DateTime.now(),
                  weight: _weightController.text.trim().isNotEmpty
                      ? _weightController.text.trim()
                      : null,
                  template: _selectedTemplate,
                );
                if (!mounted) return;
                showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
              },
              label: const Text('Preview'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt),
              onPressed: () async {
                await DatabaseService().insert(
                  'INSERT INTO certificat_bonne_sante (patient_id, doctor_id) VALUES (?, ?)',
                  [
                    _currentPatient.patientId,
                    int.tryParse(_doctorId ?? '') ?? 0,
                  ],
                );
                final pdfFuture = generateBonneSantePdf(
                  patient: _currentPatient,
                  dateCreation: DateTime.now(),
                  weight: _weightController.text.trim().isNotEmpty
                      ? _weightController.text.trim()
                      : null,
                  template: _selectedTemplate,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                showPdfPreview(context: context, generatedPdfBytes: pdfFuture);
              },
              label: const Text('Confirmer et Imprimer'),
            ),
          ],
        );
      },
    );
  }

  void _showPrenuptialDialog() {
    String? selectedBloodGroup = 'A+';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nouveau Certificat Prénuptial'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Établir un certificat médical prénuptial pour ${_currentPatient.fullName}',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedBloodGroup,
                      decoration: const InputDecoration(
                        labelText: 'Groupe Sanguin *',
                        prefixIcon: Icon(Icons.bloodtype),
                        border: OutlineInputBorder(),
                      ),
                      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                          .map((bg) => DropdownMenuItem(
                                value: bg,
                                child: Text(bg),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedBloodGroup = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    final pdfFuture = generatePrenuptialPdf(
                      patient: _currentPatient,
                      groupeSanguin: selectedBloodGroup,
                      dateCreation: DateTime.now(),
                      template: _selectedTemplate,
                    );
                    if (!mounted) return;
                    showPdfPreview(
                      context: context,
                      generatedPdfBytes: pdfFuture,
                      title: 'Certificat Prénuptial - Preview',
                    );
                  },
                  label: const Text('Preview'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  onPressed: () async {
                    await DatabaseService().insert(
                      'INSERT INTO certificat_prenuptial (patient_id, doctor_id, groupe_sanguin) VALUES (?, ?, ?)',
                      [
                        _currentPatient.patientId,
                        int.tryParse(_doctorId ?? '') ?? 0,
                        selectedBloodGroup,
                      ],
                    );
                    final pdfFuture = generatePrenuptialPdf(
                      patient: _currentPatient,
                      groupeSanguin: selectedBloodGroup,
                      dateCreation: DateTime.now(),
                      template: _selectedTemplate,
                    );
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    showPdfPreview(
                      context: context,
                      generatedPdfBytes: pdfFuture,
                      title: 'Certificat Prénuptial - Preview',
                    );
                  },
                  label: const Text('Save & Print'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submit() {
    final plainDetails = _detailsQuillController.document.toPlainText().trim();
    if (plainDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Détails required'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_doctorController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Doctor ID is required')));
      return;
    }

    setState(() => _isLoading = true);

    final record = MedicalRecord(
      id: widget.recordToEdit?.id,
      patientId: _currentPatient.patientId!,
      doctorId: int.tryParse(_doctorId ?? '') ?? 0,
      recordDate: _prescriptionDate,
      motif: _motifController.text.isEmpty ? null : _motifController.text,
      details: jsonEncode(_detailsQuillController.document.toDelta().toJson()),
      diagnostic: _diagnosticController.text.isEmpty
          ? null
          : _diagnosticController.text,
      prescriptions: _prescriptionsFieldController.text.isEmpty
          ? null
          : _prescriptionsFieldController.text,
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

    if (widget.recordToEdit != null) {
      context.read<MedicalRecordCubit>().updateMedicalRecord(
        widget.recordToEdit!.id!,
        record,
      );
    } else {
      context.read<MedicalRecordCubit>().createMedicalRecord(record);
    }
  }

  Future<void> _processPayment(int recordId) async {
    if (_selectedServices.isEmpty) return;
    setState(() => _isProcessingPayment = true);

    final servicesText = _selectedServices.map((s) => s.serviceName).join(', ');

    final payment = Payment(
      patientId: _currentPatient.patientId,
      doctorId: int.tryParse(_doctorId ?? ''),
      patientName: _currentPatient.firstName,
      patientSurname: _currentPatient.lastName,
      servicesText: servicesText,
      amount: _totalPaymentAmount,
      paymentDate: DateTime.now(),
      recordId: recordId,
      notes: _paymentNoteController.text,
      paymentMethod: _paymentMethod,
    );

    final paymentServices = _selectedServices
        .map(
          (s) => PaymentService(
            serviceId: s.serviceId,
            serviceName: s.serviceName,
            servicePrice: s.price,
            doctorCommission: s.doctorCommission,
          ),
        )
        .toList();

    await context.read<BillingCubit>().createPaymentWithServices(
      payment,
      paymentServices,
    );
  }

  Future<void> _updatePaymentForRecord(int recordId) async {
    if (_selectedServices.isEmpty) return;
    setState(() => _isProcessingPayment = true);

    try {
      final repo = PaymentRepository();
      final result = await repo.getByRecordId(recordId);

      result.fold((_) {}, (existingPayment) async {
        if (existingPayment == null) {
          await _processPayment(recordId);
          return;
        }

        final servicesText = _selectedServices
            .map((s) => s.serviceName)
            .join(', ');
        final updatedPayment = existingPayment.copyWith(
          amount: _totalPaymentAmount,
          servicesText: servicesText,
          notes: _paymentNoteController.text,
          paymentMethod: _paymentMethod,
        );

        final paymentServices = _selectedServices
            .map(
              (s) => PaymentService(
                serviceId: s.serviceId,
                serviceName: s.serviceName,
                servicePrice: s.price,
                doctorCommission: s.doctorCommission,
              ),
            )
            .toList();

        final updateResult = await repo.updateWithServices(
          existingPayment.paymentId!,
          updatedPayment,
          paymentServices,
        );

        updateResult.fold(
          (failure) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update payment: ${failure.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _finalizeAfterCreate(int recordId) async {
    setState(() => _isProcessingPayment = true);
    try {
      if (_selectedServices.isNotEmpty) {
        await _processPayment(recordId);
      }
      if (_soinsController.text.isNotEmpty) {
        await _saveSoins(recordId);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        context.read<WorkspaceCubit>().closeTab(widget.tabId);
      }
    }
  }

  Future<void> _finalizeAfterUpdate(int recordId) async {
    setState(() => _isProcessingPayment = true);
    try {
      await _updatePaymentForRecord(recordId);
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        context.read<WorkspaceCubit>().closeTab(widget.tabId);
      }
    }
  }

  void _addService(Service service) {
    _markAsDirty();
    setState(() {
      _selectedServices.add(service);
      _recalculateTotals();
    });
  }

  void _removeServiceAt(int index) {
    _markAsDirty();
    setState(() {
      _selectedServices.removeAt(index);
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    _totalPaymentAmount = _selectedServices.fold(
      0.0,
      (sum, item) => sum + item.price,
    );
    _totalDoctorCommission = _selectedServices.fold(
      0.0,
      (sum, item) => sum + item.doctorCommission,
    );
  }

  void _showCnasVerificationDialog() {
    List<CnasBeneficiary>? beneficiaries;
    CnasBeneficiary? selectedBeneficiary;
    bool isLoading = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void checkValidity(CnasBeneficiary chosen) {
              if (chosen.isValid) {
                setDialogState(() {
                  selectedBeneficiary = chosen;
                });
              } else {
                // Expired or Already consulted! Look for another beneficiary
                CnasBeneficiary? other;
                for (final item in beneficiaries!) {
                  if (item.isValid) {
                    other = item;
                    break;
                  }
                }
                if (other != null) {
                  setDialogState(() {
                    selectedBeneficiary = other;
                  });
                  final reason = chosen.status == 'already_consulted'
                      ? "Déjà consulté aujourd'hui"
                      : "Droits expirés";
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        "$reason pour ${chosen.text}. Sélection automatique de ${other.text}.",
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else {
                  setDialogState(() {
                    selectedBeneficiary = null;
                  });
                  final title = chosen.status == 'already_consulted'
                      ? 'Déjà Consulté'
                      : 'Droits Expirés';
                  final message = chosen.status == 'already_consulted'
                      ? "Alerte: Le patient a déjà effectué une consultation aujourd'hui."
                      : 'Alerte: La date de fin de droit a expiré pour tous les bénéficiaires.';
                  showDialog(
                    context: dialogContext,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(title),
                        ],
                      ),
                      content: Text(message),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('Vérification Carte CHIFA'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (beneficiaries == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.credit_card),
                        label: const Text('Lire la Carte CHIFA'),
                        onPressed: () async {
                          String currentAssurance = _currentPatient.nationalId ?? "";
                          
                          Future<void> runFetch(String assurance) async {
                            setDialogState(() {
                              isLoading = true;
                            });
                            List<CnasBeneficiary> list = [];
                            String? errorMessage;
                            try {
                              list = await CnasService.instance.fetchBeneficiaries(assurance);
                            } catch (e) {
                              errorMessage = e.toString().replaceAll('Exception:', '').trim();
                            }
                            
                            if (errorMessage != null && 
                                (errorMessage.contains("indicateurs au rouge") || 
                                 errorMessage.contains("lecteur de carte") ||
                                 errorMessage.contains("Lecteur de carte"))) {
                              
                              setDialogState(() {
                                isLoading = false;
                              });
                              
                              final enteredNo = await _showInsuranceNumberDialog(dialogContext, assurance);
                              if (enteredNo != null && enteredNo.isNotEmpty) {
                                final saved = await _updatePatientNationalId(enteredNo);
                                if (saved) {
                                  await runFetch(enteredNo);
                                }
                              }
                              return;
                            }
                            
                            setDialogState(() {
                              beneficiaries = errorMessage == null ? list : [];
                              isLoading = false;
                              if (list.isNotEmpty) {
                                final first = list.first;
                                if (first.isValid) {
                                  selectedBeneficiary = first;
                                } else {
                                  CnasBeneficiary? validOne;
                                  for (final b in list) {
                                    if (b.isValid) {
                                      validOne = b;
                                      break;
                                    }
                                  }
                                  if (validOne != null) {
                                    selectedBeneficiary = validOne;
                                    final reason = first.status == 'already_consulted'
                                        ? "Déjà consulté aujourd'hui"
                                        : "Droits expirés";
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "$reason pour ${first.text}. Sélection automatique de ${validOne.text}.",
                                        ),
                                        backgroundColor: Colors.orange,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  } else {
                                    selectedBeneficiary = null;
                                    final title = first.status == 'already_consulted'
                                        ? 'Déjà Consulté'
                                        : 'Droits Expirés';
                                    final message = first.status == 'already_consulted'
                                        ? "Alerte: Le patient a déjà effectué une consultation aujourd'hui."
                                        : 'Alerte: La date de fin de droit a expiré pour tous les bénéficiaires.';
                                    showDialog(
                                      context: dialogContext,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          children: [
                                            const Icon(Icons.warning, color: Colors.red),
                                            const SizedBox(width: 8),
                                            Text(title),
                                          ],
                                        ),
                                        content: Text(message),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              }
                            });
                            
                            if (errorMessage != null) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 8),
                                ),
                              );
                            } else if (list.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Aucun bénéficiaire trouvé.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                          
                          if (currentAssurance.isEmpty) {
                            final enteredNo = await _showInsuranceNumberDialog(dialogContext, "");
                            if (enteredNo != null && enteredNo.isNotEmpty) {
                              final saved = await _updatePatientNationalId(enteredNo);
                              if (saved) {
                                await runFetch(enteredNo);
                              }
                            }
                          } else {
                            await runFetch(currentAssurance);
                          }
                        },
                      )
                    else ...[
                      DropdownButtonFormField<CnasBeneficiary>(
                        value: selectedBeneficiary,
                        decoration: const InputDecoration(
                          labelText: 'Bénéficiaire',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: beneficiaries!.map((b) {
                          String labelText = 'Valide';
                          Color labelColor = Colors.green;
                          Color itemColor = Colors.black;
                          if (b.status == 'already_consulted') {
                            labelText = 'Déjà consulté';
                            labelColor = Colors.orange.shade700;
                            itemColor = Colors.orange.shade900;
                          } else if (!b.isValid) {
                            labelText = 'Expiré';
                            labelColor = Colors.red;
                            itemColor = Colors.red;
                          }
                          return DropdownMenuItem<CnasBeneficiary>(
                            value: b,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    b.text,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: itemColor,
                                      fontWeight: b.isValid ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  labelText,
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (b) {
                                if (b != null) {
                                  checkValidity(b);
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      if (selectedBeneficiary != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            "Date Fin Droit: ${selectedBeneficiary!.dfd}",
                            style: TextStyle(
                              color: selectedBeneficiary!.isValid ? Colors.green.shade800 : Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (isSubmitting)
                        const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text(
                              "Enregistrement de la prescription sur le portail CNAS...",
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Enregistrer la Prescription sur CNAS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedBeneficiary != null && selectedBeneficiary!.isValid
                                ? Colors.green.shade700
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: selectedBeneficiary == null || !selectedBeneficiary!.isValid
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isSubmitting = true;
                                  });

                                  final rawText = _prescriptionsFieldController.text;
                                  final lines = rawText
                                      .split('\n')
                                      .map((l) => l.trim())
                                      .where((l) => l.isNotEmpty)
                                      .toList();
                                  final medicines = lines.map((l) {
                                    var clean = l.replaceFirst(RegExp(r'^\d+[\.\s\-]*'), '').trim();
                                    if (clean.contains('-')) {
                                      clean = clean.split('-')[0].trim();
                                    }
                                    return clean;
                                  }).where((m) => m.isNotEmpty).toList();

                                  if (medicines.isEmpty) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      const SnackBar(
                                        content: Text('Veuillez d\'abord saisir une ordonnance.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    setDialogState(() {
                                      isSubmitting = false;
                                    });
                                    return;
                                  }

                                  final success = await CnasService.instance.runPrescription(
                                    assuranceNumber: widget.patient.nationalId ?? "",
                                    beneficiaryValue: selectedBeneficiary!.value,
                                    medicines: medicines,
                                  );

                                  setDialogState(() {
                                    isSubmitting = false;
                                  });

                                  if (success) {
                                    Navigator.pop(dialogContext);
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text('Succès'),
                                          ],
                                        ),
                                        content: const Text(
                                          'L\'ordonnance a été validée et enregistrée avec succès sur le portail PNC CNAS.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(Icons.error, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Erreur'),
                                          ],
                                        ),
                                        content: const Text(
                                          'Une erreur s\'est produite lors de l\'enregistrement de l\'ordonnance sur le portail CNAS.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          setState(() {
                            _paymentMethod = 'Cash';
                          });
                        },
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _filterServices(String query, List<Service> allServices) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredServices = allServices;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredServices = allServices.where((s) {
          return s.serviceName.toLowerCase().contains(lowerQuery) ||
              (s.price.toString().contains(lowerQuery)) ||
              (s.specialization?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }
      _showServiceSuggestions = true;
    });
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
          // Handle new record creation
          if (widget.recordToEdit == null && state.lastCreatedId != null) {
            if (_selectedServices.isNotEmpty ||
                _soinsController.text.isNotEmpty) {
              _finalizeAfterCreate(state.lastCreatedId!);
            }
          }

          // Handle existing record update - process payment/services
          if (widget.recordToEdit != null) {
            _finalizeAfterUpdate(widget.recordToEdit!.id!);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
          context.read<MedicalRecordCubit>().clearSuccessMessage();
          // Only close tab if not processing payment
          if (!_isProcessingPayment && context.mounted) {
            context.read<WorkspaceCubit>().closeTab(widget.tabId);
          }
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
          context.read<MedicalRecordCubit>().clearError();
        }
      },
      child: BlocListener<BillingCubit, BillingState>(
        listenWhen: (previous, current) =>
            previous.successMessage != current.successMessage ||
            previous.error != current.error,
        listener: (context, state) {
          // Guard against billing state changes from other tabs/dialogs
          if (!_isProcessingPayment) return;

          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
            context.read<BillingCubit>().clearSuccessMessage();
            setState(() => _isProcessingPayment = false);
          } else if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ),
            );
            context.read<BillingCubit>().clearError();
            setState(() => _isProcessingPayment = false);
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          endDrawer: Drawer(
            width: MediaQuery.of(context).size.width * 0.85 > 450
                ? 450
                : MediaQuery.of(context).size.width * 0.85,
            child: SafeArea(
              child: PatientHistoryPanel(
                patient: _currentPatient,
                onImportPrescription: (val) {
                  setState(() {
                    if (_prescriptionsFieldController.text.isNotEmpty) {
                      _prescriptionsFieldController.text += '\n$val';
                    } else {
                      _prescriptionsFieldController.text = val;
                    }
                    _markAsDirty();
                  });
                  Navigator.pop(context);
                },
                onImportDiagnostic: (val) {
                  setState(() {
                    if (_diagnosticController.text.isNotEmpty) {
                      _diagnosticController.text += ' $val';
                    } else {
                      _diagnosticController.text = val;
                    }
                    _markAsDirty();
                  });
                  Navigator.pop(context);
                },
                onImportMotif: (val) {
                  setState(() {
                    if (_motifController.text.isNotEmpty) {
                      _motifController.text += ' $val';
                    } else {
                      _motifController.text = val;
                    }
                    _markAsDirty();
                  });
                  Navigator.pop(context);
                },
                onImportDetails: (val) {
                  setState(() {
                    final currentDoc = _detailsQuillController.document;
                    final prefix = currentDoc.toPlainText().trim().isEmpty ? '' : '\n';
                    _detailsQuillController.document.insert(currentDoc.length - 1, prefix + val);
                    _markAsDirty();
                  });
                  Navigator.pop(context);
                },
                onImportSoins: (val) {
                  setState(() {
                    if (_soinsController.text.isNotEmpty) {
                      _soinsController.text += '\n$val';
                    } else {
                      _soinsController.text = val;
                    }
                    _markAsDirty();
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ),
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
                      widget.recordToEdit != null
                          ? 'Edit Medical Record'
                          : 'New Medical Record',
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = MediaQuery.of(context).size.width >= 1100;
                      final formWidget = SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Card(
                            elevation: 0,
                            color: Colors.blue.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.blue.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        child: Text(
                                          _currentPatient.firstName.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _currentPatient.fullName,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                            Text(
                                              'ID: ${_currentPatient.patientId}  •  ${_currentPatient.age} ans  •  ${_currentPatient.gender == Gender.male ? 'Homme' : _currentPatient.gender == Gender.female ? 'Femme' : 'N/A'}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        tooltip: 'Modifier les informations du patient',
                                        onPressed: _showEditPatientDialog,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.calendar_month, color: Colors.teal),
                                        tooltip: 'Planifier un rendez-vous',
                                        onPressed: _showAppointmentDialog,
                                      ),
                                      if (MediaQuery.of(context).size.width < 1100)
                                        IconButton(
                                          icon: const Icon(Icons.history, color: Colors.blue),
                                          tooltip: 'Dossier Historique du Patient',
                                          onPressed: () {
                                            _scaffoldKey.currentState?.openEndDrawer();
                                          },
                                        ),
                                    ],
                                  ),
                                  if (_currentPatient.atcd.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.history, size: 16, color: Colors.orange.shade700),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Antécédents: ${_currentPatient.atcd}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade900,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            readOnly: true,
                            controller: _doctorController,
                            decoration: const InputDecoration(
                              labelText: 'Doctor Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.medical_services),
                            ),
                            keyboardType: TextInputType.text,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _motifController,
                            decoration: const InputDecoration(
                              labelText: 'Motif de Consultation',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.question_mark),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Détails *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Column(
                              children: [
                                quill.QuillSimpleToolbar(
                                  controller: _detailsQuillController,
                                  config: const quill.QuillSimpleToolbarConfig(
                                    showSearchButton: false,
                                    showFontFamily: false,
                                    showFontSize: false,
                                    showInlineCode: false,
                                    showSubscript: false,
                                    showSuperscript: false,
                                    showCodeBlock: false,
                                    showQuote: false,
                                    showIndent: false,
                                    showLink: false,
                                    showListCheck: false,
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: quill.QuillEditor.basic(
                                    controller: _detailsQuillController,
                                    config: const quill.QuillEditorConfig(
                                      scrollable: false,
                                      expands: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width < 600
                                    ? double.infinity
                                    : (MediaQuery.of(context).size.width -
                                              100) /
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
                                  validator: _validateWeight,
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width < 600
                                    ? (MediaQuery.of(context).size.width - 40) /
                                          2
                                    : (MediaQuery.of(context).size.width -
                                              100) /
                                          3,
                                child: TextFormField(
                                  controller: _temperatureController,
                                  decoration: const InputDecoration(
                                    labelText: 'Temp (°C)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.thermostat),
                                  ),
                                  validator: _validateTemperature,
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width < 600
                                    ? (MediaQuery.of(context).size.width - 40) /
                                          2
                                    : (MediaQuery.of(context).size.width -
                                              100) /
                                          3,
                                child: TextFormField(
                                  controller: _tensionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tension',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.favorite),
                                  ),
                                  validator: _validateTension,
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
                                    ? (MediaQuery.of(context).size.width - 40) /
                                          2
                                    : (MediaQuery.of(context).size.width - 80) /
                                          2,
                                child: TextFormField(
                                  controller: _frequenceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Fréq. Cardiaque',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.monitor_heart),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: _validateHeartRate,
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width < 600
                                    ? (MediaQuery.of(context).size.width - 40) /
                                          2
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
                                  validator: _validateSpO2,
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

                          // Prescriptions Section
                          Row(
                            children: [
                              const Icon(
                                Icons.medication,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Prescription',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.search, size: 18),
                                label: const Text('Assistant Pathologie IA'),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => PathologySearchDialog(
                                      onInsertTreatment: (treatment) {
                                        setState(() {
                                          if (_prescriptionsFieldController.text.isNotEmpty) {
                                            _prescriptionsFieldController.text += '\n$treatment';
                                          } else {
                                            _prescriptionsFieldController.text = treatment;
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Advanced Search Row — adaptive for narrow screens
                          Builder(
                            builder: (context) {
                              final small =
                                  MediaQuery.of(context).size.width < 600;
                              final searchField = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _medicSearchController,
                                    decoration: InputDecoration(
                                      labelText: 'Search Medicament (DB)',
                                      hintText: 'Name, DCI, Indication, etc.',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 20,
                                      ),
                                      suffixIcon: _isSearching
                                          ? Container(
                                              width: 16,
                                              height: 16,
                                              padding: const EdgeInsets.all(12),
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                            )
                                          : _medicSearchController
                                                .text
                                                .isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 16,
                                              ),
                                              onPressed: () {
                                                _medicSearchController.clear();
                                                setState(
                                                  () => _searchResults = [],
                                                );
                                                setState(
                                                  () => _selectedMedic = null,
                                                );
                                              },
                                            )
                                          : ElevatedButton(
                                              onPressed: _addNewMedicament,
                                              child: const Icon(Icons.add),
                                            ),
                                    ),
                                    onChanged: _searchMedicament,
                                  ),
                                  if (_searchResults.isNotEmpty)
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 180,
                                      ),
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        color: Colors.white,
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: _searchResults.length,
                                        itemBuilder: (context, index) {
                                          final medic = _searchResults[index];
                                          final name = (medic['name'] ?? 'Unknown').replaceAll(',', '.');
                                          final dosage = medic['dosage'] ?? '';
                                          final formulation = medic['formulation'] ?? '';
                                          final conditionnement = medic['conditionnement'] ?? '';
                                          final dci = medic['dci'] ?? '';
                                          final origin = medic['origin'] ?? '';

                                          final titleParts = [
                                            name,
                                            if (dosage.toString().isNotEmpty) dosage,
                                            if (formulation.toString().isNotEmpty) formulation,
                                            if (conditionnement.toString().isNotEmpty) '($conditionnement)',
                                          ];
                                          final titleText = titleParts.where((p) => p.toString().isNotEmpty).join(' ');

                                          String capitalizedDci = '';
                                          if (dci.toString().isNotEmpty) {
                                            final cleaned = dci.toString().replaceAll(':', '').trim().toLowerCase();
                                            if (cleaned.isNotEmpty) {
                                              capitalizedDci = cleaned[0].toUpperCase() + cleaned.substring(1);
                                            }
                                          }

                                          final subtitleParts = [
                                            if (capitalizedDci.isNotEmpty) capitalizedDci,
                                            if (origin.toString().isNotEmpty) '[$origin]',
                                          ];
                                          final subtitleText = subtitleParts.where((p) => p.toString().isNotEmpty).join(' - ');

                                          return ListTile(
                                            dense: true,
                                            title: Text(
                                              titleText,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            subtitle: Text(
                                              subtitleText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.normal,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            onTap: () =>
                                                _selectMedicament(medic),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              );

                               if (small) {
                                 // Two-row layout on mobile
                                 return Column(
                                   crossAxisAlignment:
                                       CrossAxisAlignment.stretch,
                                   children: [
                                     searchField,
                                     _buildPosologyRecommendation(),
                                     const SizedBox(height: 8),
                                     Row(
                                       children: [
                                         Expanded(
                                           child: TextField(
                                             controller: _posologyController,
                                             decoration: const InputDecoration(
                                               labelText: 'Posologie',
                                               isDense: true,
                                               border: OutlineInputBorder(),
                                             ),
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: TextField(
                                             controller: _durationController,
                                             decoration: const InputDecoration(
                                               labelText: 'Durée',
                                               isDense: true,
                                               border: OutlineInputBorder(),
                                             ),
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         ElevatedButton(
                                           onPressed: _addMedicToTextArea,
                                           style: ElevatedButton.styleFrom(
                                             padding: const EdgeInsets.symmetric(
                                               horizontal: 12,
                                               vertical: 14,
                                             ),
                                           ),
                                           child: const Icon(
                                             Icons.add,
                                             size: 20,
                                           ),
                                         ),
                                       ],
                                     ),
                                   ],
                                 );
                               }

                               // Wide layout — single row
                               return Column(
                                 crossAxisAlignment: CrossAxisAlignment.stretch,
                                 children: [
                                   Row(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Expanded(flex: 5, child: searchField),
                                       const SizedBox(width: 8),
                                       Expanded(
                                         flex: 3,
                                         child: TextField(
                                           controller: _posologyController,
                                           decoration: const InputDecoration(
                                             labelText: 'Posologie',
                                             isDense: true,
                                             border: OutlineInputBorder(),
                                           ),
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       Expanded(
                                         flex: 3,
                                         child: TextField(
                                           controller: _durationController,
                                           decoration: const InputDecoration(
                                             labelText: 'Durée',
                                             isDense: true,
                                             border: OutlineInputBorder(),
                                           ),
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       ElevatedButton(
                                         onPressed: _addMedicToTextArea,
                                         style: ElevatedButton.styleFrom(
                                           padding: const EdgeInsets.symmetric(
                                             horizontal: 16,
                                             vertical: 14,
                                           ),
                                         ),
                                         child: const Icon(Icons.add, size: 20),
                                       ),
                                     ],
                                   ),
                                   _buildPosologyRecommendation(),
                                 ],
                               );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Main Prescription Area
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
                            controller: _prescriptionsFieldController,
                            decoration: const InputDecoration(
                              labelText: 'Ordonnance *',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 6,
                            minLines: 4,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.bookmark_add, size: 18),
                                label: const Text('Sauvegarder comme modèle'),
                                onPressed: _savePrescriptionAsModel,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Templates Section
                          Card(
                            elevation: 0,
                            color: Colors.grey.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Modèles (Common Prescriptions)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  BlocBuilder<
                                    PrescriptionCubit,
                                    PrescriptionState
                                  >(
                                    builder: (context, state) {
                                      List<PrescriptionType> types = [];
                                      if (state is PrescriptionTypesLoaded) {
                                        types = state.types;
                                      }

                                      return DropdownButtonFormField<
                                        PrescriptionType
                                      >(
                                        decoration: const InputDecoration(
                                          labelText: 'Modèles d\'ordonnances',
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
                                              if (_prescriptionsFieldController
                                                  .text
                                                  .isNotEmpty) {
                                                _prescriptionsFieldController
                                                        .text +=
                                                    '\n${val.prescription}';
                                              } else {
                                                _prescriptionsFieldController
                                                        .text =
                                                    val.prescription;
                                              }
                                            });
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search templates...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                  const SizedBox(height: 12),
                                  BlocBuilder<
                                    PrescriptionCubit,
                                    PrescriptionState
                                  >(
                                    builder: (context, state) {
                                      if (state is PrescriptionLoading) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }

                                      if (state is PrescriptionsLoaded) {
                                        if (state.prescriptions.isEmpty) {
                                          return const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text('No templates found'),
                                            ),
                                          );
                                        }

                                        return Container(
                                          constraints: const BoxConstraints(
                                            maxHeight: 200,
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount:
                                                state.prescriptions.length,
                                            itemBuilder: (context, index) {
                                              final template =
                                                  state.prescriptions[index];
                                              return ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                  Icons.article,
                                                  size: 20,
                                                ),
                                                title: Text(
                                                  template.prescription.length >
                                                          50
                                                      ? '${template.prescription.substring(0, 50).replaceAll('\n', ' ')}...'
                                                      : template.prescription
                                                            .replaceAll(
                                                              '\n',
                                                              ' ',
                                                            ),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                    color: Colors.blue,
                                                  ),
                                                  onPressed: () =>
                                                      _insertTemplate(template),
                                                  tooltip: 'Use this template',
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }

                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Soins Medicaux Section
                          Row(
                            children: [
                              const Icon(
                                Icons.medical_information,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Soins Médicaux',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 24),

                          // Certificates & Letters Section
                          Row(
                            children: [
                              const Icon(
                                Icons.description,
                                color: Colors.indigo,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Certificats & Lettres',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Certificate buttons — Wrap so they reflow on small screens
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _certButton(
                                icon: Icons.sick,
                                color: Colors.orange,
                                label: 'Arrêt de Travail',
                                onPressed: _showArretDeTravailDialog,
                              ),
                              _certButton(
                                icon: Icons.biotech,
                                color: Colors.blue,
                                label: 'Lab Test',
                                onPressed: _showBilanDialog,
                              ),
                              _certButton(
                                icon: Icons.email,
                                color: Colors.purple,
                                label: 'Lettre de Liaison',
                                onPressed: _showLettreDeLiaisonDialog,
                              ),
                              _certButton(
                                icon: Icons.medical_information,
                                color: Colors.teal,
                                label: 'Maladie Chronique',
                                onPressed: _showMaladieChroniqueDialog,
                              ),
                              _certButton(
                                icon: Icons.health_and_safety,
                                color: Colors.green,
                                label: 'Bonne Santé',
                                onPressed: _showBonneSanteDialog,
                              ),
                              _certButton(
                                icon: Icons.fitness_center,
                                color: Colors.blueAccent,
                                label: 'Dispense Sport',
                                onPressed: _showDispenseSportDialog,
                              ),
                              _certButton(
                                icon: Icons.favorite,
                                color: Colors.red,
                                label: 'Prénuptial',
                                onPressed: _showPrenuptialDialog,
                              ),
                              _certButton(
                                icon: Icons.bloodtype_outlined,
                                color: Colors.blueGrey,
                                label: 'Suivi Glycémique',
                                onPressed: () {
                                  showPdfPreview(
                                    context: context,
                                    generatedPdfBytes: generateProfilGlycemiquePdf(
                                      patient: _currentPatient,
                                      dateCreation: DateTime.now(),
                                      template: _selectedTemplate,
                                    ),
                                    title: 'Feuille de suivi glycémique - Preview',
                                  );
                                },
                              ),
                              _certButton(
                                icon: Icons.monitor_heart,
                                color: Colors.redAccent,
                                label: 'Profil TA',
                                onPressed: () {
                                  showPdfPreview(
                                    context: context,
                                    generatedPdfBytes: generateProfilTAPdf(
                                      patient: _currentPatient,
                                      dateCreation: DateTime.now(),
                                      template: _selectedTemplate,
                                    ),
                                    title: 'Profil TA - Preview',
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Services & Payment Section
                          Row(
                            children: [
                              const Icon(Icons.payments, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Services & Payment',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Mode de paiement',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.payment),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Cash',
                                child: Text('Espèces (Cash)'),
                              ),
                              DropdownMenuItem(
                                value: 'Credit Card',
                                child: Text('Carte Bancaire'),
                              ),
                              DropdownMenuItem(
                                value: 'CARTE CHIFA',
                                child: Text('CARTE CHIFA'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _paymentMethod = val;
                                });
                                if (val == 'CARTE CHIFA') {
                                  _showCnasVerificationDialog();
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          BlocBuilder<BillingCubit, BillingState>(
                            buildWhen: (previous, current) =>
                                previous.services != current.services ||
                                previous.isLoading != current.isLoading,
                            builder: (context, state) {
                              if (state.isLoading && state.services.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (state.services.isNotEmpty) {
                                final allServices = state.services;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Searchable service input
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextField(
                                          controller: _serviceSearchController,
                                          decoration: InputDecoration(
                                            labelText: 'Search Services',
                                            hintText: 'Type to search...',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              size: 20,
                                            ),
                                            suffixIcon:
                                                _serviceSearchController
                                                    .text
                                                    .isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      size: 16,
                                                    ),
                                                    onPressed: () {
                                                      _serviceSearchController
                                                          .clear();
                                                      setState(() {
                                                        _showServiceSuggestions =
                                                            false;
                                                        _filteredServices = [];
                                                      });
                                                    },
                                                  )
                                                : null,
                                          ),
                                          onChanged: (value) => _filterServices(
                                            value,
                                            allServices,
                                          ),
                                          onTap: () {
                                            if (_serviceSearchController
                                                .text
                                                .isEmpty) {
                                              _filterServices('', allServices);
                                            }
                                          },
                                        ),
                                        // Suggestions dropdown
                                        if (_showServiceSuggestions &&
                                            _filteredServices.isNotEmpty)
                                          Container(
                                            constraints: const BoxConstraints(
                                              maxHeight: 200,
                                            ),
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: ListView.separated(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount:
                                                  _filteredServices.length,
                                              separatorBuilder: (_, index) =>
                                                  Divider(
                                                    height: 1,
                                                    color: Colors.grey.shade200,
                                                  ),
                                              itemBuilder: (context, index) {
                                                final service =
                                                    _filteredServices[index];
                                                final isAlreadySelected =
                                                    _selectedServices.any(
                                                      (s) =>
                                                          s.serviceId ==
                                                          service.serviceId,
                                                    );
                                                return ListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 2,
                                                      ),
                                                  leading: Icon(
                                                    isAlreadySelected
                                                        ? Icons.check_circle
                                                        : Icons
                                                              .add_circle_outline,
                                                    color: isAlreadySelected
                                                        ? Colors.green
                                                        : Colors.grey,
                                                    size: 20,
                                                  ),
                                                  title: Text(
                                                    service.serviceName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: isAlreadySelected
                                                          ? Colors
                                                                .green
                                                                .shade700
                                                          : null,
                                                    ),
                                                  ),
                                                  subtitle: Row(
                                                    children: [
                                                      Text(
                                                        '${service.price.toStringAsFixed(2)} DA',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .blue
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        'Commission: ${service.doctorCommission.toStringAsFixed(2)} DA',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .orange
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  onTap: () {
                                                    _addService(service);
                                                    _serviceSearchController
                                                        .clear();
                                                    setState(() {
                                                      _showServiceSuggestions =
                                                          false;
                                                      _filteredServices = [];
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Selected services chips
                                    if (_selectedServices.isNotEmpty) ...[
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _selectedServices.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final service = entry.value;
                                          return Chip(
                                            label: Text(
                                              '${service.serviceName} — ${service.price.toStringAsFixed(2)} DA',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            deleteIcon: const Icon(
                                              Icons.close,
                                              size: 16,
                                            ),
                                            onDeleted: () =>
                                                _removeServiceAt(index),
                                            backgroundColor:
                                                Colors.green.shade50,
                                            side: BorderSide(
                                              color: Colors.green.shade200,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 12),

                                      // Breakdown table
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Table header
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(7),
                                                    ),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      'Service',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Amount',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Commission',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Table rows
                                            ..._selectedServices.map((service) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    top: BorderSide(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(
                                                        service.serviceName,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        '${service.price.toStringAsFixed(2)} DA',
                                                        textAlign:
                                                            TextAlign.right,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .blue
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        '${service.doctorCommission.toStringAsFixed(2)} DA',
                                                        textAlign:
                                                            TextAlign.right,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .orange
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            // Totals row
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      bottom: Radius.circular(
                                                        7,
                                                      ),
                                                    ),
                                                border: Border(
                                                  top: BorderSide(
                                                    color:
                                                        Colors.green.shade200,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      'TOTAL',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '${_totalPaymentAmount.toStringAsFixed(2)} DA',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color: Colors
                                                            .blue
                                                            .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '${_totalDoctorCommission.toStringAsFixed(2)} DA',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                        color: Colors
                                                            .orange
                                                            .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _paymentNoteController,
                                        decoration: const InputDecoration(
                                          labelText: 'Payment Note (Optional)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                              return const Text('Loading services...');
                            },
                          ),
                        ],
                      ),
                    ),
                  );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: formWidget,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: PatientHistoryPanel(
                                patient: _currentPatient,
                                onImportPrescription: (val) {
                                  setState(() {
                                    if (_prescriptionsFieldController.text.isNotEmpty) {
                                      _prescriptionsFieldController.text += '\n$val';
                                    } else {
                                      _prescriptionsFieldController.text = val;
                                    }
                                    _markAsDirty();
                                  });
                                },
                                onImportDiagnostic: (val) {
                                  setState(() {
                                    if (_diagnosticController.text.isNotEmpty) {
                                      _diagnosticController.text += ' $val';
                                    } else {
                                      _diagnosticController.text = val;
                                    }
                                    _markAsDirty();
                                  });
                                },
                                onImportMotif: (val) {
                                  setState(() {
                                    if (_motifController.text.isNotEmpty) {
                                      _motifController.text += ' $val';
                                    } else {
                                      _motifController.text = val;
                                    }
                                    _markAsDirty();
                                  });
                                },
                                onImportDetails: (val) {
                                  setState(() {
                                    final currentDoc = _detailsQuillController.document;
                                    final prefix = currentDoc.toPlainText().trim().isEmpty ? '' : '\n';
                                    _detailsQuillController.document.insert(currentDoc.length - 1, prefix + val);
                                    _markAsDirty();
                                  });
                                },
                                onImportSoins: (val) {
                                  setState(() {
                                    if (_soinsController.text.isNotEmpty) {
                                      _soinsController.text += '\n$val';
                                    } else {
                                      _soinsController.text = val;
                                    }
                                    _markAsDirty();
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        return formWidget;
                      }
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: _buildFooter(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── adaptive footer ──────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    final small = MediaQuery.of(context).size.width < 600;

    final previewBtn = OutlinedButton.icon(
      onPressed: () {
        if (_prescriptionsFieldController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No prescription entered.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        final weight = _weightController.text.trim().isNotEmpty
            ? _weightController.text.trim()
            : null;
        showPdfPreview(
          context: context,
          generatedPdfBytes: generateOrdonnancePdf(
            patient: _currentPatient,
            weight: weight,
            prescriptionText: _prescriptionsFieldController.text,
            template: _selectedTemplate,
            includeDate: _includeDateInOrdonnance,
            date: _prescriptionDate,
          ),
        );
      },
      icon: const Icon(Icons.visibility),
      label: const Text('Preview'),
    );

    final blankOrdonnanceBtn = OutlinedButton.icon(
      onPressed: _printBlankOrdonnance,
      icon: const Icon(Icons.note_alt_outlined),
      label: const Text('Blank Ordonnance'),
    );

    final printBtn = OutlinedButton.icon(
      onPressed: _printOrdonnance,
      icon: const Icon(Icons.print),
      label: const Text('Print'),
    );

    final saveBtn = ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              widget.recordToEdit != null ? 'Save Changes' : 'Create Record',
            ),
    );

    final cancelBtn = TextButton(
      onPressed: _requestClose,
      child: const Text('Cancel'),
    );

    if (small) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTemplateSelector(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [cancelBtn, blankOrdonnanceBtn, previewBtn, printBtn, saveBtn],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildTemplateSelector(),
        const Spacer(),
        cancelBtn,
        const SizedBox(width: 8),
        blankOrdonnanceBtn,
        const SizedBox(width: 8),
        previewBtn,
        const SizedBox(width: 8),
        printBtn,
        const SizedBox(width: 8),
        saveBtn,
      ],
    );
  }

  // ── certificate button helper ────────────────────────────────────────────────

  Widget _certButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  Widget _buildPosologyRecommendation() {
    if (_isScrapingPosology) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.shade200, width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Recherche de la posologie sur Vidal...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.teal.shade900,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedMedic == null) return const SizedBox.shrink();

    final age = _currentPatient.age;
    final weightText = _weightController.text.trim();
    final weight = double.tryParse(weightText);

    final isChild = age < 15 || (weight != null && weight < 40);

    String? recommendationText;
    String titleText = 'Posologie Recommandée';
    String? formulaText;
    String? calculatedDose;

    if (isChild) {
      titleText = 'Posologie Pédiatrique Recommandée';
      final rawPediatrique = _selectedMedic!['posologie_pediatrique']?.toString() ?? '';
      final formula = _selectedMedic!['posologie']?.toString() ?? '';

      if (formula.isNotEmpty && weight != null) {
        calculatedDose = Formatters.calculatePosologyProposition(
          posoText: formula,
          weight: weight,
        );
        if (calculatedDose != null) {
          recommendationText = 'Dose calculée : $calculatedDose';
          formulaText = 'Standard : $formula';
        }
      }

      if (recommendationText == null && rawPediatrique.isNotEmpty) {
        recommendationText = rawPediatrique;
      }
    } else {
      titleText = 'Posologie Adulte Recommandée';
      final rawAdulte = _selectedMedic!['posologie_adulte']?.toString() ?? '';
      if (rawAdulte.isNotEmpty) {
        recommendationText = rawAdulte;
      }
    }

    if (recommendationText == null || recommendationText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: Colors.teal.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.teal.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendationText,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.teal.shade800,
                  ),
                ),
                if (formulaText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formulaText,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.teal.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (calculatedDose != null) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final cleanedDose = calculatedDose!.replaceAll(' mg/jour', '');
                setState(() {
                  _posologyController.text = '$cleanedDose mg/jour';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              child: const Text('Appliquer'),
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _showInsuranceNumberDialog(BuildContext context, String currentVal) async {
    final controller = TextEditingController(text: currentVal);
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Numéro d\'assurance requis'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Le lecteur de carte CHIFA n\'est pas connecté ou la carte n\'est pas détectée. Veuillez saisir le numéro d\'assurance du patient pour effectuer une recherche à distance.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Numéro d\'assurance (N° Sécurité Sociale)',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: 630026048450',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir un numéro valide.';
                    }
                    if (value.trim().length < 8) {
                      return 'Le numéro est trop court.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _updatePatientNationalId(String nationalId) async {
    try {
      final updatedPatient = _currentPatient.copyWith(nationalId: nationalId);
      final repo = PatientRepository();
      final result = await repo.update(_currentPatient.patientId!, updatedPatient);
      return result.fold(
        (failure) => false,
        (success) {
          if (success) {
            setState(() {
              _currentPatient = updatedPatient;
            });
            return true;
          }
          return false;
        },
      );
    } catch (e) {
      return false;
    }
  }
}

