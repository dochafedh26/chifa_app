import 'dart:convert';

class MachineProfile {
  final String id;
  final String name;
  final String relayUrl;
  final String token;
  final String? rdpToken;

  const MachineProfile({
    required this.id,
    required this.name,
    required this.relayUrl,
    required this.token,
    this.rdpToken,
  });

  MachineProfile copyWith({
    String? id,
    String? name,
    String? relayUrl,
    String? token,
    String? rdpToken,
  }) {
    return MachineProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      relayUrl: relayUrl ?? this.relayUrl,
      token: token ?? this.token,
      rdpToken: rdpToken ?? this.rdpToken,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relayUrl': relayUrl,
        'token': token,
        'rdpToken': rdpToken,
      };

  factory MachineProfile.fromJson(Map<String, dynamic> json) => MachineProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        relayUrl: json['relayUrl'] as String,
        token: json['token'] as String,
        rdpToken: json['rdpToken'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MachineProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MachineProfile($name, $relayUrl)';
}
