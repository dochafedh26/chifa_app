import "package:equatable/equatable.dart";

class InterpretationEcg extends Equatable {
  final int? id;
  final String? uuid;
  final int patientId;
  final int? doctorId;
  final String? motif;
  final String rythme;
  final int frequenceCardiaque;
  final String axeQrs;
  final String ondeP;
  final String espacePr;
  final String complexeQrs;
  final String segmentSt;
  final String ondeT;
  final String intervalleQt;
  final String conclusion;
  final String? remarques;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool needsSync;
  final String? sourceId;
  final bool isDeleted;

  const InterpretationEcg({
    this.id,
    this.uuid,
    required this.patientId,
    this.doctorId,
    this.motif = 'Bilan systématique',
    this.rythme = 'Sinusal régulier',
    this.frequenceCardiaque = 75,
    this.axeQrs = 'Normal (~60°)',
    this.ondeP = 'Normale',
    this.espacePr = 'Normal (120-200 ms)',
    this.complexeQrs = 'Fin (< 100 ms)',
    this.segmentSt = 'Isoélectrique',
    this.ondeT = 'Positive et normale',
    this.intervalleQt = 'Normal',
    required this.conclusion,
    this.remarques,
    required this.createdAt,
    this.updatedAt,
    this.needsSync = false,
    this.sourceId = 'local_server',
    this.isDeleted = false,
  });

  factory InterpretationEcg.fromMap(Map<String, dynamic> map) {
    return InterpretationEcg(
      id: map['id'],
      uuid: map['uuid'],
      patientId: map['patient_id'] is int
          ? map['patient_id']
          : int.tryParse(map['patient_id']?.toString() ?? '0') ?? 0,
      doctorId: map['doctor_id'] != null
          ? (map['doctor_id'] is int
              ? map['doctor_id']
              : int.tryParse(map['doctor_id'].toString()))
          : null,
      motif: map['motif'] ?? 'Bilan systématique',
      rythme: map['rythme'] ?? 'Sinusal régulier',
      frequenceCardiaque: map['frequence_cardiaque'] is int
          ? map['frequence_cardiaque']
          : int.tryParse(map['frequence_cardiaque']?.toString() ?? '75') ?? 75,
      axeQrs: map['axe_qrs'] ?? 'Normal (~60°)',
      ondeP: map['onde_p'] ?? 'Normale',
      espacePr: map['espace_pr'] ?? 'Normal (120-200 ms)',
      complexeQrs: map['complexe_qrs'] ?? 'Fin (< 100 ms)',
      segmentSt: map['segment_st'] ?? 'Isoélectrique',
      ondeT: map['onde_t'] ?? 'Positive et normale',
      intervalleQt: map['intervalle_qt'] ?? 'Normal',
      conclusion: map['conclusion'] ?? '',
      remarques: map['remarques'],
      createdAt: map['created_at'] is DateTime
          ? map['created_at']
          : DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
              ? map['updated_at']
              : DateTime.tryParse(map['updated_at'].toString()))
          : null,
      needsSync: (map['needs_sync'] == 1 || map['needs_sync'] == true),
      sourceId: map['source_id']?.toString(),
      isDeleted: (map['is_deleted'] == 1 || map['is_deleted'] == true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'motif': motif,
      'rythme': rythme,
      'frequence_cardiaque': frequenceCardiaque,
      'axe_qrs': axeQrs,
      'onde_p': ondeP,
      'espace_pr': espacePr,
      'complexe_qrs': complexeQrs,
      'segment_st': segmentSt,
      'onde_t': ondeT,
      'intervalle_qt': intervalleQt,
      'conclusion': conclusion,
      'remarques': remarques,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
      if (sourceId != null) 'source_id': sourceId,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        patientId,
        doctorId,
        motif,
        rythme,
        frequenceCardiaque,
        axeQrs,
        ondeP,
        espacePr,
        complexeQrs,
        segmentSt,
        ondeT,
        intervalleQt,
        conclusion,
        remarques,
        createdAt,
        updatedAt,
        needsSync,
        sourceId,
        isDeleted,
      ];
}

