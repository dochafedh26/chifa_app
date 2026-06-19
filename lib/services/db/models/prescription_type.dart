import "package:chifa/services/db/utils/db_utils.dart";
import "package:equatable/equatable.dart";

class PrescriptionType extends Equatable {
  final int? id;
  final String title;
  final String prescription;
  final DateTime? createdAt;

  const PrescriptionType({
    this.id,
    required this.title,
    required this.prescription,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'prescription': prescription,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory PrescriptionType.fromMap(Map<String, dynamic> map) {
    return PrescriptionType(
      id: DbUtils.toInt(map['id']),
      title: DbUtils.toStringValue(map['title']),
      prescription: DbUtils.toStringValue(map['prescription']),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, title, prescription, createdAt];
}
