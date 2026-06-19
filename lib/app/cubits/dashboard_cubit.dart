import "package:flutter/foundation.dart";
import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Dashboard Events
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardStatistics extends DashboardEvent {}

class LoadTodayStatistics extends DashboardEvent {}

class LoadWeekStatistics extends DashboardEvent {}

class LoadMonthStatistics extends DashboardEvent {}

class LoadYearStatistics extends DashboardEvent {}

class LoadRevenueStatistics extends DashboardEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadRevenueStatistics(this.startDate, this.endDate);

  @override
  List<Object?> get props => [startDate, endDate];
}

class LoadPatientStatistics extends DashboardEvent {}

class LoadAppointmentStatistics extends DashboardEvent {}

class LoadMedicalRecordStatistics extends DashboardEvent {}

class LoadCertificateStatistics extends DashboardEvent {}

class LoadInventoryStatistics extends DashboardEvent {}

// Dashboard States
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardStatisticsLoaded extends DashboardState {
  final DashboardStatistics statistics;

  const DashboardStatisticsLoaded(this.statistics);

  @override
  List<Object?> get props => [statistics];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

// Dashboard Statistics Model
class DashboardStatistics extends Equatable {
  final int totalPatients;
  final int totalAppointments;
  final int totalMedicalRecords;
  final int totalInvoices;
  final double totalRevenue;
  final int totalCertificates;
  final int totalLabOrders;
  final int lowStockItems;
  final int todayPatients;
  final int todayAppointments;
  final double todayRevenue;
  final int weekAppointments;
  final int monthAppointments;
  final double monthRevenue;
  final Map<String, int> appointmentsByStatus;
  final Map<String, int> patientsByStatus;
  final List<double> revenueByMonth;
  final List<int> appointmentsByMonth;

  const DashboardStatistics({
    this.totalPatients = 0,
    this.totalAppointments = 0,
    this.totalMedicalRecords = 0,
    this.totalInvoices = 0,
    this.totalRevenue = 0.0,
    this.totalCertificates = 0,
    this.totalLabOrders = 0,
    this.lowStockItems = 0,
    this.todayPatients = 0,
    this.todayAppointments = 0,
    this.todayRevenue = 0.0,
    this.weekAppointments = 0,
    this.monthAppointments = 0,
    this.monthRevenue = 0.0,
    this.appointmentsByStatus = const {},
    this.patientsByStatus = const {},
    this.revenueByMonth = const [],
    this.appointmentsByMonth = const [],
  });

  DashboardStatistics copyWith({
    int? totalPatients,
    int? totalAppointments,
    int? totalMedicalRecords,
    int? totalInvoices,
    double? totalRevenue,
    int? totalCertificates,
    int? totalLabOrders,
    int? lowStockItems,
    int? todayPatients,
    int? todayAppointments,
    double? todayRevenue,
    int? weekAppointments,
    int? monthAppointments,
    double? monthRevenue,
    Map<String, int>? appointmentsByStatus,
    Map<String, int>? patientsByStatus,
    List<double>? revenueByMonth,
    List<int>? appointmentsByMonth,
  }) {
    return DashboardStatistics(
      totalPatients: totalPatients ?? this.totalPatients,
      totalAppointments: totalAppointments ?? this.totalAppointments,
      totalMedicalRecords: totalMedicalRecords ?? this.totalMedicalRecords,
      totalInvoices: totalInvoices ?? this.totalInvoices,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalCertificates: totalCertificates ?? this.totalCertificates,
      totalLabOrders: totalLabOrders ?? this.totalLabOrders,
      lowStockItems: lowStockItems ?? this.lowStockItems,
      todayPatients: todayPatients ?? this.todayPatients,
      todayAppointments: todayAppointments ?? this.todayAppointments,
      todayRevenue: todayRevenue ?? this.todayRevenue,
      weekAppointments: weekAppointments ?? this.weekAppointments,
      monthAppointments: monthAppointments ?? this.monthAppointments,
      monthRevenue: monthRevenue ?? this.monthRevenue,
      appointmentsByStatus: appointmentsByStatus ?? this.appointmentsByStatus,
      patientsByStatus: patientsByStatus ?? this.patientsByStatus,
      revenueByMonth: revenueByMonth ?? this.revenueByMonth,
      appointmentsByMonth: appointmentsByMonth ?? this.appointmentsByMonth,
    );
  }

  @override
  List<Object?> get props => [
    totalPatients,
    totalAppointments,
    totalMedicalRecords,
    totalInvoices,
    totalRevenue,
    totalCertificates,
    totalLabOrders,
    lowStockItems,
    todayPatients,
    todayAppointments,
    todayRevenue,
    weekAppointments,
    monthAppointments,
    monthRevenue,
    appointmentsByStatus,
    patientsByStatus,
    revenueByMonth,
    appointmentsByMonth,
  ];
}

// Dashboard Cubit
class DashboardCubit extends Cubit<DashboardState> {
  final PatientRepository _patientRepository;
  final AppointmentRepository _appointmentRepository;
  final MedicalRecordRepository _medicalRecordRepository;
  final InvoiceRepository _invoiceRepository;
  final ArretDeTravailRepository _arretRepository;
  final LettreRepository _lettreRepository;
  final BilanRepository _bilanRepository;
  final InventoryRepository _inventoryRepository;

  DashboardCubit(
    this._patientRepository,
    this._appointmentRepository,
    this._medicalRecordRepository,
    this._invoiceRepository,
    this._arretRepository,
    this._lettreRepository,
    this._bilanRepository,
    this._inventoryRepository,
  ) : super(DashboardInitial());

  /// Load all dashboard statistics
  Future<void> loadDashboardStatistics() async {
    emit(DashboardLoading());

    try {
      final stats = await _loadAllStatistics();
      emit(DashboardStatisticsLoaded(stats));
    } catch (e) {
      emit(DashboardError('Failed to load statistics: ${e.toString()}'));
    }
  }

  /// Load today's statistics
  Future<void> loadTodayStatistics() async {
    emit(DashboardLoading());

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final todayRevenueResult = await _invoiceRepository.getTotalRevenue(
        startOfDay,
        endOfDay,
      );
      final todayRevenue = todayRevenueResult.fold((_) => 0.0, (r) => r);

      // Count today's appointments
      int todayAppointments = 0;
      final appointmentsResult = await _appointmentRepository.getAll();
      appointmentsResult.fold((_) => {}, (appointments) {
        todayAppointments = appointments.where((a) {
          return a.appointmentDate.year == now.year &&
              a.appointmentDate.month == now.month &&
              a.appointmentDate.day == now.day;
        }).length;
      });

      final currentStats = await _loadAllStatistics();
      final stats = currentStats.copyWith(
        todayRevenue: todayRevenue,
        todayAppointments: todayAppointments,
      );

      emit(DashboardStatisticsLoaded(stats));
    } catch (e) {
      emit(DashboardError('Failed to load today statistics: ${e.toString()}'));
    }
  }

  /// Load month statistics
  Future<void> loadMonthStatistics() async {
    emit(DashboardLoading());

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final monthRevenueResult = await _invoiceRepository.getTotalRevenue(
        startOfMonth,
        endOfMonth,
      );
      final monthRevenue = monthRevenueResult.fold((_) => 0.0, (r) => r);

      final currentStats = await _loadAllStatistics();
      final stats = currentStats.copyWith(monthRevenue: monthRevenue);

      emit(DashboardStatisticsLoaded(stats));
    } catch (e) {
      emit(DashboardError('Failed to load month statistics: ${e.toString()}'));
    }
  }

  /// Load revenue statistics for date range
  Future<void> loadRevenueStatistics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    emit(DashboardLoading());

    try {
      final revenueResult = await _invoiceRepository.getTotalRevenue(
        startDate,
        endDate,
      );
      final revenue = revenueResult.fold((_) => 0.0, (r) => r);

      final currentStats = await _loadAllStatistics();
      final stats = currentStats.copyWith(totalRevenue: revenue);

      emit(DashboardStatisticsLoaded(stats));
    } catch (e) {
      emit(
        DashboardError('Failed to load revenue statistics: ${e.toString()}'),
      );
    }
  }

  /// Load monthly revenue chart data
  Future<void> loadMonthlyRevenueData([int months = 12]) async {
    emit(DashboardLoading());

    try {
      final now = DateTime.now();
      final revenueByMonth = <double>[];
      final labels = <String>[];

      for (int i = months - 1; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final startOfMonth = monthDate;
        final endOfMonth = DateTime(
          monthDate.year,
          monthDate.month + 1,
          0,
          23,
          59,
          59,
        );

        final result = await _invoiceRepository.getTotalRevenue(
          startOfMonth,
          endOfMonth,
        );
        final revenue = result.fold((_) => 0.0, (r) => r);
        revenueByMonth.add(revenue);
        labels.add('${monthDate.month}/${monthDate.year}');
      }

      final currentStats = await _loadAllStatistics();
      final stats = currentStats.copyWith(revenueByMonth: revenueByMonth);

      emit(DashboardStatisticsLoaded(stats));
    } catch (e) {
      emit(
        DashboardError('Failed to load monthly revenue data: ${e.toString()}'),
      );
    }
  }

  /// Load monthly appointments data
  Future<void> loadMonthlyAppointmentsData([int months = 12]) async {
    emit(DashboardLoading());

    try {
      final now = DateTime.now();
      final appointmentsByMonth = <int>[];

      for (int i = months - 1; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final startOfMonth = monthDate;
        final endOfMonth = DateTime(
          monthDate.year,
          monthDate.month + 1,
          0,
          23,
          59,
          59,
        );

        // Count appointments manually since getByDateRange may not exist
        final appointmentsResult = await _appointmentRepository.getAll();
        int count = 0;
        appointmentsResult.fold((_) => {}, (appointments) {
          count = appointments.where((a) {
            return a.appointmentDate.isAfter(
                  startOfMonth.subtract(const Duration(days: 1)),
                ) &&
                a.appointmentDate.isBefore(
                  endOfMonth.add(const Duration(days: 1)),
                );
          }).length;
        });
        appointmentsByMonth.add(count);
      }

      final currentStats = await _loadAllStatistics();
      final stats = currentStats.copyWith(
        appointmentsByMonth: appointmentsByMonth,
      );

      emit(DashboardStatisticsLoaded(stats));
    } catch (e) {
      emit(
        DashboardError(
          'Failed to load monthly appointments data: ${e.toString()}',
        ),
      );
    }
  }

  /// Load all statistics
  Future<DashboardStatistics> _loadAllStatistics() async {
    int totalPatients = 0;
    int totalAppointments = 0;
    int totalMedicalRecords = 0;
    int totalInvoices = 0;
    double totalRevenue = 0.0;
    int totalCertificates = 0;
    int totalLabOrders = 0;
    int lowStockItems = 0;
    Map<String, int> appointmentsByStatus = {};
    Map<String, int> patientsByStatus = {};

    // Load patient count
    final patientCountResult = await _patientRepository.getCount();
    totalPatients = patientCountResult.fold((_) => 0, (c) => c);

    // Load appointment count and status breakdown
    final appointmentsResult = await _appointmentRepository.getAll();
    appointmentsResult.fold((_) => {}, (appointments) {
      totalAppointments = appointments.length;
      appointmentsByStatus = {};
      for (var status in AppointmentStatus.values) {
        final count = appointments.where((a) => a.status == status).length;
        appointmentsByStatus[status.name] = count;
      }
    });

    // Load medical record count
    final medicalRecordCountResult = await _medicalRecordRepository.getCount();
    totalMedicalRecords = medicalRecordCountResult.fold((_) => 0, (c) => c);

    // Load invoice count and revenue
    final invoicesResult = await _invoiceRepository.getAll();

    invoicesResult.fold((_) => {}, (invoices) {
      totalInvoices = invoices.length;
      // debugPrint('invoicesResult: $totalInvoices');
    });

    // Load total revenue from payments table
    final revenueResult = await _invoiceRepository.getTotalRevenue(
      DateTime(2000), // Far past date to get all payments
      DateTime.now().add(const Duration(days: 1)),
    );
    totalRevenue = revenueResult.fold((_) => 0.0, (r) => r);
    debugPrint('totalRevenue: $totalRevenue');

    // Load certificate count (arrets + lettres)
    final arretCountResult = await _arretRepository.getCount();
    final arretCount = arretCountResult.fold((_) => 0, (c) => c);
    final lettreCountResult = await _lettreRepository.getCount();
    final lettreCount = lettreCountResult.fold((_) => 0, (c) => c);
    totalCertificates = arretCount + lettreCount;

    // Load lab orders count
    final bilanResult = await _bilanRepository.getAll();
    totalLabOrders = bilanResult.fold((_) => 0, (bilans) => bilans.length);

    // Load low stock items count
    final lowStockResult = await _inventoryRepository.getLowStockItems(10);
    lowStockItems = lowStockResult.fold((_) => 0, (items) => items.length);

    // Load patient status breakdown
    final patientsResult = await _patientRepository.getAll();
    patientsResult.fold((_) => {}, (patients) {
      patientsByStatus = {};
      for (var status in PatientStatus.values) {
        final count = patients.where((p) => p.status == status).length;
        patientsByStatus[status.name] = count;
      }
    });

    return DashboardStatistics(
      totalPatients: totalPatients,
      totalAppointments: totalAppointments,
      totalMedicalRecords: totalMedicalRecords,
      totalInvoices: totalInvoices,
      totalRevenue: totalRevenue,
      totalCertificates: totalCertificates,
      totalLabOrders: totalLabOrders,
      lowStockItems: lowStockItems,
      appointmentsByStatus: appointmentsByStatus,
      patientsByStatus: patientsByStatus,
    );
  }
}
