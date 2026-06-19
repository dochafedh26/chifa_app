import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

class Service extends Equatable {
  final int? serviceId;
  final String serviceName;
  final double price;
  final DateTime createdAt;
  final String? specialization;
  final double doctorCommission;

  Service({
    this.serviceId,
    required this.serviceName,
    required this.price,
    DateTime? createdAt,
    this.specialization,
    this.doctorCommission = 0.0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'service_id': serviceId,
      'service_name': serviceName,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'specialization': specialization,
      'doctor_commission': doctorCommission,
    };
  }

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      serviceId: DbUtils.toInt(map['service_id']),
      serviceName: DbUtils.toStringValue(map['service_name']),
      price: DbUtils.toDouble(map['price']),
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
      specialization: map['specialization'] as String?,
      doctorCommission: DbUtils.toDouble(map['doctor_commission']),
    );
  }

  Service copyWith({
    int? serviceId,
    String? serviceName,
    double? price,
    DateTime? createdAt,
    String? specialization,
    double? doctorCommission,
  }) {
    return Service(
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      specialization: specialization ?? this.specialization,
      doctorCommission: doctorCommission ?? this.doctorCommission,
    );
  }

  @override
  List<Object?> get props => [
    serviceId,
    serviceName,
    price,
    createdAt,
    specialization,
    doctorCommission,
  ];
}
