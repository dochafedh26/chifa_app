import 'package:flutter/material.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:chifa/services/db/repositories/auth_repository.dart';

class SignupDialog extends StatefulWidget {
  const SignupDialog({super.key});

  @override
  State<SignupDialog> createState() => _SignupDialogState();
}

class _SignupDialogState extends State<SignupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  EmployeeRole _selectedRole = EmployeeRole.doctor;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newEmployee = Employee(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      role: _selectedRole,
      specialization: _specializationController.text.trim().isNotEmpty
          ? _specializationController.text.trim()
          : null,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      password: _passwordController.text,
      accessLevel: AccessLevel.doctor,
      isActive: false, // Default pending approval
    );

    final result = await AuthRepository().registerPendingEmployee(newEmployee);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (id) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, size: 44, color: Colors.green.shade600),
              ),
              const SizedBox(height: 18),
              const Text(
                'Compte créé avec succès !',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Votre demande a été enregistrée. Pour des motifs de confidentialité médicale, votre compte doit être validé par l'administrateur de l'établissement avant votre première connexion.",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Compris', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Créer un Compte Praticien',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Le compte sera soumis à l'approbation de l'administrateur de la clinique.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 12))),
                      ],
                    ),
                  ),
                ],

                // Name fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'Prénom *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Role and Specialization
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<EmployeeRole>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(labelText: 'Rôle *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: EmployeeRole.doctor, child: Text('Médecin')),
                          DropdownMenuItem(value: EmployeeRole.nurse, child: Text('Infirmier(ère)')),
                        ],
                        onChanged: (role) {
                          if (role != null) setState(() => _selectedRole = role);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _specializationController,
                        decoration: const InputDecoration(
                          labelText: 'Spécialité (ex: Généraliste)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Email & Phone
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de Téléphone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Password Fields
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe *',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (v.length < 6) return 'Au moins 6 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe *',
                    prefixIcon: Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Créer mon compte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

