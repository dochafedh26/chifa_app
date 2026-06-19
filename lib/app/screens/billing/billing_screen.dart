import 'package:chifa/app/cubits/billing_cubit.dart';
import 'package:chifa/app/screens/billing/invoice_form_dialog.dart';
import 'package:chifa/app/screens/billing/invoice_print_dialog.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:chifa/services/db/models/payment.dart';
import 'package:chifa/services/db/models/payment_service.dart';
import 'package:chifa/services/db/repositories/payment_repository.dart';
import 'package:chifa/services/pdf_generation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// Billing & Invoices Screen
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int? _selectedDoctorId;
  bool _showFilters = false;
  final Set<int> _selectedPaymentIds = {};

  @override
  void initState() {
    super.initState();
    context.read<BillingCubit>().loadAllPayments();
    context.read<BillingCubit>().loadServices();
    context.read<BillingCubit>().loadDoctors();
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _patientController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _selectedPaymentIds.clear();
    });
    context.read<BillingCubit>().filterPayments(
      startDate: _startDate,
      endDate: _endDate,
      doctorId: _selectedDoctorId,
      patientQuery: _patientController.text,
      serviceQuery: _serviceController.text,
    );
  }

  void _resetFilters() {
    setState(() {
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _selectedDoctorId = null;
      _patientController.clear();
      _serviceController.clear();
      _searchController.clear();
      _selectedPaymentIds.clear();
    });
    context.read<BillingCubit>().loadAllPayments();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _selectedPaymentIds.clear();
    });
    if (query.isEmpty) {
      _applyFilters();
    } else {
      context.read<BillingCubit>().searchPayments(query);
    }
  }

  void _showCreateInvoiceDialog() {
    showDialog(
      context: context,
      builder: (context) => const InvoiceFormDialog(),
    );
  }

  void _printBillingList() async {
    final state = context.read<BillingCubit>().state;
    final allPayments = state.payments;
    final payments = _selectedPaymentIds.isEmpty
        ? allPayments
        : allPayments.where((p) => _selectedPaymentIds.contains(p.paymentId)).toList();

    if (payments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payments to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pdfService = PdfGenerationService(
        clinicName: 'Clinique Chifa',
        clinicAddress: 'Route d\'Alger, En face Dr Chaabane Sari - MEDEA',
        clinicPhone: '07 91 14 07 73 - 025 78 00 47',
        clinicEmail: 'contact@chifa-clinique.com',
        doctorName: 'Dr HERHOUR MOHAMED',
        doctorSpecialization: 'Médecine Générale',
      );

      Employee? selectedDoctor;
      for (final doctor in state.doctors) {
        if (doctor.employeeId == _selectedDoctorId) {
          selectedDoctor = doctor;
          break;
        }
      }
      final doctorName = selectedDoctor?.fullName;

      final doc = await pdfService.generateBillingList(
        payments: payments,
        startDate: _startDate,
        endDate: _endDate,
        doctorName: doctorName,
      );

      final pdfBytes = doc.save();

      if (mounted) {
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing list printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing billing list: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Action Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: isMobile
              ? Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showCreateInvoiceDialog,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            label: const Text('Filters'),
                            selected: _showFilters,
                            onSelected: (val) =>
                                setState(() => _showFilters = val),
                            avatar: Icon(
                              Icons.filter_list,
                              size: 18,
                              color: _showFilters ? Colors.white : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _printBillingList,
                          icon: Badge(
                            label: Text('${_selectedPaymentIds.length}'),
                            isLabelVisible: _selectedPaymentIds.isNotEmpty,
                            child: const Icon(Icons.print, color: Colors.blue),
                          ),
                          tooltip: _selectedPaymentIds.isEmpty
                              ? 'Print List'
                              : 'Print Selected (${_selectedPaymentIds.length})',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            context.read<BillingCubit>().loadAllPayments();
                            context.read<BillingCubit>().loadServices();
                            context.read<BillingCubit>().loadDoctors();
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Quick search (name, service)...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: _showFilters ? 'Hide Filters' : 'Show Filters',
                      child: FilterChip(
                        label: const Text('Filters'),
                        selected: _showFilters,
                        onSelected: (val) => setState(() => _showFilters = val),
                        avatar: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: _showFilters ? Colors.white : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        context.read<BillingCubit>().loadAllPayments();
                        context.read<BillingCubit>().loadServices();
                        context.read<BillingCubit>().loadDoctors();
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateInvoiceDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('New Payment'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _printBillingList,
                      icon: const Icon(Icons.print),
                      label: Text(_selectedPaymentIds.isEmpty
                          ? 'Print List'
                          : 'Print Selected (${_selectedPaymentIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),

        // Collapsible Filter Bar
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildFilterBar(),
          crossFadeState: _showFilters
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),

        const SizedBox(height: 16),

        // Summary Cards
        BlocBuilder<BillingCubit, BillingState>(
          builder: (context, state) {
            final cards = [
              _SummaryCard(
                label: 'Total Revenue',
                value: state.totalFilteredAmount,
                icon: Icons.account_balance_wallet,
                color: Colors.teal,
              ),
              _SummaryCard(
                label: 'Commissions',
                value: state.totalFilteredCommission,
                icon: Icons.person_outline,
                color: Colors.orange,
              ),
              _SummaryCard(
                label: 'Payments',
                value: state.payments.length.toDouble(),
                icon: Icons.receipt_long,
                color: Colors.blue,
                isInteger: true,
              ),
            ];

            return isMobile
                ? Column(
                    children: cards
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: c,
                          ),
                        )
                        .toList(),
                  )
                : Row(
                    children: cards
                        .map(
                          (c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: c,
                            ),
                          ),
                        )
                        .toList(),
                  );
          },
        ),

        const SizedBox(height: 16),

        // Selection Action Bar
        BlocBuilder<BillingCubit, BillingState>(
          builder: (context, state) {
            if (state.payments.isEmpty) return const SizedBox.shrink();
            final isAllSelected = state.payments.isNotEmpty &&
                state.payments.every((p) => _selectedPaymentIds.contains(p.paymentId));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Checkbox(
                    value: isAllSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPaymentIds.addAll(
                            state.payments
                                .map((p) => p.paymentId)
                                .whereType<int>(),
                          );
                        } else {
                          _selectedPaymentIds.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAllSelected ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_selectedPaymentIds.isNotEmpty)
                    Chip(
                      label: Text(
                        '${_selectedPaymentIds.length} selected',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      deleteIcon: const Icon(Icons.clear, size: 14),
                      onDeleted: () {
                        setState(() {
                          _selectedPaymentIds.clear();
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),

        // Payments list
        Expanded(
          child: _PaymentList(
            onRefresh: _applyFilters,
            selectedPaymentIds: _selectedPaymentIds,
            onSelectionChanged: (paymentId, selected) {
              setState(() {
                if (selected) {
                  _selectedPaymentIds.add(paymentId);
                } else {
                  _selectedPaymentIds.remove(paymentId);
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isMobile
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateFilter(
                              context,
                              'From',
                              _startDate,
                              (d) => setState(() => _startDate = d),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDateFilter(
                              context,
                              'To',
                              _endDate,
                              (d) => setState(() => _endDate = d),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDoctorFilter(state),
                      const SizedBox(height: 12),
                      _buildPatientFilter(),
                      const SizedBox(height: 12),
                      _buildServiceFilter(state),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Filters'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildDateFilter(
                              context,
                              'From',
                              _startDate,
                              (d) => setState(() => _startDate = d),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: _buildDateFilter(
                              context,
                              'To',
                              _endDate,
                              (d) => setState(() => _endDate = d),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildDoctorFilter(state)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildPatientFilter()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildServiceFilter(state)),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: IconButton(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Reset Filters',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildDateFilter(
    BuildContext context,
    String label,
    DateTime date,
    Function(DateTime) onPicked,
  ) {
    return _FilterItem(
      label: label,
      child: OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            initialDate: date,
          );
          if (picked != null) {
            onPicked(picked);
            _applyFilters();
          }
        },
        icon: const Icon(Icons.calendar_today, size: 14),
        label: Text(
          DateFormat('dd/MM').format(date),
          style: const TextStyle(fontSize: 10),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildDoctorFilter(BillingState state) {
    return _FilterItem(
      label: 'Doctor',
      child: DropdownButtonFormField<int>(
        initialValue: _selectedDoctorId,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(),
        ),
        hint: const Text('All Doctors', style: TextStyle(fontSize: 12)),
        items: [
          const DropdownMenuItem<int>(
            value: null,
            child: Text('All Doctors', style: TextStyle(fontSize: 12)),
          ),
          ...state.doctors.map(
            (doc) => DropdownMenuItem<int>(
              value: doc.employeeId,
              child: Text(doc.fullName, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
        onChanged: (val) {
          setState(() => _selectedDoctorId = val);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildPatientFilter() {
    return _FilterItem(
      label: 'Patient Name',
      child: TextField(
        controller: _patientController,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          hintText: 'Search patient...',
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildServiceFilter(BillingState state) {
    return _FilterItem(
      label: 'Service',
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(),
        ),
        hint: const Text('All Services', style: TextStyle(fontSize: 12)),
        initialValue: _serviceController.text.isEmpty
            ? null
            : _serviceController.text,
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('All Services', style: TextStyle(fontSize: 12)),
          ),
          ...state.services.map(
            (service) => DropdownMenuItem<String>(
              value: service.serviceName,
              child: Text(
                service.serviceName,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
        onChanged: (val) {
          setState(() {
            _serviceController.text = val ?? '';
          });
          _applyFilters();
        },
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final String label;
  final Widget child;

  const _FilterItem({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PaymentList extends StatelessWidget {
  final VoidCallback? onRefresh;
  final Set<int> selectedPaymentIds;
  final void Function(int, bool) onSelectionChanged;

  const _PaymentList({
    this.onRefresh,
    required this.selectedPaymentIds,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        if (state.isLoading && state.payments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null && state.payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${state.error}'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      context.read<BillingCubit>().loadAllPayments(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final payments = state.payments;

        if (payments.isEmpty && !state.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No payments found',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return _PaymentCard(
              payment: payment,
              onRefresh: onRefresh,
              isSelected: selectedPaymentIds.contains(payment.paymentId),
              onSelectedChanged: (val) {
                if (payment.paymentId != null) {
                  onSelectionChanged(payment.paymentId!, val ?? false);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final Payment payment;
  final VoidCallback? onRefresh;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const _PaymentCard({
    required this.payment,
    this.onRefresh,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  double _commission = 0.0;
  List<PaymentService> _services = [];
  bool _isLoadingServices = false;

  @override
  void initState() {
    super.initState();
    _loadServicesAndCommission();
  }

  Future<void> _loadServicesAndCommission() async {
    if (widget.payment.paymentId != null) {
      setState(() => _isLoadingServices = true);
      final repo = PaymentRepository();
      final result = await repo.getServicesByPaymentId(widget.payment.paymentId!);
      result.fold(
        (failure) {
          setState(() {
            _commission = 0.0;
            _services = [];
            _isLoadingServices = false;
          });
        },
        (services) {
          final total = services.fold<double>(0, (sum, s) => sum + s.doctorCommission);
          setState(() {
            _commission = total;
            _services = services;
            _isLoadingServices = false;
          });
        },
      );
    }
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => InvoicePrintDialog(payment: widget.payment),
    );
  }

  void _editPayment(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => InvoiceFormDialog(payment: widget.payment),
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<BillingCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text(
          'Are you sure you want to delete this payment record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (widget.payment.paymentId != null) {
                await cubit.deletePayment(widget.payment.paymentId!);
                widget.onRefresh?.call();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final patientName = '${widget.payment.patientName ?? ""} ${widget.payment.patientSurname ?? ""}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Checkbox(
                value: widget.isSelected,
                onChanged: widget.onSelectedChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_long, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment #${widget.payment.paymentId ?? "N/A"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        patientName.isEmpty ? 'No patient' : patientName,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editPayment(context);
                        break;
                      case 'print':
                        _showDetails(context);
                        break;
                      case 'delete':
                        _confirmDelete(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, size: 20),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                        leading: Icon(Icons.print, size: 20),
                        title: Text('Print/Details'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, size: 20, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateFormat('dd/MM/yyyy').format(widget.payment.paymentDate),
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.account_balance_wallet,
                    label: 'Total',
                    value: '${widget.payment.amount.toStringAsFixed(2)} DA',
                    valueColor: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.check_circle,
                    label: 'Status',
                    value: 'PAID',
                    valueColor: Colors.green,
                    badge: true,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Commission',
                    value: '${_commission.toStringAsFixed(2)} DA',
                    valueColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Services',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            _isLoadingServices
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _services.isEmpty
                    ? Text(
                        widget.payment.servicesText ?? 'No services listed',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _services.map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Text(
                              '${s.serviceName} (${s.servicePrice.toStringAsFixed(2)} DA)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool badge;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            badge
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isInteger;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isInteger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isInteger
                        ? value.toInt().toString()
                        : '${value.toStringAsFixed(2)} DA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
