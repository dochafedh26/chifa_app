import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Billing States
class BillingState extends Equatable {
  final List<Payment> payments;
  final List<Service> services;
  final List<Employee> doctors;
  final Payment? selectedPayment;
  final double? revenue;
  final DateTime? revenueStartDate;
  final DateTime? revenueEndDate;
  final double totalFilteredAmount;
  final double totalFilteredCommission;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const BillingState({
    this.payments = const [],
    this.services = const [],
    this.doctors = const [],
    this.selectedPayment,
    this.revenue,
    this.revenueStartDate,
    this.revenueEndDate,
    this.totalFilteredAmount = 0.0,
    this.totalFilteredCommission = 0.0,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  BillingState copyWith({
    List<Payment>? payments,
    List<Service>? services,
    List<Employee>? doctors,
    Payment? selectedPayment,
    double? revenue,
    DateTime? revenueStartDate,
    DateTime? revenueEndDate,
    double? totalFilteredAmount,
    double? totalFilteredCommission,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearSelectedPayment = false,
    bool clearError = false,
    bool clearSuccessMessage = false,
  }) {
    return BillingState(
      payments: payments ?? this.payments,
      services: services ?? this.services,
      doctors: doctors ?? this.doctors,
      selectedPayment:
          clearSelectedPayment ? null : (selectedPayment ?? this.selectedPayment),
      revenue: revenue ?? this.revenue,
      revenueStartDate: revenueStartDate ?? this.revenueStartDate,
      revenueEndDate: revenueEndDate ?? this.revenueEndDate,
      totalFilteredAmount: totalFilteredAmount ?? this.totalFilteredAmount,
      totalFilteredCommission:
          totalFilteredCommission ?? this.totalFilteredCommission,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        payments,
        services,
        doctors,
        selectedPayment,
        revenue,
        revenueStartDate,
        revenueEndDate,
        totalFilteredAmount,
        totalFilteredCommission,
        isLoading,
        error,
        successMessage,
      ];
}

// Billing Cubit
class BillingCubit extends Cubit<BillingState> {
  final InvoiceRepository _invoiceRepository;
  final ServiceRepository _serviceRepository;
  final PaymentRepository _paymentRepository;
  final AuthRepository _authRepository;

  BillingCubit(
    this._invoiceRepository,
    this._serviceRepository,
    this._paymentRepository,
    this._authRepository,
  ) : super(const BillingState());

  /// Load all payments
  Future<void> loadAllPayments() async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _invoiceRepository.getFilteredPayments();

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (result) => emit(state.copyWith(
        isLoading: false,
        payments: result.payments,
        totalFilteredAmount: result.totalAmount,
        totalFilteredCommission: result.totalCommission,
      )),
    );
  }

  /// Load payment by ID
  Future<void> loadPaymentById(int id) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _invoiceRepository.getById(id);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (payment) => emit(state.copyWith(isLoading: false, selectedPayment: payment)),
    );
  }

  /// Load payments by patient ID
  Future<void> loadPaymentsByPatientId(int patientId) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _invoiceRepository.getByPatientId(patientId);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (payments) => emit(state.copyWith(isLoading: false, payments: payments)),
    );
  }

  /// Search payments
  Future<void> searchPayments(String query) async {
    if (query.isEmpty) {
      loadAllPayments();
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _invoiceRepository.search(query);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (payments) => emit(state.copyWith(isLoading: false, payments: payments)),
    );
  }

  /// Update payment
  Future<void> updatePayment(int id, Payment payment) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _invoiceRepository.update(id, payment);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Payment updated successfully',
          ));
          loadAllPayments();
        } else {
          emit(state.copyWith(isLoading: false, error: 'Failed to update payment'));
        }
      },
    );
  }

  /// Update payment with services
  Future<void> updatePaymentWithServices(int paymentId, Payment payment, List<PaymentService> services) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _paymentRepository.updateWithServices(paymentId, payment, services);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Payment updated successfully',
          ));
          loadAllPayments();
        } else {
          emit(state.copyWith(isLoading: false, error: 'Failed to update payment'));
        }
      },
    );
  }

  /// Delete payment
  Future<void> deletePayment(int id) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _invoiceRepository.delete(id);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Payment deleted successfully',
          ));
          loadAllPayments();
        } else {
          emit(state.copyWith(isLoading: false, error: 'Failed to delete payment'));
        }
      },
    );
  }

  /// Load payments by date range
  Future<void> loadPaymentsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _invoiceRepository.getByDateRange(startDate, endDate);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (payments) => emit(state.copyWith(isLoading: false, payments: payments)),
    );
  }

  /// Load payments by date and doctor
  Future<void> loadPaymentsByDateAndDoctor(
    DateTime startDate,
    DateTime endDate,
    int doctorId,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _invoiceRepository.getByDateAndDoctor(
      startDate,
      endDate,
      doctorId,
    );

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (payments) => emit(state.copyWith(isLoading: false, payments: payments)),
    );
  }

  /// Filter payments with multiple criteria
  Future<void> filterPayments({
    DateTime? startDate,
    DateTime? endDate,
    int? doctorId,
    int? patientId,
    String? patientQuery,
    String? serviceQuery,
  }) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _invoiceRepository.getFilteredPayments(
      startDate: startDate,
      endDate: endDate,
      doctorId: doctorId,
      patientId: patientId,
      patientQuery: patientQuery,
      serviceQuery: serviceQuery,
    );

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (result) => emit(state.copyWith(
        isLoading: false,
        payments: result.payments,
        totalFilteredAmount: result.totalAmount,
        totalFilteredCommission: result.totalCommission,
      )),
    );
  }

  /// Load all doctors
  Future<void> loadDoctors() async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _authRepository.getAllDoctors();

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (doctors) => emit(state.copyWith(isLoading: false, doctors: doctors)),
    );
  }

  /// Load all services
  Future<void> loadServices() async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _serviceRepository.getAll();

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (services) => emit(state.copyWith(isLoading: false, services: services)),
    );
  }

  /// Create new service
  Future<void> createService(Service service) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _serviceRepository.create(service);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (id) {
        emit(state.copyWith(
          isLoading: false,
          successMessage: 'Service created successfully',
        ));
        loadServices();
      },
    );
  }

  /// Update service
  Future<void> updateService(int id, Service service) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _serviceRepository.update(id, service);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Service updated successfully',
          ));
          loadServices();
        } else {
          emit(state.copyWith(isLoading: false, error: 'Failed to update service'));
        }
      },
    );
  }

  /// Delete service
  Future<void> deleteService(int id) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _serviceRepository.delete(id);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (success) {
        if (success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage: 'Service deleted successfully',
          ));
          loadServices();
        } else {
          emit(state.copyWith(isLoading: false, error: 'Failed to delete service'));
        }
      },
    );
  }

  /// Create payment
  Future<void> createPayment(Payment payment) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _paymentRepository.create(payment);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (id) {
        emit(state.copyWith(
          isLoading: false,
          successMessage: 'Payment recorded successfully',
        ));
        loadAllPayments();
      },
    );
  }

  /// Create payment with services
  Future<void> createPaymentWithServices(
    Payment payment,
    List<PaymentService> services,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true, clearSuccessMessage: true));
    final result = await _paymentRepository.createWithServices(
      payment,
      services,
    );

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (id) {
        emit(state.copyWith(
          isLoading: false,
          successMessage: 'Payment with services recorded successfully',
        ));
        loadAllPayments();
      },
    );
  }

  /// Load payments by invoice ID
  Future<void> loadPaymentsByInvoiceId(int invoiceId) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _paymentRepository.getByInvoiceId(invoiceId);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (payments) => emit(state.copyWith(isLoading: false, payments: payments)),
    );
  }

  /// Get total revenue for date range
  Future<void> getRevenue(DateTime startDate, DateTime endDate) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));
    final result = await _invoiceRepository.getTotalRevenue(startDate, endDate);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (revenue) => emit(state.copyWith(
        isLoading: false,
        revenue: revenue,
        revenueStartDate: startDate,
        revenueEndDate: endDate,
      )),
    );
  }

  /// Get today's revenue
  Future<void> getTodayRevenue() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    await getRevenue(startOfDay, endOfDay);
  }

  /// Get services by specialization
  Future<void> getServicesBySpecialization(String specialization) async {
    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    final result = await _serviceRepository.getBySpecialization(specialization);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (services) => emit(state.copyWith(isLoading: false, services: services)),
    );
  }

  /// Clear error
  void clearError() => emit(state.copyWith(clearError: true));

  /// Clear success message
  void clearSuccessMessage() => emit(state.copyWith(clearSuccessMessage: true));
}
