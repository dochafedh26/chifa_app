import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/screens/medical_records/medical_record_form_dialog_for_patient.dart';
import 'package:chifa/app/screens/medical_records/patient_medical_records_list_dialog.dart';
import 'package:chifa/app/screens/patients/patient_form_dialog.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/repositories/medical_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedStars;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    context.read<PatientCubit>().loadPatients();
    context.read<PatientCubit>().loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return BlocBuilder<PatientCubit, PatientState>(
      builder: (context, state) {
        return Column(
          children: [
            // Search and Filter Bar
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: isMobile
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search patients...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_month),
                                      onPressed: () => _showDatePicker(context),
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    context.read<PatientCubit>().searchPatients(
                                      value,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.blue,
                                  size: 32,
                                ),
                                onPressed: () => _showAddPatientDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    hint: const Text('Stars'),
                                    value: _selectedStars,
                                    onChanged: (stars) {
                                      setState(() => _selectedStars = stars);
                                      if (stars != null) {
                                        context
                                            .read<PatientCubit>()
                                            .getPatientsByFidelity(stars);
                                      } else {
                                        context
                                            .read<PatientCubit>()
                                            .loadPatients();
                                      }
                                    },
                                    items: [
                                      const DropdownMenuItem<int>(
                                        value: null,
                                        child: Text('All Stars'),
                                      ),
                                      ...List.generate(
                                        5,
                                        (index) => DropdownMenuItem<int>(
                                          value: index + 1,
                                          child: Row(
                                            children: List.generate(
                                              index + 1,
                                              (i) => const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: const Text('Category'),
                                    value: _selectedCategoryFilter,
                                    onChanged: (category) {
                                      setState(
                                        () =>
                                            _selectedCategoryFilter = category,
                                      );
                                      if (category != null) {
                                        context
                                            .read<PatientCubit>()
                                            .getPatientsBySuiviCategory(
                                              category,
                                            );
                                      } else {
                                        context
                                            .read<PatientCubit>()
                                            .loadPatients();
                                      }
                                    },
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('All Categories'),
                                      ),
                                      ...state.categories.map(
                                        (c) => DropdownMenuItem<String>(
                                          value: c,
                                          child: Text(
                                            c,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: () =>
                                    context.read<PatientCubit>().loadPatients(),
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
                                labelText: 'Search patients...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_month),
                                  onPressed: () => _showDatePicker(context),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                context.read<PatientCubit>().searchPatients(
                                  value,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              context.read<PatientCubit>().loadPatients();
                            },
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<int>(
                            hint: const Text('Filter by Stars'),
                            value: _selectedStars,
                            onChanged: (stars) {
                              setState(() {
                                _selectedStars = stars;
                              });
                              if (stars != null) {
                                context
                                    .read<PatientCubit>()
                                    .getPatientsByFidelity(stars);
                              } else {
                                context.read<PatientCubit>().loadPatients();
                              }
                            },
                            items: [
                              const DropdownMenuItem<int>(
                                value: null,
                                child: Text('All Patients'),
                              ),
                              ...List.generate(5, (index) {
                                final stars = index + 1;
                                return DropdownMenuItem<int>(
                                  value: stars,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(stars, (i) {
                                      return const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            hint: const Text('Filter by Category'),
                            value: _selectedCategoryFilter,
                            onChanged: (category) {
                              setState(() {
                                _selectedCategoryFilter = category;
                              });
                              if (category != null) {
                                context
                                    .read<PatientCubit>()
                                    .getPatientsBySuiviCategory(category);
                              } else {
                                context.read<PatientCubit>().loadPatients();
                              }
                            },
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Categories'),
                              ),
                              ...state.categories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddPatientDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Patient'),
                          ),
                        ],
                      ),
              ),
            ),

            // Patient List
            Expanded(child: _buildStateContent(state)),
          ],
        );
      },
    );
  }

  Widget _buildStateContent(PatientState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<PatientCubit>().loadPatients(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.patients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No patients found', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return _buildPatientList(state.patients);
  }

  Widget _buildPatientList(List<Patient> patients) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            radius: 20,
                            child: Text(
                              patient.firstName[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patient.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildLoyaltyStars(patient.medicalRecordsCount),
                              ],
                            ),
                          ),
                          _buildMobileActionMenu(context, patient),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildInfoBadge(
                            Icons.cake_outlined,
                            '${patient.age} yrs',
                          ),
                          _buildInfoBadge(
                            patient.gender.name == 'Male'
                                ? Icons.male
                                : Icons.female,
                            patient.gender.name,
                          ),
                          if (patient.phone != null &&
                              patient.phone!.isNotEmpty)
                            _buildInfoBadge(
                              Icons.phone_outlined,
                              patient.phone!,
                            ),
                        ],
                      ),
                      if (patient.categories.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: patient.categories.map((cat) {
                            return _buildCategoryChip(context, cat);
                          }).toList(),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        radius: 24,
                        child: Text(
                          patient.firstName[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (patient.categories.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: patient.categories.map((cat) {
                                  return _buildCategoryChip(context, cat);
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 4),
                            _buildLoyaltyStars(patient.medicalRecordsCount),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                _buildInfoBadge(
                                  Icons.cake_outlined,
                                  '${patient.age} yrs',
                                ),
                                _buildInfoBadge(
                                  patient.gender.name == 'Male'
                                      ? Icons.male
                                      : Icons.female,
                                  patient.gender.name,
                                ),
                                if (patient.phone != null &&
                                    patient.phone!.isNotEmpty)
                                  _buildInfoBadge(
                                    Icons.phone_outlined,
                                    patient.phone!,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(
                            icon: Icons.folder_shared_outlined,
                            color: Colors.blue,
                            tooltip: 'View Records',
                            onPressed: () =>
                                _showPatientRecordsDialog(context, patient),
                          ),
                          const SizedBox(width: 4),
                          _buildActionButton(
                            icon: Icons.note_add_outlined,
                            color: Colors.teal,
                            tooltip: 'Add Record',
                            onPressed: () =>
                                _showAddRecordDialog(context, patient),
                          ),
                          const SizedBox(width: 4),
                          _buildActionButton(
                            icon: Icons.edit_outlined,
                            color: Colors.black54,
                            tooltip: 'Edit',
                            onPressed: () =>
                                _showEditPatientDialog(context, patient),
                          ),
                          const SizedBox(width: 4),
                          _buildActionButton(
                            icon: Icons.delete_outline,
                            color: Colors.red,
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(context, patient),
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

  Widget _buildCategoryChip(BuildContext context, String cat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        cat,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildMobileActionMenu(BuildContext context, Patient patient) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'records':
            _showPatientRecordsDialog(context, patient);
            break;
          case 'add_record':
            _showAddRecordDialog(context, patient);
            break;
          case 'edit':
            _showEditPatientDialog(context, patient);
            break;
          case 'delete':
            _confirmDelete(context, patient);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'records',
          child: ListTile(
            leading: Icon(Icons.folder_shared_outlined, color: Colors.blue),
            title: Text('View Records'),
          ),
        ),
        const PopupMenuItem(
          value: 'add_record',
          child: ListTile(
            leading: Icon(Icons.note_add_outlined, color: Colors.teal),
            title: Text('Add Record'),
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit Patient'),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Delete Patient'),
          ),
        ),
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      if (!context.mounted) return;
      String formattedDate =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
      setState(() {
        _searchController.text = formattedDate;
      });
      context.read<PatientCubit>().searchPatients(formattedDate);
    }
  }

  Widget _buildLoyaltyStars(int count) {
    if (count == 0) return const SizedBox.shrink();

    // Mapping: Linear mapping up to 10 records for 5 stars.
    // 1-2 records: 1 star
    // 3-4 records: 2 stars
    // ...
    // 9-10+ records: 5 stars
    int stars = ((count + 1) / 2).floor().clamp(1, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => PatientFormDialog(
        onSave: (patient) {
          context.read<PatientCubit>().createPatient(patient);
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showEditPatientDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (dialogContext) => PatientFormDialog(
        patient: patient,
        onSave: (updatedPatient) {
          context.read<PatientCubit>().updatePatient(
            patient.patientId!,
            updatedPatient,
          );
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text('Are you sure you want to delete ${patient.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<PatientCubit>().deletePatient(patient.patientId!);
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context, Patient patient) {
    final tabId = 'new_record_patient_${patient.patientId}';
    context.read<WorkspaceCubit>().openTab(
      WorkspaceTab(
        id: tabId,
        title: 'New: ${patient.fullName}',
        content: BlocProvider(
          create: (context) =>
              MedicalRecordCubit(context.read<MedicalRecordRepository>()),
          child: MedicalRecordFormDialogForPatient(
            patient: patient,
            tabId: tabId,
          ),
        ),
      ),
    );
  }

  void _showPatientRecordsDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<MedicalRecordCubit>(),
        child: PatientMedicalRecordsListDialog(patient: patient),
      ),
    );
  }
}
