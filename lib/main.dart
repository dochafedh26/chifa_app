import 'dart:io';

import 'package:chifa/app/cubits/appointment_cubit.dart';
import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/bilan_cubit.dart';
import 'package:chifa/app/cubits/billing_cubit.dart';
import 'package:chifa/app/cubits/certificate_cubit.dart';
import 'package:chifa/app/cubits/dashboard_cubit.dart';
import 'package:chifa/app/cubits/doctor_working_hours_cubit.dart';
import 'package:chifa/app/cubits/inventory_cubit.dart';
import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/app/cubits/prescription_cubit.dart';
import 'package:chifa/app/cubits/settings_cubit.dart';
import 'package:chifa/app/cubits/soins_service_cubit.dart';
import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/screens/auth/login_screen.dart';
import 'package:chifa/app/screens/main_shell.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/local_sqlite_service.dart';
import 'package:chifa/services/db/repositories/appointment_repository.dart';
import 'package:chifa/services/db/repositories/arret_de_travail_repository.dart';
import 'package:chifa/services/db/repositories/auth_repository.dart';
import 'package:chifa/services/db/repositories/bilan_repository.dart';
import 'package:chifa/services/db/repositories/certificat_bonne_sante_repository.dart';
import 'package:chifa/services/db/repositories/certificat_coups_et_blessures_repository.dart';
import 'package:chifa/services/db/repositories/certificat_aptitude_sport_repository.dart';
import 'package:chifa/services/db/repositories/interpretation_ecg_repository.dart';
import 'package:chifa/services/db/repositories/certificat_dispense_sport_repository.dart';
import 'package:chifa/services/db/repositories/certificat_maladie_chronique_repository.dart';
import 'package:chifa/services/db/repositories/certificat_prenuptial_repository.dart';
import 'package:chifa/services/db/repositories/doctor_working_hours_repository.dart';
import 'package:chifa/services/db/repositories/inventory_repository.dart';
import 'package:chifa/services/db/repositories/invoice_repository.dart';
import 'package:chifa/services/db/repositories/lettre_repository.dart';
import 'package:chifa/services/db/repositories/medical_record_repository.dart';
import 'package:chifa/services/db/repositories/patient_repository.dart';
import 'package:chifa/services/db/repositories/payment_repository.dart';
import 'package:chifa/services/db/repositories/prescription_repository.dart';
import 'package:chifa/services/db/repositories/service_repository.dart';
import 'package:chifa/services/db/repositories/soins_service_repository.dart';
import 'package:chifa/services/db/sync_manager.dart';
import 'package:chifa/services/xampp_service.dart';
import 'package:chifa/tunnel/services/settings_service.dart';
import 'package:chifa/tunnel/services/tunnel_service.dart';
import 'package:chifa/tunnel/services/terminal_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
      if (systemOverlaysAreVisible) {
        await Future.delayed(const Duration(seconds: 2));
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('Warning: Could not load .env file: $e');
    }
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await XamppService().startAll();
  }

  // Initialize local SQLite service for offline resilience (Desktop / Mobile only)
  if (!kIsWeb) {
    try {
      await LocalSqliteService.instance.init();
      debugPrint('Local SQLite service initialized successfully');
    } catch (e) {
      debugPrint('Local SQLite initialization warning: $e');
    }
  }

  // Initialize database (Mobile/Tablet and Web use direct Octenium Cloud)
  try {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (kIsWeb || isMobile) {
      await DatabaseManager.initialize(databaseType: 'octenium');
    } else {
      try {
        await DatabaseManager.initialize(databaseType: 'xampp');
        // Automatically keep Windows local database synchronized with Octenium cloud
        SyncManager().startPeriodicSync();
      } catch (e) {
        debugPrint('Local XAMPP failed, falling back to Octenium Cloud: $e');
        await DatabaseManager.initialize(databaseType: 'octenium');
      }
    }
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    // Don't rethrow - let the app start and show the dialog
  }

  // Initialize TCP Tunnel services
  final tunnelSettings = SettingsService();
  await tunnelSettings.init();
  final tunnelService = TunnelService();
  final tunnelTerminal = TerminalService();

  // Spell checker disabled for performance
  // AppSpellCheckService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: tunnelService),
        ChangeNotifierProvider.value(value: tunnelSettings),
        ChangeNotifierProvider.value(value: tunnelTerminal),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => MedicalRecordRepository()),
        RepositoryProvider(create: (context) => SoinsServiceRepository()),
        RepositoryProvider(create: (context) => PaymentRepository()),
        RepositoryProvider(create: (context) => PatientRepository()),
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => AppointmentRepository()),
        RepositoryProvider(create: (context) => PrescriptionRepository()),
        RepositoryProvider(create: (context) => ServiceRepository()),
        RepositoryProvider(create: (context) => InvoiceRepository()),
        RepositoryProvider(create: (context) => BilanRepository()),
        RepositoryProvider(create: (context) => ArretDeTravailRepository()),
        RepositoryProvider(create: (context) => LettreRepository()),
        RepositoryProvider(create: (context) => InventoryRepository()),
        RepositoryProvider(create: (context) => DoctorWorkingHoursRepository()),
        RepositoryProvider(
          create: (context) => CertificatMaladieChroniqueRepository(),
        ),
        RepositoryProvider(
          create: (context) => CertificatBonneSanteRepository(),
        ),
        RepositoryProvider(
          create: (context) => CertificatDispenseSportRepository(),
        ),
        RepositoryProvider(
          create: (context) => CertificatPrenuptialRepository(),
        ),
        RepositoryProvider(
          create: (context) => CertificatCoupsEtBlessuresRepository(),
        ),
        RepositoryProvider(
          create: (context) => CertificatAptitudeSportRepository(),
        ),
        RepositoryProvider(
          create: (context) => InterpretationEcgRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                AuthCubit(context.read<AuthRepository>())..checkAuthStatus(),
          ),
          BlocProvider(
            create: (context) =>
                PatientCubit(context.read<PatientRepository>()),
          ),
          BlocProvider(
            create: (context) =>
                AppointmentCubit(context.read<AppointmentRepository>()),
          ),
          BlocProvider(
            create: (context) => BillingCubit(
              context.read<InvoiceRepository>(),
              context.read<ServiceRepository>(),
              context.read<PaymentRepository>(),
              context.read<AuthRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                PrescriptionCubit(context.read<PrescriptionRepository>()),
          ),
          BlocProvider(
            create: (context) =>
                MedicalRecordCubit(context.read<MedicalRecordRepository>()),
          ),
          BlocProvider(
            create: (context) => DashboardCubit(
              context.read<PatientRepository>(),
              context.read<AppointmentRepository>(),
              context.read<MedicalRecordRepository>(),
              context.read<InvoiceRepository>(),
              context.read<ArretDeTravailRepository>(),
              context.read<LettreRepository>(),
              context.read<BilanRepository>(),
              context.read<InventoryRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => SettingsCubit(context.read<AuthRepository>()),
          ),
          BlocProvider(
            create: (context) => BilanCubit(context.read<BilanRepository>()),
          ),
          BlocProvider(
            create: (context) => CertificateCubit(
              context.read<ArretDeTravailRepository>(),
              context.read<LettreRepository>(),
              context.read<CertificatMaladieChroniqueRepository>(),
              context.read<CertificatBonneSanteRepository>(),
              context.read<CertificatDispenseSportRepository>(),
              context.read<CertificatPrenuptialRepository>(),
              context.read<CertificatCoupsEtBlessuresRepository>(),
              context.read<CertificatAptitudeSportRepository>(),
              context.read<InterpretationEcgRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                InventoryCubit(context.read<InventoryRepository>()),
          ),
          BlocProvider(
            create: (context) => DoctorWorkingHoursCubit(
              context.read<DoctorWorkingHoursRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                SoinsServiceCubit(context.read<SoinsServiceRepository>()),
          ),
          BlocProvider(create: (context) => WorkspaceCubit()),
        ],
        child: MaterialApp(
          title: 'Chifa - Clinic Management',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('fr', 'FR'),
            Locale('ar', 'DZ'),
          ],
          home: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (state is AuthLoading || state is AuthInitial) {
                return const SplashScreen();
              } else if (state is AuthAuthenticated) {
                return const MainShell();
              } else {
                return const LoginScreen();
              }
            },
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'CHIFA',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Clinic Management System',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
