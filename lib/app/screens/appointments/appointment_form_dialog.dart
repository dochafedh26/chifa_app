import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/doctor_working_hours_cubit.dart';
import 'package:chifa/app/printing/appointment_pdf.dart';
import 'package:chifa/app/printing/preview.dart';
import 'package:chifa/app/screens/appointments/pvc_appointment_card_dialog.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/models/appointment.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AppointmentFormDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Function(Appointment) onSave;

  const AppointmentFormDialog({
    super.key,
    required this.selectedDate,
    required this.onSave,
  });

  @override
  State<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _doctorController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _notesController;
  AppointmentStatus _selectedStatus = AppointmentStatus.scheduled;
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  Patient? _selectedPatient;
  String? _doctorId;
  List<Employee> _availableDoctors = [];
  bool _isLoadingDoctors = false;

  @override
  void initState() {
    super.initState();
    _doctorController = TextEditingController();
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _notesController = TextEditingController();

    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;
    final isDoctor = authCubit.isDoctor;

    if (isDoctor && user != null) {
      _doctorController.text = '${user.firstName} ${user.lastName}';
      _doctorId = user.employeeId.toString();
    } else {
      _loadDoctors();
    }
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoadingDoctors = true);
    try {
      final results = await DatabaseManager.instance.query(
        "SELECT * FROM employees WHERE (LOWER(role) = 'doctor' OR LOWER(role) = 'admin') AND is_active = 1",
      );
      final doctors = results.map((r) => Employee.fromMap(r)).toList();
      if (mounted) {
        setState(() {
          _availableDoctors = doctors;
          _isLoadingDoctors = false;
          if (doctors.isNotEmpty) {
            _doctorId = doctors.first.employeeId.toString();
            _doctorController.text = '${doctors.first.firstName} ${doctors.first.lastName}';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDoctors = false);
    }
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = isMobile ? screenWidth - 48 : 400.0;

    return AlertDialog(
      title: const Text('New Appointment'),
      contentPadding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        20,
        isMobile ? 16 : 24,
        0,
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Autocomplete<Patient>(
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Patient>.empty();
                    }
                    final db = DatabaseManager.instance;
                    final results = await db.query(
                      'SELECT * FROM patients WHERE first_name LIKE ? OR last_name LIKE ?',
                      [
                        '%${textEditingValue.text}%',
                        '%${textEditingValue.text}%',
                      ],
                    );
                    final List<Patient> patients = [];
                    for (final row in results) {
                      patients.add(Patient.fromMap(row));
                    }
                    return patients;
                  },
                  displayStringForOption: (Patient option) =>
                      '${option.firstName} ${option.lastName}',
                  onSelected: (Patient selection) {
                    setState(() {
                      _selectedPatient = selection;
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Search Patient by Name *',
                            prefixIcon: Icon(Icons.search),
                          ),
                          validator: (v) => _selectedPatient == null
                              ? 'Please select a patient'
                              : null,
                          onChanged: (v) {
                            if (_selectedPatient != null &&
                                v !=
                                    '${_selectedPatient!.firstName} ${_selectedPatient!.lastName}') {
                              setState(() => _selectedPatient = null);
                            }
                          },
                        );
                      },
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final isDoctor = context.read<AuthCubit>().isDoctor;
                    if (!isDoctor) {
                      if (_isLoadingDoctors) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final validDoctors = _availableDoctors
                          .where((d) => d.employeeId != null)
                          .toList();
                      return DropdownButtonFormField<String>(
                        initialValue: validDoctors.any(
                              (d) => d.employeeId.toString() == _doctorId,
                            )
                            ? _doctorId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Médecin affecté *',
                          prefixIcon: Icon(Icons.medical_services),
                        ),
                        items: validDoctors.map((doc) {
                          final label = isMobile
                              ? 'Dr. ${doc.firstName}'
                              : 'Dr. ${doc.fullName}';
                          return DropdownMenuItem<String>(
                            value: doc.employeeId!.toString(),
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _doctorId = val;
                              final match = validDoctors.firstWhere(
                                (d) => d.employeeId!.toString() == val,
                              );
                              _doctorController.text =
                                  '${match.firstName} ${match.lastName}';
                            });
                          }
                        },
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Médecin requis' : null,
                      );
                    }
                    return TextFormField(
                      controller: _doctorController,
                      decoration: const InputDecoration(
                        labelText: 'Doctor *',
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                      readOnly: true,
                      validator: (v) => _doctorId == null || _doctorId!.isEmpty
                          ? 'Doctor is required'
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date *',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: _selectDate,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time *',
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  readOnly: true,
                  onTap: _selectTime,
                  validator: (v) => _selectedTime == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AppointmentStatus>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: AppointmentStatus.values.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.label));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: isMobile ? 2 : 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        isMobile ? 8 : 24,
        8,
        isMobile ? 8 : 24,
        isMobile ? 12 : 16,
      ),
      actions: isMobile
          ? [
              // Row 1 (mobile): secondary actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.badge_outlined,
                        color: Color(0xFF0F5B9E), size: 16),
                    label: const Text('PVC', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleSave(printPvc: true),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleSave(shouldPrint: true),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
              // Row 2 (mobile): primary actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleSave(shouldPrint: false),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.badge_outlined, color: Color(0xFF0F5B9E)),
                label: const Text('Carte PVC'),
                onPressed: () => _handleSave(printPvc: true),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.print_outlined),
                label: const Text('Save & Print'),
                onPressed: () => _handleSave(shouldPrint: true),
              ),
              ElevatedButton(
                onPressed: () => _handleSave(shouldPrint: false),
                child: const Text('Create'),
              ),
            ],
    );
  }

  Future<void> _handleSave({bool shouldPrint = false, bool printPvc = false}) async {
    if (_formKey.currentState!.validate() &&
        _selectedTime != null &&
        _selectedPatient != null &&
        _doctorId != null) {
      final appointmentDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final doctorIdInt = int.parse(_doctorId!);
      final isAvailable = await context
          .read<DoctorWorkingHoursCubit>()
          .checkAvailability(doctorIdInt, appointmentDate);

      if (!mounted) return;

      if (!isAvailable) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Outside Working Hours'),
            content: const Text(
              'This appointment is outside the doctor\'s working hours for this day. Do you want to proceed anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (confirm != true) return;
      }

      final appointment = Appointment(
        patientId: _selectedPatient!.patientId!,
        doctorId: doctorIdInt,
        appointmentDate: appointmentDate,
        status: _selectedStatus,
        notes: _notesController.text.isEmpty
            ? null
            : _notesController.text,
      );

      widget.onSave(appointment);

      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
        if (printPvc) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (navigator.mounted) {
              PvcAppointmentCardDialog.show(
                context: navigator.context,
                patient: _selectedPatient!,
                appointment: appointment,
              );
            }
          });
        } else if (shouldPrint) {
          final pdfBytes = generateAppointmentPdf(
            patient: _selectedPatient!,
            appointment: appointment,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (navigator.mounted) {
              showPdfPreview(context: navigator.context, generatedPdfBytes: pdfBytes);
            }
          });
        }
      }
    }
  }
}
