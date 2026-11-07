import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Service SQLite local autonome pour Chifa.
/// Fonctionne 100% hors-ligne sur Windows, Linux, macOS, Android et iOS
/// sans nécessiter XAMPP ou MySQL local.
class LocalSqliteService {
  static final LocalSqliteService instance = LocalSqliteService._internal();
  LocalSqliteService._internal();

  Database? _db;
  bool _initialized = false;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    await init();
    return _db!;
  }

  bool get isInitialized => _initialized && _db != null && _db!.isOpen;

  Future<void> init() async {
    if (_initialized && _db != null && _db!.isOpen) return;

    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final dbFolder = await _getDatabaseDirectory();
      final dbPath = p.join(dbFolder, 'chifa_local.db');
      debugPrint('[LocalSqliteService] Initialisation base SQLite : $dbPath');

      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await _ensureTables(db);
        },
      );

      _initialized = true;
      debugPrint('[LocalSqliteService] Base SQLite locale prête.');
    } catch (e, stack) {
      debugPrint('[LocalSqliteService] Erreur init SQLite: $e\n$stack');
      rethrow;
    }
  }

  Future<String> _getDatabaseDirectory() async {
    if (kIsWeb) return '';
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final dir = Directory(appSupportDir.path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir.path;
    } catch (_) {
      final docDir = await getApplicationDocumentsDirectory();
      return docDir.path;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
  }

  Future<void> _ensureTables(Database db) async {
    await _createAllTables(db);
  }

  Future<void> _createAllTables(Database db) async {
    // 1. Cached Employees (pour connexion hors-ligne sécurisée)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_employees (
        employee_id INTEGER PRIMARY KEY,
        uuid TEXT UNIQUE,
        first_name TEXT,
        last_name TEXT,
        role TEXT,
        specialization TEXT,
        email TEXT UNIQUE,
        phone TEXT,
        password_hash TEXT,
        access_level TEXT,
        is_active INTEGER DEFAULT 1,
        token TEXT,
        last_login_at TEXT
      )
    ''');

    // 2. Sync tracking
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_status (
        table_name TEXT PRIMARY KEY,
        last_push_at TEXT DEFAULT '1970-01-01 00:00:00',
        last_pull_at TEXT DEFAULT '1970-01-01 00:00:00'
      )
    ''');

    // 3. Patients
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        patient_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        dob TEXT,
        gender TEXT,
        phone TEXT,
        address TEXT,
        national_id TEXT,
        blood_group TEXT,
        allergies TEXT,
        notes TEXT,
        portal_pin_hash TEXT,
        portal_access_enabled INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 4. Appointments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        appointment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        appointment_date TEXT NOT NULL,
        status TEXT DEFAULT 'Scheduled',
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 5. Medical Records & Consultations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicalrecords (
        record_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        visit_date TEXT,
        chief_complaint TEXT,
        diagnosis TEXT,
        treatment_plan TEXT,
        blood_pressure TEXT,
        heart_rate TEXT,
        temperature TEXT,
        weight TEXT,
        height TEXT,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 6. Medical Record Services
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicalrecord_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        medicalrecord_id INTEGER,
        service_id INTEGER,
        quantity INTEGER DEFAULT 1,
        price REAL DEFAULT 0.0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 7. Prescriptions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prescriptions (
        prescription_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        medicalrecord_id INTEGER,
        medication TEXT,
        dosage TEXT,
        frequency TEXT,
        duration TEXT,
        instructions TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 8. Modern Prescriptions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS modern_prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        prescription TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 9. Bilans
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bilans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        medicalrecord_id INTEGER,
        bilans TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bilan_type (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        nom TEXT,
        elements TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 10. Invoices
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        invoice_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        total_amount REAL DEFAULT 0.0,
        paid_amount REAL DEFAULT 0.0,
        status TEXT DEFAULT 'Pending',
        invoice_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 11. Payments & Payment Services
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        amount REAL DEFAULT 0.0,
        payment_date TEXT,
        payment_method TEXT DEFAULT 'Cash',
        note TEXT,
        discount_amount REAL DEFAULT 0.0,
        discount_type TEXT DEFAULT 'money',
        discount_value REAL DEFAULT 0.0,
        discount_commission_amount REAL DEFAULT 0.0,
        discount_commission_type TEXT DEFAULT 'proportional',
        discount_commission_value REAL DEFAULT 0.0,
        apply_commission_discount INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        payment_id INTEGER,
        service_id INTEGER,
        service_type TEXT DEFAULT 'act',
        price REAL DEFAULT 0.0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 12. Services & Soins Services
    await db.execute('''
      CREATE TABLE IF NOT EXISTS services (
        service_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        service_name TEXT NOT NULL,
        price REAL DEFAULT 0.0,
        doctor_commission REAL DEFAULT 0.0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS soins_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        nom TEXT NOT NULL,
        price REAL DEFAULT 0.0,
        doctor_commission REAL DEFAULT 0.0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS soins_medicaux (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        medicalrecord_id INTEGER,
        soins TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 13. Employees mirror
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        employee_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        role TEXT NOT NULL,
        specialization TEXT,
        email TEXT UNIQUE,
        phone TEXT,
        password TEXT,
        access_level TEXT DEFAULT 'limited',
        patient_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 14. Clinical Certificates & Documents
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lettres (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        atcd TEXT,
        motif_consultation TEXT,
        examen_clinique TEXT,
        motif_lettre TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS arret_de_travail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        type TEXT NOT NULL,
        motif TEXT NOT NULL,
        date_debut TEXT,
        jours INTEGER DEFAULT 1,
        date_reprise TEXT,
        date_creation TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS certificat_bonne_sante (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS certificat_dispense_sport (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        motif TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS certificat_maladie_chronique (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        maladie_chronique TEXT,
        diagnostic TEXT,
        traitement TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS certificat_prenuptial (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        groupe_sanguin TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS certificat_aptitude_sport (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        sport TEXT DEFAULT 'Toutes disciplines sportives',
        type_pratique TEXT DEFAULT 'Entraînement et Loisir',
        examen_clinique TEXT,
        remarques TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS interpretation_ecg (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        doctor_id INTEGER,
        motif TEXT DEFAULT 'Bilan systématique',
        rythme TEXT DEFAULT 'Sinusal régulier',
        frequence_cardiaque INTEGER DEFAULT 75,
        axe_qrs TEXT DEFAULT 'Normal (~60°)',
        onde_p TEXT DEFAULT 'Normale',
        espace_pr TEXT DEFAULT 'Normal (120-200 ms)',
        complexe_qrs TEXT DEFAULT 'Fin (< 100 ms)',
        segment_st TEXT DEFAULT 'Isoélectrique',
        onde_t TEXT DEFAULT 'Positive et normale',
        intervalle_qt TEXT DEFAULT 'Normal',
        conclusion TEXT,
        remarques TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 15. Hospitalizations, Expenses, Inventory
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hospitalizations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        admission_date TEXT,
        discharge_date TEXT,
        diagnosis TEXT,
        room_number TEXT,
        status TEXT DEFAULT 'active',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        category TEXT,
        description TEXT,
        amount REAL DEFAULT 0.0,
        expense_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        item_name TEXT NOT NULL,
        category TEXT,
        quantity INTEGER DEFAULT 0,
        unit_price REAL DEFAULT 0.0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    // 16. Patient Portal Uploads & Notifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patient_portal_uploads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        file_path TEXT,
        original_name TEXT,
        file_type TEXT,
        file_size INTEGER DEFAULT 0,
        category TEXT,
        notes TEXT,
        status TEXT DEFAULT 'pending',
        viewed_by INTEGER,
        viewed_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'portal'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        doctor_id INTEGER,
        patient_id INTEGER,
        title TEXT,
        message TEXT,
        type TEXT DEFAULT 'patient_upload',
        reference_id INTEGER,
        is_read INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'portal'
      )
    ''');

    // 17. Patients Fidèles & Suivi
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients_fideles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER UNIQUE,
        medical_records_count INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients_suivi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER UNIQUE,
        doctor_id INTEGER DEFAULT 1,
        pathologies TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS patient_suivi_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        patient_id INTEGER,
        category TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medalgeriemedics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        nom TEXT,
        dosage TEXT,
        forme TEXT,
        presentation TEXT,
        posologie_adulte TEXT,
        posologie_pediatrique TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ordonnance_type (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        titre TEXT,
        contenu TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 0,
        source_id TEXT DEFAULT 'local_sqlite'
      )
    ''');
  }

  // ─── Query & Mutation Wrappers ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> insert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  Future<int> update(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  Future<int> delete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }

  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ─── Offline Authentication Cache Helpers ────────────────────────────────────

  Future<void> cacheEmployee({
    required int employeeId,
    required String uuid,
    required String firstName,
    required String lastName,
    required String role,
    required String email,
    String? specialization,
    String? phone,
    required String passwordHash,
    String? accessLevel,
    int isActive = 1,
    String? token,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.rawInsert('''
      INSERT OR REPLACE INTO cached_employees 
        (employee_id, uuid, first_name, last_name, role, specialization, email, phone, password_hash, access_level, is_active, token, last_login_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
    ''', [
      employeeId,
      uuid,
      firstName,
      lastName,
      role,
      specialization,
      email.toLowerCase().trim(),
      phone,
      passwordHash,
      accessLevel ?? 'limited',
      isActive,
      token,
    ]);
  }

  Future<Map<String, dynamic>?> getCachedEmployee(String identifier) async {
    if (kIsWeb) return null;
    final db = await database;
    final clean = identifier.toLowerCase().trim();
    String alias = clean;
    if (clean == 'toumi' || clean == 'touami') {
      alias = 'touami@gmail.com';
    } else if (!clean.contains('@')) {
      alias = '$clean@gmail.com';
    }
    final rows = await db.rawQuery(
      'SELECT * FROM cached_employees WHERE LOWER(email) = ? OR LOWER(email) = ? OR phone = ? OR LOWER(last_name) LIKE ? LIMIT 1',
      [clean, alias, identifier.trim(), '%$clean%'],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }
}

