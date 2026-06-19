import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Auth Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class LogoutRequested extends AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

// Auth States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Employee employee;

  const AuthAuthenticated(this.employee);

  @override
  List<Object?> get props => [employee];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// Auth Cubit
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  Employee? _currentUser;

  AuthCubit(this._authRepository) : super(AuthInitial());

  Employee? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  /// Login with email and password
  Future<void> login(String email, String password) async {
    emit(AuthLoading());

    final result = await _authRepository.login(email, password);

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (employee) {
        _currentUser = employee;
        emit(AuthAuthenticated(employee));
      },
    );
  }

  /// Logout
  Future<void> logout() async {
    _currentUser = null;
    emit(AuthUnauthenticated());
  }

  /// Check if user is already authenticated
  Future<void> checkAuthStatus() async {
    if (_currentUser != null) {
      emit(AuthAuthenticated(_currentUser!));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  /// Get current employee role
  EmployeeRole? get currentRole => _currentUser?.role;

  /// Check if user has admin access
  bool get isAdmin => _currentUser?.accessLevel == AccessLevel.admin;

  /// Check if user is a doctor
  bool get isDoctor => _currentUser?.role == EmployeeRole.doctor;

  /// Check if user is a nurse
  bool get isNurse => _currentUser?.role == EmployeeRole.nurse;
}
