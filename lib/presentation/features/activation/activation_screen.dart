import 'package:flutter/material.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/services/activation/activation_service.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;

  const ActivationScreen({super.key, required this.onActivated});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _machineId;

  @override
  void initState() {
    super.initState();
    _loadMachineId();
  }

  Future<void> _loadMachineId() async {
    final id = await ActivationService.instance.getMachineId();
    if (mounted) {
      setState(() => _machineId = id);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final key = _keyController.text.trim();
    final result = await ActivationService.instance.verifyAndActivate(key);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isLoading = false;
        _successMessage = result['message'] ?? 'Poste activé avec succès !';
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        widget.onActivated();
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['error'] ?? "Échec de l'activation.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: Card(
                elevation: 16,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 24.0 : 40.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Shield & Caduceus icon
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'Activation du Poste',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'Ce terminal doit être activé auprès du Cloud de la clinique avant la première utilisation.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          // License Key Input
                          TextFormField(
                            controller: _keyController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: "Clé d'activation Établissement",
                              hintText: 'CHIFA-XXXX-XXXX',
                              prefixIcon: const Icon(Icons.key_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Veuillez saisir votre clé d'activation";
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleActivation(),
                          ),
                          const SizedBox(height: 16),

                          // Success / Error Alerts
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_successMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _successMessage!,
                                      style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _handleActivation,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_open_rounded, size: 20),
                                        SizedBox(width: 8),
                                        Text('Activer ce terminal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Machine Fingerprint Info
                          if (_machineId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.devices_rounded, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ID Machine : $_machineId',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
