import "package:bcrypt/bcrypt.dart";
import "package:chifa/services/db/sync_manager.dart";
import "package:chifa/services/db/repositories/base_repository.dart";
import "package:chifa/services/db/models/models.dart";
import "package:chifa/services/db/database.dart";
import "package:dartz/dartz.dart";

class AuthRepository {
  final DatabaseService _db = DatabaseService();

  DatabaseService get db => _db;

  /// Hash password using bcrypt
  String _hashPassword(String password) {
    final salt = BCrypt.gensalt();
    return BCrypt.hashpw(password, salt);
  }

  /// Verify password against bcrypt hash
  bool _verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      return false;
    }
  }

  /// Login with email and password
  Future<Either<Failure, Employee>> login(String email, String password) async {
    try {
      final results = await _db.query(
        'SELECT * FROM employees WHERE email = ? AND is_deleted = 0',
        [email],
      );

      if (results.isEmpty) {
        return Left(NotFoundFailure('Employee not found'));
      }

      final employee = Employee.fromMap(results.first);

      // Verify password using bcrypt (passwords are stored as bcrypt hashes in DB)
      final isValid = _verifyPassword(password, employee.password);

      if (!isValid) {
        return Left(ValidationFailure('Invalid password'));
      }

      return Right(employee);
    } catch (e) {
      return Left(DatabaseFailure('Login failed: ${e.toString()}'));
    }
  }

  /// Get employee by ID
  Future<Either<Failure, Employee>> getEmployeeById(int id) async {
    try {
      final results = await _db.query(
        'SELECT * FROM employees WHERE employee_id = ? AND is_deleted = 0',
        [id],
      );

      if (results.isEmpty) {
        return Left(NotFoundFailure('Employee not found'));
      }

      return Right(Employee.fromMap(results.first));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get employee: ${e.toString()}'));
    }
  }

  /// Get all doctors
  Future<Either<Failure, List<Employee>>> getAllDoctors() async {
    try {
      final results = await _db.query(
        'SELECT * FROM employees WHERE (role = ? OR role = ?) AND is_deleted = 0',
        ['Doctor', 'doctor'],
      );

      final doctors = results.map((row) => Employee.fromMap(row)).toList();
      return Right(doctors);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get doctors: ${e.toString()}'));
    }
  }

  /// Get all employees
  Future<Either<Failure, List<Employee>>> getAllEmployees() async {
    try {
      final results = await _db.query(
        'SELECT * FROM employees WHERE is_deleted = 0 ORDER BY created_at DESC',
      );
      final employees = results.map((row) => Employee.fromMap(row)).toList();
      return Right(employees);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get employees: ${e.toString()}'));
    }
  }

  /// Create new employee
  Future<Either<Failure, int>> createEmployee(Employee employee) async {
    try {
      final uuid = SyncManager().generateUuid();
      final hashedPassword = _hashPassword(employee.password);
      final id = await _db.insert(
        '''INSERT INTO employees (uuid, first_name, last_name, role, specialization, email, phone, password, access_level, patient_id, needs_sync)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)''',
        [
          uuid,
          employee.firstName,
          employee.lastName,
          employee.role.name,
          employee.specialization,
          employee.email,
          employee.phone,
          hashedPassword,
          employee.accessLevel.name,
          employee.patientId,
        ],
      );
      return Right(id);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to create employee: ${e.toString()}'),
      );
    }
  }

  /// Update employee
  Future<Either<Failure, bool>> updateEmployee(
    int id,
    Employee employee,
  ) async {
    try {
      final result = await _db.execute(
        '''UPDATE employees SET 
           first_name = ?, last_name = ?, role = ?, specialization = ?, 
           email = ?, phone = ?, access_level = ?, patient_id = ?, needs_sync = 1
           WHERE employee_id = ?''',
        [
          employee.firstName,
          employee.lastName,
          employee.role.name,
          employee.specialization,
          employee.email,
          employee.phone,
          employee.accessLevel.name,
          employee.patientId,
          id,
        ],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to update employee: ${e.toString()}'),
      );
    }
  }

  /// Update employee password
  Future<Either<Failure, bool>> updatePassword(
    int id,
    String newPassword,
  ) async {
    try {
      final hashedPassword = _hashPassword(newPassword);
      final result = await _db.execute(
        'UPDATE employees SET password = ?, needs_sync = 1 WHERE employee_id = ?',
        [hashedPassword, id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to update password: ${e.toString()}'),
      );
    }
  }

  /// Delete employee
  Future<Either<Failure, bool>> deleteEmployee(int id) async {
    try {
      // Soft delete
      final result = await _db.execute(
        'UPDATE employees SET is_deleted = 1, needs_sync = 1 WHERE employee_id = ?',
        [id],
      );
      return Right(result > 0);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to delete employee: ${e.toString()}'),
      );
    }
  }

  /// Get employees by role
  Future<Either<Failure, List<Employee>>> getEmployeesByRole(
    EmployeeRole role,
  ) async {
    try {
      final results = await _db.query(
        'SELECT * FROM employees WHERE role = ? AND is_deleted = 0 ORDER BY created_at DESC',
        [role.name],
      );
      final employees = results.map((row) => Employee.fromMap(row)).toList();
      return Right(employees);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get employees by role: ${e.toString()}'),
      );
    }
  }
}
