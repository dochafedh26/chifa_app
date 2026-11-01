import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/screens/auth/signup_dialog.dart';
import 'package:chifa/app/screens/database/database_selection_screen.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:chifa/presentation/features/activation/activation_screen.dart';
import 'package:chifa/services/activation/activation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isActivated = true;
  bool _checkingActivation = true;

  @override
  void initState() {
    super.initState();
    _checkActivationAndCredentials();
  }

  Future<void> _checkActivationAndCredentials() async {
    final activated = await ActivationService.instance.isActivated();
    if (mounted) {
      setState(() {
        _isActivated = activated;
        _checkingActivation = false;
      });
    }
    await _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (rememberMe) {
      setState(() {
        _rememberMe = true;
        _emailController.text = prefs.getString('email') ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('email', email);
        await prefs.setString('password', password);
      } else {
        await prefs.setBool('remember_me', false);
        await prefs.remove('email');
        await prefs.remove('password');
      }

      if (mounted) {
        context.read<AuthCubit>().login(email, password);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    if (_checkingActivation) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isActivated) {
      return ActivationScreen(
        onActivated: () {
          setState(() {
            _isActivated = true;
          });
        },
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo and Title
                          Icon(
                            Icons.local_hospital,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Clinic Management',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 32),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Remember Me Checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                              const Text('Remember me'),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          BlocListener<AuthCubit, AuthState>(
                            listener: (context, state) {
                              if (state is AuthError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(state.message),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: BlocBuilder<AuthCubit, AuthState>(
                              builder: (context, state) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: state is AuthLoading
                                        ? null
                                        : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: state is AuthLoading
                                        ? const CircularProgressIndicator()
                                        : Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 16 * AppTheme.fontScale,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 14),
                          isMobile ?
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Nouveau praticien ?",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const SignupDialog(),
                                  );
                                },
                                child: const Text(
                                  "Créer un compte",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Nouveau praticien ?",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const SignupDialog(),
                                  );
                                },
                                child: const Text(
                                  "Créer un compte",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DatabaseSelectionScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.storage),
                            label: const Text('Change Database Connection'),
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
