import "package:equatable/equatable.dart";

class BilanType extends Equatable {
  final int? id;
  final String name;
  final String bilans;

  const BilanType({
    this.id,
    required this.name,
    required this.bilans,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bilans': bilans,
    };
  }

  factory BilanType.fromMap(Map<String, dynamic> map) {
    return BilanType(
      id: map['id'] as int?,
      name: map['name'] as String,
      bilans: map['bilans'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name, bilans];
}
