import 'package:chifa/app/cubits/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Clinic Settings Dialog - Configure clinic information
class ClinicSettingsDialog extends StatefulWidget {
  const ClinicSettingsDialog({super.key});

  @override
  State<ClinicSettingsDialog> createState() => _ClinicSettingsDialogState();
}

class _ClinicSettingsDialogState extends State<ClinicSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _clinicNameController;
  late TextEditingController _clinicAddressController;
  late TextEditingController _clinicPhoneController;
  late TextEditingController _clinicEmailController;
  late TextEditingController _doctorNameController;
  late TextEditingController _doctorSpecializationController;
  late TextEditingController _taxIdController;

  String _currency = 'DZD';
  String _language = 'fr';
  String _theme = 'light';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsCubit>().settings;
    _clinicNameController = TextEditingController(text: settings.clinicName);
    _clinicAddressController = TextEditingController(
      text: settings.clinicAddress,
    );
    _clinicPhoneController = TextEditingController(text: settings.clinicPhone);
    _clinicEmailController = TextEditingController(text: settings.clinicEmail);
    _doctorNameController = TextEditingController(text: settings.doctorName);
    _doctorSpecializationController = TextEditingController(
      text: settings.doctorSpecialization,
    );
    _taxIdController = TextEditingController(text: settings.taxId);
    _currency = settings.currency;
    _language = settings.language;
    _theme = settings.theme;
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    _clinicEmailController.dispose();
    _doctorNameController.dispose();
    _doctorSpecializationController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final settings = ClinicSettings(
      clinicName: _clinicNameController.text,
      clinicAddress: _clinicAddressController.text,
      clinicPhone: _clinicPhoneController.text,
      clinicEmail: _clinicEmailController.text,
      doctorName: _doctorNameController.text,
      doctorSpecialization: _doctorSpecializationController.text,
      taxId: _taxIdController.text,
      currency: _currency,
      language: _language,
      theme: _theme,
    );

    context.read<SettingsCubit>().updateClinicInfo(settings);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listener: (context, state) {
        setState(() => _isLoading = false);
        if (state is SettingsOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      },
      child: AlertDialog(
        title: const Text('Clinic Settings'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Clinic Info
                  Text(
                    'Clinic Information',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clinicNameController,
                    decoration: const InputDecoration(
                      labelText: 'Clinic Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Clinic name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clinicAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _clinicPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _clinicEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Doctor Info
                  Text(
                    'Doctor Information',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _doctorNameController,
                    decoration: const InputDecoration(
                      labelText: 'Doctor Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_services),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _doctorSpecializationController,
                    decoration: const InputDecoration(
                      labelText: 'Specialization',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taxIdController,
                    decoration: const InputDecoration(
                      labelText: 'Tax ID / NIF',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preferences
                  Text(
                    'Preferences',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'DZD',
                        child: Text('DZD - Algerian Dinar'),
                      ),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('USD - US Dollar'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _currency = value!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) => setState(() => _language = value!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _theme,
                    decoration: const InputDecoration(
                      labelText: 'Theme',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.palette),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                      DropdownMenuItem(
                        value: 'system',
                        child: Text('System Default'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _theme = value!),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
