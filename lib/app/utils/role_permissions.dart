import 'package:chifa/services/db/models/employee.dart';

/// Centralized Role-Based Access Control (RBAC) helper
class RolePermissions {
  /// Check whether an employee role has access to a specific main navigation tab
  static bool canAccessTab(EmployeeRole? role, String tabId) {
    if (role == null) return false;

    // Admin and Doctor have full module access
    if (role == EmployeeRole.admin || role == EmployeeRole.doctor) {
      return true;
    }

    // Nurse / Assistant permissions (accueil & encaissement)
    if (role == EmployeeRole.nurse) {
      const allowedNurseTabs = <String>{
        'dashboard',
        'appointments',
        'patients',
        'medical_records',
        'billing', // Caisse & Encaissement des consultations/soins
        'inventory',
        'bilan',
      };
      return allowedNurseTabs.contains(tabId);
    }

    // Patient portal role (limited)
    if (role == EmployeeRole.patient) {
      const allowedPatientTabs = <String>{
        'dashboard',
        'appointments',
      };
      return allowedPatientTabs.contains(tabId);
    }

    return false;
  }

  /// Whether the user can view global financial reports & business revenue
  static bool canViewFinancialData(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can view doctor commission figures
  static bool canViewDoctorCommissions(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can delete payment/invoice records
  static bool canDeletePayments(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can write / edit medical prescriptions (ordonnances)
  static bool canPrescribe(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can issue official medical certificates (arrêts de travail, etc.)
  static bool canIssueCertificates(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can delete medical records
  static bool canDeleteMedicalRecords(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can create medical records (dossiers médicaux / consultations)
  static bool canCreateMedicalRecord(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can edit medical records
  static bool canEditMedicalRecord(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can edit payment/invoice records
  static bool canEditPayments(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can create, edit, or delete lab test orders (bilans)
  static bool canManageLabTests(EmployeeRole? role) {
    return role == EmployeeRole.admin || role == EmployeeRole.doctor;
  }

  /// Whether the user can manage clinic staff & users
  static bool canManageUsers(EmployeeRole? role) {
    return role == EmployeeRole.admin;
  }
}

