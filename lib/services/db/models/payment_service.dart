import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

class PaymentService extends Equatable {
  final int? id;
  final int? paymentId;
  final int? serviceId;
  final String serviceName;
  final double servicePrice;
  final double doctorCommission;

  const PaymentService({
    this.id,
    this.paymentId,
    this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.doctorCommission,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'payment_id': paymentId,
      'service_id': serviceId,
      'service_name': serviceName,
      'service_price': servicePrice,
      'doctor_commission': doctorCommission,
    };
  }

  factory PaymentService.fromMap(Map<String, dynamic> map) {
    return PaymentService(
      id: DbUtils.toInt(map['id']),
      paymentId: DbUtils.toInt(map['payment_id']),
      serviceId: DbUtils.toInt(map['service_id']),
      serviceName: DbUtils.toStringValue(map['service_name']),
      servicePrice: DbUtils.toDouble(map['service_price']),
      doctorCommission: DbUtils.toDouble(map['doctor_commission']),
    );
  }

  PaymentService copyWith({
    int? id,
    int? paymentId,
    int? serviceId,
    String? serviceName,
    double? servicePrice,
    double? doctorCommission,
  }) {
    return PaymentService(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      servicePrice: servicePrice ?? this.servicePrice,
      doctorCommission: doctorCommission ?? this.doctorCommission,
    );
  }

  @override
  List<Object?> get props => [
    id,
    paymentId,
    serviceId,
    serviceName,
    servicePrice,
    doctorCommission,
  ];
}
