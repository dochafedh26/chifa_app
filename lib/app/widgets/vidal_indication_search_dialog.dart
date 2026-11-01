import 'package:flutter/material.dart';
import '../../services/vidal/vidal_indication_service.dart';
import '../../services/db/database.dart';

class VidalIndicationSearchDialog extends StatefulWidget {
  final String? initialQuery;

  const VidalIndicationSearchDialog({
    super.key,
    this.initialQuery,
  });

  static Future<VidalMedicationItem?> show(
    BuildContext context, {
    String? initialQuery,
  }) {
    return showDialog<VidalMedicationItem>(
      context: context,
      builder: (context) => VidalIndicationSearchDialog(initialQuery: initialQuery),
    );
  }

  @override
  State<VidalIndicationSearchDialog> createState() =>
      _VidalIndicationSearchDialogState();
}

class _VidalIndicationSearchDialogState
    extends State<VidalIndicationSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingMeds = false;
  String? _errorMessage;

  List<VidalIndicationItem> _indications = [];
  List<VidalMedicationItem> _medications = [];
  VidalIndicationItem? _selectedIndication;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _indications = [];
      _medications = [];
      _selectedIndication = null;
    });

    final result =
        await VidalIndicationService.instance.searchByIndication(trimmed);

    if (!mounted) return;

    if (result != null && result.status == 'success') {
      setState(() {
        _isLoading = false;
        _indications = result.indications;
        _medications = result.medications;
        if (result.indications.isNotEmpty) {
          _selectedIndication = result.indications.first;
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Aucune indication ou médicament trouvé pour \"$trimmed\".";
      });
    }
  }

  Future<void> _loadMedicationsForIndication(VidalIndicationItem ind) async {
    setState(() {
      _selectedIndication = ind;
      _isLoadingMeds = true;
      _medications = [];
    });

    final onlineMeds = await VidalIndicationService.instance.fetchMedicationsForUrl(
      _searchController.text.trim(),
      ind.url,
    );

    List<VidalMedicationItem> finalMeds = onlineMeds;
    if (finalMeds.isEmpty) {
      finalMeds = await _fetchLocalMedications(ind.title);
    }

    if (!mounted) return;

    setState(() {
      _isLoadingMeds = false;
      _medications = finalMeds;
    });
  }

  List<String> _getClinicalTreatmentKeywords(String title, String userQuery) {
    final combined = '$title $userQuery'.toLowerCase();
    final List<String> keywords = [];

    if (combined.contains('otite')) {
      keywords.addAll(['otite', 'oflocet', 'polydexa', 'amoxicilline', 'augmentin', 'ciprofloxacine']);
    } else if (combined.contains('angine')) {
      keywords.addAll(['angine', 'amoxicilline', 'augmentin', 'cefuroxime', 'azithromycine']);
    } else if (combined.contains('hta') || combined.contains('hypertension')) {
      keywords.addAll(['hypertension', 'amlodipine', 'enalapril', 'lisinopril', 'ramipril', 'valsartan']);
    } else if (combined.contains('diab')) {
      keywords.addAll(['diabete', 'metformine', 'gliclazide', 'insuline']);
    } else if (combined.contains('asthme') || combined.contains('bronch')) {
      keywords.addAll(['asthme', 'ventoline', 'salbutamol', 'seretide']);
    } else {
      final words = combined
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((s) => s.length > 2 && !['des', 'les', 'par', 'aux', 'sur', 'pour', 'chez', 'avec', 'traitement', 'aigu', 'chronique'].contains(s))
          .toList();
      if (words.isNotEmpty) {
        keywords.add(words.first);
      }
    }
    return keywords;
  }

  Future<List<VidalMedicationItem>> _fetchLocalMedications(String term) async {
    try {
      final keywords = _getClinicalTreatmentKeywords(term, _searchController.text);
      if (keywords.isEmpty) return [];

      final Set<String> medNames = {};
      for (final kw in keywords.take(3)) {
        final rows = await DatabaseService().query(
          '''SELECT name, dci, dosage, formulation FROM medicaments 
             WHERE indication LIKE ? OR name LIKE ? OR dci LIKE ? LIMIT 20''',
          ['%$kw%', '%$kw%', '%$kw%'],
        );

        for (final r in rows) {
          final name = (r['name'] ?? '').toString().trim();
          final dosage = (r['dosage'] ?? '').toString().trim();
          final formulation = (r['formulation'] ?? '').toString().trim();
          final fullName = [name, dosage, formulation].where((s) => s.isNotEmpty).join(' ');
          if (fullName.isNotEmpty) {
            medNames.add(fullName);
          }
        }
      }

      return medNames.map((n) => VidalMedicationItem(name: n, url: '')).toList();
    } catch (e) {
      debugPrint("Error fetching local medications: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 650,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.medical_services_outlined, color: Colors.blue, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Recherche VIDAL par Indication',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Saisir une maladie ou indication (ex: Angine, HTA, Asthme...)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _performSearch(_searchController.text),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Rechercher'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),

            // Body content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Connexion et recherche sur VIDAL.fr en cours...'),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Indications List
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  child: const Text(
                                    'Indications Correspondantes',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Expanded(
                                  child: _indications.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'Aucune indication',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: _indications.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final ind = _indications[index];
                                            final isSelected = _selectedIndication?.url == ind.url;
                                            return ListTile(
                                              dense: true,
                                              selected: isSelected,
                                              selectedTileColor: Colors.blue.shade50,
                                              title: Text(
                                                ind.title,
                                                style: TextStyle(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  color: isSelected ? Colors.blue.shade900 : Colors.black87,
                                                ),
                                              ),
                                              trailing: const Icon(Icons.chevron_right, size: 18),
                                              onTap: () => _loadMedicationsForIndication(ind),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Right Column: Medications / Specialties List
                        Expanded(
                          flex: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedIndication != null
                                              ? 'Médicaments pour: ${_selectedIndication!.title}'
                                              : 'Médicaments Spécialités VIDAL',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.blue.shade900,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _isLoadingMeds
                                      ? const Center(child: CircularProgressIndicator())
                                      : _medications.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Sélectionnez une indication pour afficher les médicaments',
                                                style: TextStyle(color: Colors.grey),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount: _medications.length,
                                              separatorBuilder: (_, __) => const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final med = _medications[index];
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(
                                                    med.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  trailing: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context).pop(med);
                                                    },
                                                    child: const Text('Choisir', style: TextStyle(fontSize: 12)),
                                                  ),
                                                );
                                              },
                                            ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
