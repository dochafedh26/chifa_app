import 'package:chifa/services/db/models/patient.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PatientFormDialog extends StatefulWidget {
  final Patient? patient;
  final Function(Patient) onSave;

  const PatientFormDialog({super.key, this.patient, required this.onSave});

  @override
  State<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<PatientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _nationalIdController;
  late TextEditingController _addressController;
  late TextEditingController _atcdController;
  late TextEditingController _dobController;
  Gender _selectedGender = Gender.male;
  PatientStatus _selectedStatus = PatientStatus.waiting;
  List<String> _selectedCategories = [];
  late TextEditingController _suiviPathologiesController;
  late TextEditingController _categoryController;
  DateTime? _selectedDob;

  final List<String> _categories = [
    // Maladies cardiovasculaires
    "Infarctus du myocarde",
    "Angine de poitrine",
    "Insuffisance cardiaque",
    "Phlébite",
    "Embolie pulmonaire",
    "Hypertension artérielle",
    "Hypercholestérolémie",
    "Troubles du rythme cardiaque",
    "Valvulopathie",

    // Cancers
    "Cancers du cerveau",
    "Cancer du col de l'utérus",
    "Cancer du colon",
    "Cancer de l'estomac",
    "Cancer du foie",
    "Cancer de la prostate",
    "Cancer de l'ovaire",
    "Cancer des os",
    "Cancer du poumon",
    "Cancer du rein",
    "Cancer du sein",
    "Cancer de la thyroïde",

    // Maladies endocriniennes
    "Diabète",
    "Hyperthyroïdie",
    "Hypothyroïdie",
    "Obésité",
    "Syndrome de Cushing",

    // Maladies respiratoires et ORL
    "Asthme",
    "Bronchite chronique",
    "Broncho pneumopathie chronique obstructive (BPCO)",
    "Emphysème",
    "Apnée du sommeil",
    "Mucoviscidose",
    "Pneumopathie",
    "Rhinite chronique",
    "Sinusite chronique",

    // Maladies digestives
    "Ulcère gastro duodénal",
    "Gastrite chronique",
    "Maladie de Crohn",
    "Reflux gastro œsophagien",
    "Côlon irritable",
    "Maladie cœliaque",
    "Rectocolite hémorragique",
    "Cirrhose",

    // Maladies rhumatologiques
    "Arthrose",
    "Hernie discale",
    "Sciatique",
    "Lombalgie",
    "Fibromyalgie",
    "Tendinite chronique",
    "Ostéoporose",
    "Scoliose",

    // Maladies neurologiques et musculaires
    "Sclérose en plaques",
    "Céphalées chroniques",
    "Épilepsie",
    "Maladie d'Alzheimer",
    "Maladie de Parkinson",
    "Démence",
    "Algie vasculaire de la face",
    "Accident vasculaire cérébral",

    // Maladies gynécologiques, urinaires ou rénales
    "Endométriose",
    "Insuffisance rénale",
    "Incontinence urinaire",
    "Fibrome utérin",
    "Kyste ovarien",
    "Trouble de la fertilité",
    "Adénome de la prostate",
    "Calculs rénaux",
    "Trouble érectile",

    // Maladies de la peau
    "Acné",
    "Eczéma",
    "Urticaire",
    "Psoriasis",
    "Vitiligo",
    "Zona",
    "Herpès",

    // Maladies hématologiques
    "Leucémie",
    "Lymphome",
    "Déficit immunitaire",

    // Maladies chroniques transmissibles
    "VIH/Sida",
    "Hépatite C",
    "Hépatite B",
    "Maladie de Lyme",
    "Tuberculose",

    // Maladies rares (Doublons retirés)
    "Myopathies",
    "Hémophilie",
    "Drépanocytose",
    "Maladie de Paget",
    "Syndrome de Guillain Barré",
    "Lupus",
    "Maladie de Hodgkin",
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.patient?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.patient?.lastName ?? '',
    );
    _phoneController = TextEditingController(text: widget.patient?.phone ?? '');
    _emailController = TextEditingController(text: widget.patient?.email ?? '');
    _nationalIdController = TextEditingController(
      text: widget.patient?.nationalId ?? '',
    );
    _addressController = TextEditingController(
      text: widget.patient?.address ?? '',
    );
    _atcdController = TextEditingController(text: widget.patient?.atcd ?? '');
    _selectedDob = widget.patient?.dateOfBirth;
    _dobController = TextEditingController(
      text: widget.patient?.dateOfBirth != null
          ? DateFormat('yyyy-MM-dd').format(widget.patient!.dateOfBirth)
          : '',
    );
    if (widget.patient != null) {
      _selectedGender = widget.patient!.gender;
      _selectedStatus = widget.patient!.status;
      _selectedCategories = List.from(widget.patient!.categories);
    }
    _suiviPathologiesController = TextEditingController(
      text: widget.patient?.suiviPathologies ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.patient?.categories.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    _atcdController.dispose();
    _dobController.dispose();
    _suiviPathologiesController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.patient != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Patient' : 'Add New Patient'),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // First Name & Last Name
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                // Date of Birth & Gender
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: TextFormField(
                        controller: _dobController,
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth *',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: _selectDate,
                        validator: (v) =>
                            _selectedDob == null ? 'Required' : null,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: DropdownButtonFormField<Gender>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender *',
                        ),
                        items: Gender.values.map((g) {
                          return DropdownMenuItem(
                            value: g,
                            child: Text(g.name),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedGender = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Phone & Email
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // National ID & Status
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: TextFormField(
                        controller: _nationalIdController,
                        decoration: const InputDecoration(
                          labelText: 'National ID',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 500
                          ? double.infinity
                          : (MediaQuery.of(context).size.width * 0.95 - 48) / 2,
                      child: DropdownButtonFormField<PatientStatus>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: PatientStatus.values.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // Medical History (ATCD)
                TextFormField(
                  controller: _atcdController,
                  decoration: const InputDecoration(
                    labelText: 'Medical History (ATCD)',
                    hintText: 'Past medical conditions, allergies, etc.',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Follow-up Information (Suivi)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Category selection with Multi-select Chips
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return _categories.where((String option) {
                          return option.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ) &&
                              !_selectedCategories.contains(option);
                        });
                      },
                      onSelected: (String selection) {
                        setState(() {
                          if (!_selectedCategories.contains(selection)) {
                            _selectedCategories.add(selection);
                          }
                          _categoryController.clear();
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Add Category',
                                prefixIcon: Icon(Icons.category_outlined),
                                hintText: 'Search for pathology...',
                              ),
                              onFieldSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  setState(() {
                                    if (!_selectedCategories.contains(value)) {
                                      _selectedCategories.add(value);
                                    }
                                    controller.clear();
                                  });
                                }
                              },
                            );
                          },
                    ),
                    if (_selectedCategories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _selectedCategories.map((category) {
                          return InputChip(
                            label: Text(category),
                            onDeleted: () {
                              setState(() {
                                _selectedCategories.remove(category);
                              });
                            },
                            deleteIconColor: Colors.red[300],
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Suivi Pathologies
                TextFormField(
                  controller: _suiviPathologiesController,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Pathologies',
                    hintText: 'Specific conditions being monitored...',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedDob != null) {
              widget.onSave(
                Patient(
                  patientId: widget.patient?.patientId,
                  firstName: _firstNameController.text,
                  lastName: _lastNameController.text,
                  gender: _selectedGender,
                  dateOfBirth: _selectedDob!,
                  phone: _phoneController.text.isEmpty
                      ? null
                      : _phoneController.text,
                  atcd: _atcdController.text,
                  email: _emailController.text.isEmpty
                      ? null
                      : _emailController.text,
                  nationalId: _nationalIdController.text.isEmpty
                      ? null
                      : _nationalIdController.text,
                  address: _addressController.text.isEmpty
                      ? null
                      : _addressController.text,
                  status: _selectedStatus,
                  categories: _selectedCategories,
                  suiviPathologies: _suiviPathologiesController.text.isEmpty
                      ? null
                      : _suiviPathologiesController.text,
                ),
              );
            }
          },
          child: Text(isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
