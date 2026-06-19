import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/doctor_working_hours_cubit.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/models/appointment.dart';
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
    if (user != null) {
      _doctorController.text = '${user.firstName} ${user.lastName}';
      _doctorId = user.employeeId.toString();
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
    return AlertDialog(
      title: const Text('New Appointment'),
      content: SizedBox(
        width: 400,
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
              TextFormField(
                controller: _doctorController,
                decoration: const InputDecoration(
                  labelText: 'Doctor *',
                  prefixIcon: Icon(Icons.medical_services),
                ),
                readOnly: true,
                validator: (v) => _doctorId == null || _doctorId!.isEmpty
                    ? 'Doctor is required'
                    : null,
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
                  return DropdownMenuItem(value: s, child: Text(s.name));
                }).toList(),
                onChanged: (v) => setState(() => _selectedStatus = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
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

                if (confirm != true) return;
              }

              widget.onSave(
                Appointment(
                  patientId: _selectedPatient!.patientId!,
                  doctorId: doctorIdInt,
                  appointmentDate: appointmentDate,
                  status: _selectedStatus,
                  notes: _notesController.text.isEmpty
                      ? null
                      : _notesController.text,
                ),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
