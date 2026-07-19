import 'package:chifa/app/cubits/bilan_cubit.dart';
import 'package:chifa/app/cubits/medical_record_cubit.dart';
import 'package:chifa/services/db/models/bilan.dart';
import 'package:chifa/services/db/models/medical_record.dart';
import 'package:chifa/services/db/models/patient.dart';
import 'package:flutter/material.dart';
import 'package:chifa/app/widgets/rich_text_viewer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class PatientHistoryPanel extends StatefulWidget {
  final Patient patient;
  final Function(String) onImportPrescription;
  final Function(String) onImportDiagnostic;
  final Function(String) onImportMotif;
  final Function(String) onImportDetails;
  final Function(String) onImportSoins;

  const PatientHistoryPanel({
    super.key,
    required this.patient,
    required this.onImportPrescription,
    required this.onImportDiagnostic,
    required this.onImportMotif,
    required this.onImportDetails,
    required this.onImportSoins,
  });

  @override
  State<PatientHistoryPanel> createState() => _PatientHistoryPanelState();
}

class _PatientHistoryPanelState extends State<PatientHistoryPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistory();
  }

  void _loadHistory() {
    if (widget.patient.patientId != null) {
      context.read<MedicalRecordCubit>().loadMedicalRecordsByPatientId(
            widget.patient.patientId!,
          );
      context.read<BilanCubit>().loadBilansByPatientId(
            widget.patient.patientId!,
          );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.shade900,
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dossier Historique : ${widget.patient.fullName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                  tooltip: 'Actualiser',
                  onPressed: _loadHistory,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Tab bar
          Material(
            color: Colors.white,
            elevation: 1,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade900,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue.shade900,
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(
                  icon: Icon(Icons.calendar_view_day, size: 18),
                  text: 'Timeline',
                ),
                Tab(
                  icon: Icon(Icons.medication, size: 18),
                  text: 'Ordonnances',
                ),
                Tab(
                  icon: Icon(Icons.analytics, size: 18),
                  text: 'Analyses',
                ),
                Tab(
                  icon: Icon(Icons.monitor_heart, size: 18),
                  text: 'Constantes',
                ),
              ],
              labelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 10,
              ),
            ),
          ),
          // Tab view content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimelineTab(),
                _buildPrescriptionsTab(),
                _buildBilansTab(),
                _buildVitalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TIMELINE TAB ---
  Widget _buildTimelineTab() {
    return BlocBuilder<MedicalRecordCubit, MedicalRecordState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = state.medicalRecords
            .where((r) => r.isDeleted != true)
            .toList()
          ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

        if (records.isEmpty) {
          return _buildEmptyState('Aucune consultation antérieure enregistrée.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return _buildTimelineCard(record);
          },
        );
      },
    );
  }

  Widget _buildTimelineCard(MedicalRecord record) {
    final formattedDate = DateFormat('dd MMM yyyy à HH:mm').format(record.recordDate);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        key: PageStorageKey<int>(record.id ?? 0),
        leading: Icon(
          Icons.circle,
          size: 12,
          color: Colors.blue.shade700,
        ),
        title: Text(
          record.motif?.isNotEmpty == true ? record.motif! : 'Consultation Générale',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          formattedDate,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        childrenPadding: const EdgeInsets.all(12),
        expandedAlignment: Alignment.topLeft,
        children: [
          if (record.diagnostic?.isNotEmpty == true) ...[
            _buildImportableSection(
              title: 'Diagnostic',
              content: record.diagnostic!,
              onImport: () => widget.onImportDiagnostic(record.diagnostic!),
              iconColor: Colors.indigo.shade800,
            ),
            const SizedBox(height: 8),
          ],
          if (record.details.isNotEmpty) ...[
            _buildImportableSection(
              title: 'Détails / Observations',
              content: record.details,
              onImport: () => widget.onImportDetails(record.details),
              iconColor: Colors.grey.shade800,
            ),
            const SizedBox(height: 8),
          ],
          if (record.prescriptions?.isNotEmpty == true) ...[
            _buildImportableSection(
              title: 'Ordonnance',
              content: record.prescriptions!,
              onImport: () => widget.onImportPrescription(record.prescriptions!),
              iconColor: Colors.teal.shade800,
            ),
            const SizedBox(height: 8),
          ],
          if (record.soins?.isNotEmpty == true) ...[
            _buildImportableSection(
              title: 'Soins Médicaux',
              content: record.soins!,
              onImport: () => widget.onImportSoins(record.soins!),
              iconColor: Colors.red.shade800,
            ),
            const SizedBox(height: 8),
          ],
          _buildVitalsSummaryRow(record),
        ],
      ),
    );
  }

  Widget _buildImportableSection({
    required String title,
    required String content,
    required VoidCallback onImport,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.copy, size: 12),
              label: const Text('Importer', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: RichTextViewer(
            text: content,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsSummaryRow(MedicalRecord record) {
    final hasVitals = record.weight != null ||
        record.temperature != null ||
        record.tensionArterielle != null ||
        record.frequenceCardiaque != null ||
        record.spao2 != null;

    if (!hasVitals) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Constantes cliniques',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (record.weight != null)
              _buildMiniVitalBadge(Icons.scale, '${record.weight} kg'),
            if (record.temperature != null)
              _buildMiniVitalBadge(Icons.thermostat, '${record.temperature} °C'),
            if (record.tensionArterielle != null)
              _buildMiniVitalBadge(Icons.favorite, record.tensionArterielle!),
            if (record.frequenceCardiaque != null)
              _buildMiniVitalBadge(Icons.monitor_heart, '${record.frequenceCardiaque} bpm'),
            if (record.spao2 != null)
              _buildMiniVitalBadge(Icons.air, '${record.spao2} %'),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniVitalBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.blue.shade900),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  // --- PRESCRIPTIONS TAB ---
  Widget _buildPrescriptionsTab() {
    return BlocBuilder<MedicalRecordCubit, MedicalRecordState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = state.medicalRecords
            .where((r) => r.isDeleted != true && r.prescriptions?.isNotEmpty == true)
            .toList()
          ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

        if (records.isEmpty) {
          return _buildEmptyState('Aucune ordonnance antérieure disponible.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final formattedDate = DateFormat('dd/MM/yyyy').format(record.recordDate);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ordonnance du $formattedDate',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => widget.onImportPrescription(record.prescriptions!),
                          icon: const Icon(Icons.add_circle_outline, size: 14),
                          label: const Text('Importer', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      record.prescriptions!,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- LAB TESTS (BILANS) TAB ---
  Widget _buildBilansTab() {
    return BlocBuilder<BilanCubit, BilanState>(
      builder: (context, state) {
        if (state is BilanLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Bilan> bilans = [];
        if (state is BilansLoaded) {
          bilans = state.bilans.where((b) => b.isDeleted != true).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        if (bilans.isEmpty) {
          return _buildEmptyState('Aucune demande d\'analyse (bilan) antérieure.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: bilans.length,
          itemBuilder: (context, index) {
            final bilan = bilans[index];
            final formattedDate = DateFormat('dd/MM/yyyy').format(bilan.createdAt);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bilan d\'Analyses du $formattedDate',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.indigo,
                      ),
                    ),
                    const Divider(height: 16),
                    Text(
                      bilan.bilans,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- VITALS TAB ---
  Widget _buildVitalsTab() {
    return BlocBuilder<MedicalRecordCubit, MedicalRecordState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = state.medicalRecords
            .where((r) =>
                r.isDeleted != true &&
                (r.weight != null ||
                    r.temperature != null ||
                    r.tensionArterielle != null ||
                    r.frequenceCardiaque != null ||
                    r.spao2 != null))
            .toList()
          ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

        if (records.isEmpty) {
          return _buildEmptyState('Aucune constante physique enregistrée.');
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Historique des constantes cliniques',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(1.2), // Date
                  1: FlexColumnWidth(0.8), // Weight
                  2: FlexColumnWidth(0.8), // Temp
                  3: FlexColumnWidth(1.0), // BP (TA)
                  4: FlexColumnWidth(0.8), // FC
                  5: FlexColumnWidth(0.8), // SpO2
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Date', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Poids', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('Temp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('TA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('FC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(6), child: Text('SpO2', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                  ...records.map((r) {
                    final formattedDate = DateFormat('dd/MM/yy').format(r.recordDate);
                    return TableRow(
                      children: [
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(formattedDate, style: const TextStyle(fontSize: 10)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(r.weight != null ? '${r.weight} kg' : '-', style: const TextStyle(fontSize: 10)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(r.temperature != null ? '${r.temperature}°C' : '-', style: const TextStyle(fontSize: 10)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(r.tensionArterielle ?? '-', style: const TextStyle(fontSize: 10)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(r.frequenceCardiaque != null ? '${r.frequenceCardiaque}' : '-', style: const TextStyle(fontSize: 10)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(6), child: Text(r.spao2 != null ? '${r.spao2}%' : '-', style: const TextStyle(fontSize: 10)))),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
