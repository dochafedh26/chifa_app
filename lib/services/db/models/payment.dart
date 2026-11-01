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
  final double discountAmount;
  final String discountType; // 'money' or 'percentage'
  final double discountValue;
  final double discountCommissionAmount;
  final String discountCommissionType; // 'proportional', 'percentage', 'money'
  final double discountCommissionValue;
  final bool applyCommissionDiscount;

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
    this.discountAmount = 0.0,
    this.discountType = 'money',
    this.discountValue = 0.0,
    this.discountCommissionAmount = 0.0,
    this.discountCommissionType = 'proportional',
    this.discountCommissionValue = 0.0,
    this.applyCommissionDiscount = true,
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
      'discount_amount': discountAmount,
      'discount_type': discountType,
      'discount_value': discountValue,
      'discount_commission_amount': discountCommissionAmount,
      'discount_commission_type': discountCommissionType,
      'discount_commission_value': discountCommissionValue,
      'apply_commission_discount': applyCommissionDiscount ? 1 : 0,
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
      discountAmount: DbUtils.toDouble(map['discount_amount']),
      discountType: DbUtils.toStringValue(map['discount_type']).isNotEmpty
          ? DbUtils.toStringValue(map['discount_type'])
          : 'money',
      discountValue: DbUtils.toDouble(map['discount_value']),
      discountCommissionAmount: DbUtils.toDouble(map['discount_commission_amount']),
      discountCommissionType: DbUtils.toStringValue(map['discount_commission_type']).isNotEmpty
          ? DbUtils.toStringValue(map['discount_commission_type'])
          : 'proportional',
      discountCommissionValue: DbUtils.toDouble(map['discount_commission_value']),
      applyCommissionDiscount: map['apply_commission_discount'] == null ||
          map['apply_commission_discount'] == 1 ||
          map['apply_commission_discount'] == true,
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
    double? discountAmount,
    String? discountType,
    double? discountValue,
    double? discountCommissionAmount,
    String? discountCommissionType,
    double? discountCommissionValue,
    bool? applyCommissionDiscount,
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
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountCommissionAmount:
          discountCommissionAmount ?? this.discountCommissionAmount,
      discountCommissionType:
          discountCommissionType ?? this.discountCommissionType,
      discountCommissionValue:
          discountCommissionValue ?? this.discountCommissionValue,
      applyCommissionDiscount:
          applyCommissionDiscount ?? this.applyCommissionDiscount,
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
    discountAmount,
    discountType,
    discountValue,
    discountCommissionAmount,
    discountCommissionType,
    discountCommissionValue,
    applyCommissionDiscount,
  ];
}
