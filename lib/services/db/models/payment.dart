import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

class Payment extends Equatable {
  final int? paymentId;
  final int? invoiceId;
  final int? patientId;
  final int? doctorId;
  final String? patientName;
  final String? patientSurname;
  final String? servicesText;
  final int? recordId;
  final double amount;
  final DateTime paymentDate;
  final String? paymentMethod;
  final String? notes;

  const Payment({
    this.paymentId,
    this.invoiceId,
    this.patientId,
    this.doctorId,
    this.patientName,
    this.patientSurname,
    this.servicesText,
    this.recordId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (patientId != null) 'patient_id': patientId,
      if (doctorId != null) 'doctor_id': doctorId,
      if (patientName != null) 'patient_name': patientName,
      if (patientSurname != null) 'patient_surname': patientSurname,
      if (servicesText != null) 'services': servicesText,
      if (recordId != null) 'record_id': recordId,
      'total_amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      if (paymentMethod != null)
        'payment_method': paymentMethod, // if table has it
      if (notes != null) 'note': notes, // DB uses 'note'
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      paymentId: DbUtils.toInt(map['payment_id']),
      invoiceId: DbUtils.toInt(map['invoice_id']),
      patientId: DbUtils.toInt(map['patient_id']),
      doctorId: DbUtils.toInt(map['doctor_id']),
      patientName: map['patient_name'] as String?,
      patientSurname: map['patient_surname'] as String?,
      servicesText: map['services'] as String?,
      recordId: DbUtils.toInt(map['record_id']),
      amount: DbUtils.toDouble(map['total_amount'] ?? map['amount']),
      paymentDate: map['payment_date'] is DateTime
          ? map['payment_date'] as DateTime
          : (DateTime.tryParse(map['payment_date']?.toString() ?? '') ??
                DateTime.now()),
      paymentMethod: map['payment_method'] as String?,
      notes: (map['note'] ?? map['notes'])?.toString(),
    );
  }

  Payment copyWith({
    int? paymentId,
    int? invoiceId,
    int? patientId,
    int? doctorId,
    String? patientName,
    String? patientSurname,
    String? servicesText,
    int? recordId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? notes,
  }) {
    return Payment(
      paymentId: paymentId ?? this.paymentId,
      invoiceId: invoiceId ?? this.invoiceId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      patientName: patientName ?? this.patientName,
      patientSurname: patientSurname ?? this.patientSurname,
      servicesText: servicesText ?? this.servicesText,
      recordId: recordId ?? this.recordId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    paymentId,
    invoiceId,
    patientId,
    doctorId,
    patientName,
    patientSurname,
    servicesText,
    recordId,
    amount,
    paymentDate,
    paymentMethod,
    notes,
  ];
}
