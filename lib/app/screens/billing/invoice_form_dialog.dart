import 'package:chifa/app/cubits/billing_cubit.dart';
import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/app/cubits/patient_cubit.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:chifa/services/db/models/invoice.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:chifa/services/db/models/payment.dart';
import 'package:chifa/services/db/models/payment_service.dart';
import 'package:chifa/services/db/models/service.dart';
import 'package:chifa/services/db/models/soins_service.dart';
import 'package:chifa/app/cubits/soins_service_cubit.dart';

import 'package:chifa/services/db/repositories/payment_repository.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Invoice Form Dialog - Create new invoice or edit existing one
class InvoiceFormDialog extends StatefulWidget {
  final Payment? payment;

  const InvoiceFormDialog({super.key, this.payment});

  @override
  State<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _patientSearchController = TextEditingController();
  final _appointmentIdController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _selectedServices = <Service>[];
  final _serviceSearchController = TextEditingController();
  final _selectedSoins = <SoinsService>[];
  final _soinSearchController = TextEditingController();
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DateTime _paymentDate = DateTime.now();
  final _notesController = TextEditingController();
  Patient? _selectedPatient;
  String? _patientName;
  String? _patientSurname;
  List<Service> _allServices = [];
  List<Service> _filteredServices = [];
  List<SoinsService> _allSoins = [];
  List<SoinsService> _filteredSoins = [];

  // Remise (Discount)
  String _discountType = 'money'; // 'money' (DA) or 'percentage' (%)
  final _discountController = TextEditingController();
  double _discountAmount = 0.0;
  double _subtotalBeforeDiscount = 0.0;

  // Remise Commission Medecin
  bool _applyDoctorDiscount = true;
  String _discountCommissionType = 'proportional'; // 'proportional', 'percentage', 'money'
  final _discountCommissionController = TextEditingController();
  double _discountCommissionAmount = 0.0;
  double _grossDoctorCommission = 0.0;
  double _totalDoctorCommission = 0.0;

  @override
  void initState() {
    super.initState();
    context.read<BillingCubit>().loadServices();
    context.read<SoinsServiceCubit>().loadServices();

    if (widget.payment != null) {
      _patientIdController.text = widget.payment!.patientId?.toString() ?? '';
      _totalAmountController.text = widget.payment!.amount.toStringAsFixed(2);
      _notesController.text = widget.payment!.notes ?? '';
      _paymentDate = widget.payment!.paymentDate;
      _patientName = widget.payment!.patientName;
      _patientSurname = widget.payment!.patientSurname;
      _paymentMethod = PaymentMethod.values.firstWhere(
        (e) => e.name == widget.payment!.paymentMethod,
        orElse: () => PaymentMethod.cash,
      );
      _discountType = widget.payment!.discountType;
      _discountAmount = widget.payment!.discountAmount;
      _discountController.text = widget.payment!.discountValue > 0
          ? widget.payment!.discountValue.toStringAsFixed(widget.payment!.discountType == 'percentage' ? 1 : 0)
          : '';
      _applyDoctorDiscount = widget.payment!.applyCommissionDiscount;
      _discountCommissionType = widget.payment!.discountCommissionType;
      _discountCommissionController.text = widget.payment!.discountCommissionValue > 0
          ? widget.payment!.discountCommissionValue.toStringAsFixed(widget.payment!.discountCommissionType == 'percentage' ? 1 : 0)
          : '';
      _discountCommissionAmount = widget.payment!.discountCommissionAmount;
      _loadPaymentServices();
    } else {
      // For new payments, focus on patient search
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _patientSearchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _patientSearchController.text.length),
        );
      });
    }
  }

  Future<void> _loadPaymentServices() async {
    if (widget.payment?.paymentId == null) return;
    try {
      final repo = PaymentRepository();
      final result = await repo.getServicesByPaymentId(
        widget.payment!.paymentId!,
      );
      result.fold((_) {}, (services) {
        if (!mounted) return;
        final acts = <Service>[];
        final soins = <SoinsService>[];
        for (final ps in services) {
          if (ps.serviceType == 'soin') {
            soins.add(
              SoinsService(
                id: ps.serviceId,
                nom: ps.serviceName,
                price: ps.servicePrice,
                doctorCommission: ps.doctorCommission,
              ),
            );
          } else {
            acts.add(
              Service(
                serviceId: ps.serviceId,
                serviceName: ps.serviceName,
                price: ps.servicePrice,
                doctorCommission: ps.doctorCommission,
              ),
            );
          }
        }
        setState(() {
          _selectedServices.clear();
          _selectedServices.addAll(acts);
          _selectedSoins.clear();
          _selectedSoins.addAll(soins);
          _recalculateTotal();
        });
      });
    } catch (_) {}
  }

  void _recalculateTotal() {
    final actsTotal = _selectedServices.fold(0.0, (sum, s) => sum + s.price);
    final soinsTotal = _selectedSoins.fold(0.0, (sum, s) => sum + s.price);
    _subtotalBeforeDiscount = actsTotal + soinsTotal;

    final discVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
    if (discVal > 0 && _subtotalBeforeDiscount > 0) {
      if (_discountType == 'percentage') {
        _discountAmount = (_subtotalBeforeDiscount * discVal / 100.0).clamp(0.0, _subtotalBeforeDiscount);
      } else {
        _discountAmount = discVal.clamp(0.0, _subtotalBeforeDiscount);
      }
    } else {
      _discountAmount = 0.0;
    }

    final total = (_subtotalBeforeDiscount - _discountAmount).clamp(0.0, double.infinity);
    _totalAmountController.text = total.toStringAsFixed(2);

    final actsCommission = _selectedServices.fold(0.0, (sum, s) => sum + s.doctorCommission);
    final soinsCommission = _selectedSoins.fold(0.0, (sum, s) => sum + s.doctorCommission);
    _grossDoctorCommission = actsCommission + soinsCommission;

    if (_applyDoctorDiscount && _grossDoctorCommission > 0 && _discountAmount > 0) {
      if (_discountCommissionType == 'proportional') {
        final rate = _subtotalBeforeDiscount > 0 ? (_discountAmount / _subtotalBeforeDiscount) : 0.0;
        _discountCommissionAmount = (_grossDoctorCommission * rate).clamp(0.0, _grossDoctorCommission);
      } else if (_discountCommissionType == 'percentage') {
        final customVal = double.tryParse(_discountCommissionController.text.trim()) ?? 0.0;
        _discountCommissionAmount = (_grossDoctorCommission * customVal / 100.0).clamp(0.0, _grossDoctorCommission);
      } else {
        final customVal = double.tryParse(_discountCommissionController.text.trim()) ?? 0.0;
        _discountCommissionAmount = customVal.clamp(0.0, _grossDoctorCommission);
      }
    } else {
      _discountCommissionAmount = 0.0;
    }

    _totalDoctorCommission = (_grossDoctorCommission - _discountCommissionAmount).clamp(0.0, double.infinity);
  }

  void _addSoin(SoinsService soin) {
    setState(() {
      _selectedSoins.add(soin);
      _recalculateTotal();
    });
  }

  void _removeSoin(SoinsService soin) {
    setState(() {
      _selectedSoins.remove(soin);
      _recalculateTotal();
      _filterSoins(_soinSearchController.text);
    });
  }

  void _filterSoins(String query) {
    if (_allSoins.isEmpty) return;
    setState(() {
      if (query.isEmpty) {
        _filteredSoins = _allSoins
            .where(
              (s) => !_selectedSoins.any(
                (selected) => selected.id == s.id,
              ),
            )
            .toList();
      } else {
        _filteredSoins = _allSoins
            .where(
              (s) =>
                  !_selectedSoins.any((selected) => selected.id == s.id) &&
                  s.nom.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _filterServices(String query) {
    if (_allServices.isEmpty) return;
    setState(() {
      if (query.isEmpty) {
        _filteredServices = _allServices
            .where(
              (s) => !_selectedServices.any(
                (selected) => selected.serviceId == s.serviceId,
              ),
            )
            .toList();
      } else {
        _filteredServices = _allServices
            .where(
              (s) =>
                  s.serviceName.toLowerCase().contains(query.toLowerCase()) &&
                  !_selectedServices.any(
                    (selected) => selected.serviceId == s.serviceId,
                  ),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _patientSearchController.dispose();
    _appointmentIdController.dispose();
    _totalAmountController.dispose();
    _serviceSearchController.dispose();
    _soinSearchController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  void _onPatientSelected(Patient patient) {
    setState(() {
      _selectedPatient = patient;
      _patientIdController.text = patient.patientId!.toString();
      _patientName = patient.firstName;
      _patientSurname = patient.lastName;
      _patientSearchController.text =
          '${patient.firstName} ${patient.lastName}';
    });
  }

  void _addService(Service service) {
    setState(() {
      _selectedServices.add(service);
      _serviceSearchController.clear();
      _filterServices('');
      _recalculateTotal();
    });
  }

  void _removeService(Service service) {
    setState(() {
      _selectedServices.remove(service);
      _recalculateTotal();
      _filterServices(_serviceSearchController.text);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_patientIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient selection is required')),
      );
      return;
    }

    final actsText = _selectedServices.map((s) => s.serviceName).join(', ');
    final soinsText = _selectedSoins.map((s) => s.nom).join(', ');
    final servicesText = actsText.isNotEmpty && soinsText.isNotEmpty
        ? 'Actes: $actsText | Soins: $soinsText'
        : (actsText.isNotEmpty ? actsText : soinsText);

    final discVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final discComVal = double.tryParse(_discountCommissionController.text.trim()) ?? 0.0;
    final payment = Payment(
      paymentId: widget.payment?.paymentId,
      patientId: int.parse(_patientIdController.text),
      patientName: _patientName,
      patientSurname: _patientSurname,
      amount: double.tryParse(_totalAmountController.text) ?? 0.0,
      paymentMethod: _paymentMethod.name,
      paymentDate: _paymentDate,
      notes: _notesController.text,
      servicesText: servicesText,
      recordId: widget.payment?.recordId,
      discountAmount: _discountAmount,
      discountType: _discountType,
      discountValue: discVal,
      discountCommissionAmount: _discountCommissionAmount,
      discountCommissionType: _discountCommissionType,
      discountCommissionValue: discComVal,
      applyCommissionDiscount: _applyDoctorDiscount,
    );

    final commissionRatio = (_grossDoctorCommission > 0 && _discountCommissionAmount > 0)
        ? (1.0 - (_discountCommissionAmount / _grossDoctorCommission)).clamp(0.0, 1.0)
        : 1.0;

    final paymentServices = [
      ..._selectedServices.map(
        (s) => PaymentService(
          serviceId: s.serviceId,
          serviceName: s.serviceName,
          servicePrice: s.price,
          doctorCommission: (s.doctorCommission * commissionRatio).clamp(0.0, s.price),
          serviceType: 'act',
        ),
      ),
      ..._selectedSoins.map(
        (s) => PaymentService(
          serviceId: s.id,
          serviceName: s.nom,
          servicePrice: s.price,
          doctorCommission: (s.doctorCommission * commissionRatio).clamp(0.0, s.price),
          serviceType: 'soin',
        ),
      ),
    ];

    if (widget.payment != null) {
      context.read<BillingCubit>().updatePaymentWithServices(
        widget.payment!.paymentId!,
        payment,
        paymentServices,
      );
    } else {
      context.read<BillingCubit>().createPaymentWithServices(
        payment,
        paymentServices,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.payment != null;
    final theme = Theme.of(context);

    return BlocListener<BillingCubit, BillingState>(
      listenWhen: (previous, current) =>
          previous.successMessage != current.successMessage ||
          previous.error != current.error,
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
          context.read<BillingCubit>().clearSuccessMessage();
          Navigator.pop(context);
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
          context.read<BillingCubit>().clearError();
        }
      },
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? 'Edit Payment' : 'New Payment'),
            if (isEditing) ...[
              const SizedBox(height: 4),
              Text(
                'Payment #${widget.payment?.paymentId ?? "N/A"}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Patient Details Section
                  _buildSectionHeader('Patient Information', Icons.person),
                  const SizedBox(height: 8),

                  // Patient Search
                  BlocBuilder<PatientCubit, PatientState>(
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _patientSearchController,
                            decoration: InputDecoration(
                              labelText: 'Patient Name',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person_search),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                            readOnly: true,
                          ),
                        ],
                      );
                    },
                  ),

                  // Record Details
                  if (widget.payment?.recordId != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Record ID: ${widget.payment!.recordId}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Payment Details Section (only for new payments)
                  if (!isEditing) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader('Payment Details', Icons.payment),
                    const SizedBox(height: 8),

                    // Payment Method
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: PaymentMethod.values.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(_formatPaymentMethod(method)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _paymentMethod = value!);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Payment Date
                    InkWell(
                      onTap: _selectPaymentDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(_paymentDate)),
                            TextButton(
                              onPressed: _selectPaymentDate,
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),
                  ],

                  // Services Section
                  _buildSectionHeader('Services', Icons.medical_services),
                  const SizedBox(height: 8),

                  // Selected services list
                  if (_selectedServices.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedServices.map((service) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    service.serviceName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${service.price.toStringAsFixed(2)} DA',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isEditing)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: InkWell(
                                  onTap: () => _removeService(service),
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Service search and selector (only for new payments or adding to existing)
                  if (!isEditing || true) ...[
                    // Allow adding for editing as well
                    BlocBuilder<BillingCubit, BillingState>(
                      builder: (context, state) {
                        // Initialize filtered services when services load
                        if (_allServices.isEmpty && state.services.isNotEmpty) {
                          // Defer state update to avoid calling setState during build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _allServices = state.services;
                            _filterServices(_serviceSearchController.text);
                          });
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Service search field
                            TextField(
                              controller: _serviceSearchController,
                              decoration: InputDecoration(
                                labelText: 'Search Services',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon:
                                    _serviceSearchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _serviceSearchController.clear();
                                          _filterServices('');
                                        },
                                      )
                                    : null,
                                isDense: true,
                              ),
                              onChanged: (value) => _filterServices(value),
                            ),
                            const SizedBox(height: 8),

                            // Service suggestions
                            if (_filteredServices.isNotEmpty &&
                                _serviceSearchController.text.isNotEmpty)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filteredServices.length,
                                  itemBuilder: (context, index) {
                                    final service = _filteredServices[index];
                                    return ListTile(
                                      title: Text(service.serviceName),
                                      subtitle: Text(
                                        '${service.price.toStringAsFixed(2)} DA | Commission: ${service.doctorCommission.toStringAsFixed(2)} DA',
                                      ),
                                      onTap: () => _addService(service),
                                    );
                                  },
                                ),
                              ),
                            if (_filteredServices.isEmpty &&
                                _serviceSearchController.text.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'No services found matching your search',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Soins & Injections Section
                  Text(
                    'Soins & Injections (Administrés)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_selectedSoins.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedSoins.map((soin) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    soin.nom,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${soin.price.toStringAsFixed(2)} DA',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: InkWell(
                                onTap: () => _removeSoin(soin),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  BlocBuilder<SoinsServiceCubit, SoinsServiceState>(
                    builder: (context, state) {
                      if (_allSoins.isEmpty && state.services.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _allSoins = state.services;
                          _filterSoins(_soinSearchController.text);
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _soinSearchController,
                            decoration: InputDecoration(
                              labelText: 'Rechercher un soin / médicament...',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.vaccines_outlined, size: 18),
                              suffixIcon: _soinSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _soinSearchController.clear();
                                        _filterSoins('');
                                      },
                                    )
                                  : null,
                              isDense: true,
                            ),
                            onChanged: (value) => _filterSoins(value),
                          ),
                          const SizedBox(height: 8),

                          if (_filteredSoins.isNotEmpty &&
                              _soinSearchController.text.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredSoins.length,
                                itemBuilder: (context, index) {
                                  final soin = _filteredSoins[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(soin.nom),
                                    subtitle: Text(
                                      '${soin.price.toStringAsFixed(2)} DA | Commission: ${soin.doctorCommission.toStringAsFixed(2)} DA',
                                    ),
                                    onTap: () => _addSoin(soin),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Remise / Discount Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.discount_outlined, size: 18, color: Colors.amber.shade900),
                                const SizedBox(width: 8),
                                Text(
                                  'Remise / Réduction (Optionnel)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                            if (_discountAmount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '- ${_discountAmount.toStringAsFixed(0)} DA ${_discountType == "percentage" ? "(-${_discountController.text}%)" : ""}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'money',
                                  label: Text('DA'),
                                ),
                                ButtonSegment<String>(
                                  value: 'percentage',
                                  label: Text('%'),
                                ),
                              ],
                              selected: {_discountType},
                              onSelectionChanged: (val) {
                                setState(() {
                                  _discountType = val.first;
                                  _recalculateTotal();
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _discountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: _discountType == 'percentage'
                                      ? 'Pourcentage de remise (%)'
                                      : 'Montant de remise (DA)',
                                  hintText: _discountType == 'percentage' ? 'Ex: 10 pour 10%' : 'Ex: 100 pour 100 DA',
                                  suffixText: _discountType == 'percentage' ? '%' : 'DA',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.percent, size: 18),
                                  suffixIcon: _discountController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _discountController.clear();
                                            setState(() {
                                              _recalculateTotal();
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _recalculateTotal();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_discountAmount > 0 || _discountController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.medical_information_outlined, size: 16, color: Colors.orange.shade800),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Réduire la commission médecin',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange.shade900),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _applyDoctorDiscount,
                                activeColor: Colors.orange.shade800,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  setState(() {
                                    _applyDoctorDiscount = val;
                                    _recalculateTotal();
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_applyDoctorDiscount) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment<String>(
                                      value: 'proportional',
                                      label: Text('Proportionnelle', style: TextStyle(fontSize: 11)),
                                    ),
                                    ButtonSegment<String>(
                                      value: 'custom',
                                      label: Text('Personnalisée', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                  selected: {_discountCommissionType == 'proportional' ? 'proportional' : 'custom'},
                                  onSelectionChanged: (val) {
                                    setState(() {
                                      if (val.first == 'proportional') {
                                        _discountCommissionType = 'proportional';
                                      } else {
                                        _discountCommissionType = 'percentage';
                                      }
                                      _recalculateTotal();
                                    });
                                  },
                                ),
                                if (_discountCommissionAmount > 0) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '- ${_discountCommissionAmount.toStringAsFixed(0)} DA',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_discountCommissionType != 'proportional') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment<String>(value: 'money', label: Text('DA', style: TextStyle(fontSize: 11))),
                                      ButtonSegment<String>(value: 'percentage', label: Text('%', style: TextStyle(fontSize: 11))),
                                    ],
                                    selected: {_discountCommissionType},
                                    onSelectionChanged: (val) {
                                      setState(() {
                                        _discountCommissionType = val.first;
                                        _recalculateTotal();
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _discountCommissionController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: _discountCommissionType == 'percentage' ? 'Remise com. (%)' : 'Remise com. (DA)',
                                        hintText: _discountCommissionType == 'percentage' ? 'Ex: 10' : 'Ex: 50',
                                        suffixText: _discountCommissionType == 'percentage' ? '%' : 'DA',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _discountCommissionController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 14),
                                                onPressed: () {
                                                  _discountCommissionController.clear();
                                                  setState(() {
                                                    _recalculateTotal();
                                                  });
                                                },
                                              )
                                            : null,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _recalculateTotal();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Amount
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (_discountAmount > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Brut: ${_subtotalBeforeDiscount.toStringAsFixed(2)} DA',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                'Remise: - ${_discountAmount.toStringAsFixed(2)} DA ${_discountType == "percentage" ? "(-${_discountController.text}%)" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Net à Payer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${_totalAmountController.text} DA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedServices.isNotEmpty || _selectedSoins.isNotEmpty) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Commission Médecin Nette',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '${_totalDoctorCommission.toStringAsFixed(2)} DA ${_discountCommissionAmount > 0 ? "(-${_discountCommissionAmount.toStringAsFixed(0)} DA)" : ""}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: Text(isEditing ? 'Update Payment' : 'Create Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  String _formatPaymentMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.insurance:
        return 'Insurance';
    }
  }
}
