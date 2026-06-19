import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

enum PaymentMethod { cash, creditCard, insurance }

enum InvoiceStatus { paid, unpaid, pending }

class Invoice extends Equatable {
  final int? invoiceId;
  final int patientId;
  final int? appointmentId;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final InvoiceStatus status;
  final DateTime issueDate;
  final DateTime dueDate;

  const Invoice({
    this.invoiceId,
    required this.patientId,
    this.appointmentId,
    required this.totalAmount,
    required this.paymentMethod,
    this.status = InvoiceStatus.unpaid,
    required this.issueDate,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'invoice_id': invoiceId,
      'patient_id': patientId,
      'appointment_id': appointmentId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod.name,
      'status': status.name,
      'issue_date': issueDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      invoiceId: DbUtils.toInt(map['invoice_id']),
      patientId: DbUtils.toInt(map['patient_id']),
      appointmentId: map['appointment_id'] != null
          ? DbUtils.toInt(map['appointment_id'])
          : null,
      totalAmount: DbUtils.toDouble(map['total_amount']),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            map['payment_method']?.toString().toLowerCase(),
        orElse: () => PaymentMethod.cash,
      ),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == map['status']?.toString().toLowerCase(),
        orElse: () => InvoiceStatus.unpaid,
      ),
      issueDate: map['issue_date'] is DateTime
          ? map['issue_date'] as DateTime
          : (DateTime.tryParse(map['issue_date']?.toString() ?? '') ??
                DateTime.now()),
      dueDate: map['due_date'] is DateTime
          ? map['due_date'] as DateTime
          : (DateTime.tryParse(map['due_date']?.toString() ?? '') ??
                DateTime.now()),
    );
  }

  Invoice copyWith({
    int? invoiceId,
    int? patientId,
    int? appointmentId,
    double? totalAmount,
    PaymentMethod? paymentMethod,
    InvoiceStatus? status,
    DateTime? issueDate,
    DateTime? dueDate,
  }) {
    return Invoice(
      invoiceId: invoiceId ?? this.invoiceId,
      patientId: patientId ?? this.patientId,
      appointmentId: appointmentId ?? this.appointmentId,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  @override
  List<Object?> get props => [
    invoiceId,
    patientId,
    appointmentId,
    totalAmount,
    paymentMethod,
    status,
    issueDate,
    dueDate,
  ];
}
