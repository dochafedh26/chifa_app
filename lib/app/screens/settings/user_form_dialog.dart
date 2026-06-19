import 'package:chifa/app/cubits/settings_cubit.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// User Form Dialog - Create new user
class UserFormDialog extends StatefulWidget {
  final Employee? employee;

  const UserFormDialog({super.key, this.employee});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late final TextEditingController _specializationController;

  late EmployeeRole _role;
  late AccessLevel _accessLevel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.employee?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.employee?.lastName ?? '',
    );
    _emailController = TextEditingController(
      text: widget.employee?.email ?? '',
    );
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(
      text: widget.employee?.phone ?? '',
    );
    _specializationController = TextEditingController(
      text: widget.employee?.specialization ?? '',
    );

    _role = widget.employee?.role ?? EmployeeRole.nurse;
    _accessLevel = widget.employee?.accessLevel ?? AccessLevel.nurse;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = Employee(
      employeeId: widget.employee?.employeeId,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      role: _role,
      email: _emailController.text,
      password: _passwordController.text.isEmpty
          ? (widget.employee?.password ?? '')
          : _passwordController.text,
      accessLevel: _accessLevel,
      phone: _phoneController.text.isEmpty ? null : _phoneController.text,
      specialization: _specializationController.text.isEmpty
          ? null
          : _specializationController.text,
    );

    if (widget.employee != null) {
      context.read<SettingsCubit>().updateUser(
        widget.employee!.employeeId!,
        user,
      );
    } else {
      context.read<SettingsCubit>().createUser(user);
    }
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
        } else if (state is SettingsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: AlertDialog(
        title: Text(widget.employee != null ? 'Edit User' : 'Add New User'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name fields
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: widget.employee != null
                          ? 'Password (leave blank to keep current)'
                          : 'Password *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (widget.employee == null) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                      } else if (value != null &&
                          value.isNotEmpty &&
                          value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Role and Access Level
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<EmployeeRole>(
                          initialValue: _role,
                          decoration: const InputDecoration(
                            labelText: 'Role *',
                            border: OutlineInputBorder(),
                          ),
                          items: EmployeeRole.values.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(_formatRole(role)),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _role = value!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<AccessLevel>(
                          initialValue: _accessLevel,
                          decoration: const InputDecoration(
                            labelText: 'Access Level *',
                            border: OutlineInputBorder(),
                          ),
                          items: AccessLevel.values.map((level) {
                            return DropdownMenuItem(
                              value: level,
                              child: Text(_formatRole(level)),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _accessLevel = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Specialization
                  TextFormField(
                    controller: _specializationController,
                    decoration: const InputDecoration(
                      labelText: 'Specialization',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
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
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.employee != null ? 'Update User' : 'Create User'),
          ),
        ],
      ),
    );
  }

  String _formatRole(dynamic role) {
    final name = role.toString().split('.').last;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }
}
