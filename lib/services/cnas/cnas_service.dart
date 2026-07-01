import 'dart:convert';
import 'dart:io';

class CnasBeneficiary {
  final String value;
  final String text;
  final String dfd;
  final String status;

  CnasBeneficiary({
    required this.value,
    required this.text,
    required this.dfd,
    required this.status,
  });

  factory CnasBeneficiary.fromJson(Map<String, dynamic> json) {
    return CnasBeneficiary(
      value: json['value'] as String,
      text: json['text'] as String,
      dfd: json['dfd'] as String,
      status: (json['status'] as String?) ?? 'valid',
    );
  }

  bool get isValid => status == 'valid' && !isDfdExpired;

  bool get isDfdExpired {
    try {
      final parts = dfd.split('/');
      if (parts.length != 3) return true;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final expiryDate = DateTime(year, month, day);
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      return expiryDate.isBefore(todayDateOnly);
    } catch (e) {
      return true;
    }
  }

  @override
  String toString() => '$text (DFD: $dfd, Statut: $status)';
}

class CnasService {
  static final CnasService instance = CnasService._internal();
  CnasService._internal();

  Future<List<CnasBeneficiary>> fetchBeneficiaries(String assuranceNumber) async {
    try {
      final scriptPath = 'scripts/cnas_prescription_flow.py';
      final result = await Process.run(
        'python',
        [scriptPath, '--mode', 'fetch', '--assurance', assuranceNumber],
      );

      final output = result.stdout.toString().trim();
      final jsonStart = output.indexOf('{"status"');
      if (jsonStart != -1) {
        final jsonStr = output.substring(jsonStart);
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          final list = data['beneficiaries'] as List;
          return list.map((item) => CnasBeneficiary.fromJson(item as Map<String, dynamic>)).toList();
        } else if (data['status'] == 'error') {
          throw Exception(data['message']);
        }
      }
      if (result.exitCode != 0 && result.stderr.toString().trim().isNotEmpty) {
        throw Exception(result.stderr.toString().trim());
      }
      throw Exception('Erreur de connexion au lecteur de carte ou données invalides.');
    } catch (e) {
      print('Error in fetchBeneficiaries: $e');
      rethrow;
    }
  }

  Future<bool> runPrescription({
    required String assuranceNumber,
    required String beneficiaryValue,
    required List<String> medicines,
  }) async {
    try {
      final scriptPath = 'scripts/cnas_prescription_flow.py';
      final medicinesJson = json.encode(medicines);
      final result = await Process.run(
        'python',
        [
          scriptPath,
          '--mode',
          'prescribe',
          '--assurance',
          assuranceNumber,
          '--beneficiary',
          beneficiaryValue,
          '--medicines',
          medicinesJson,
        ],
      );

      final output = result.stdout.toString().trim();
      final jsonStart = output.indexOf('{"status"');
      if (jsonStart != -1) {
        final jsonStr = output.substring(jsonStart);
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          return true;
        } else if (data['status'] == 'error') {
          throw Exception(data['message']);
        }
      }
      if (result.exitCode != 0 && result.stderr.toString().trim().isNotEmpty) {
        throw Exception(result.stderr.toString().trim());
      }
      throw Exception('Erreur lors de la validation de la prescription.');
    } catch (e) {
      print('Error in runPrescription: $e');
      rethrow;
    }
  }
}
