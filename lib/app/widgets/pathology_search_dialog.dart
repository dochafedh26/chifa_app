import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/pathology/pathology_scraper_service.dart';

class PathologySearchDialog extends StatefulWidget {
  final Function(String) onInsertTreatment;

  const PathologySearchDialog({super.key, required this.onInsertTreatment});

  @override
  State<PathologySearchDialog> createState() => _PathologySearchDialogState();
}

class _PathologySearchDialogState extends State<PathologySearchDialog> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final res = await PathologyScraperService.instance.scrapePathology(query);
      if (res != null) {
        if (res['status'] == 'success') {
          setState(() {
            _result = res;
          });
        } else {
          setState(() {
            _error = res['message'] ?? 'Erreur : Pathologie non trouvée';
          });
        }
      } else {
        setState(() {
          _error = 'Impossible de contacter le service de recherche.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Une erreur est survenue : $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search_outlined, color: primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Assistant Médical IA - Pathologies',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Input Box
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Saisir le nom de la pathologie (ex: AVC, Asthme, Angine...)',
                        prefixIcon: const Icon(Icons.medication_liquid_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _search,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Rechercher'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Suggestions / Error or Loading or Results
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Génération du guide clinique par l\'IA en cours...'),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Card(
                              color: Colors.red.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _result == null
                            ? const Center(
                                child: Text(
                                  'Saisissez une pathologie pour que l\'Assistant IA génère les recommandations et prescriptions.',
                                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              )
                            : _buildResultsTabs(context, _result!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsTabs(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final definition = data['definition'] as String? ?? '';
    final symptomes = data['symptomes'] as String? ?? '';
    final diagnostic = data['diagnostic'] as String? ?? '';
    final traitements = data['traitements'] as String? ?? '';
    final matchedPathology = data['matched_pathology'] as String? ?? '';
    final suggestions = data['suggestions'] as List? ?? [];

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle showing matched pathology name
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      children: [
                        const TextSpan(text: 'Pathologie trouvée : '),
                        TextSpan(
                          text: matchedPathology,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // AI Mode Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.purple.shade700,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Optimisé par IA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Bar Headers
          TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.primaryColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: 'Définition'),
              Tab(icon: Icon(Icons.warning_amber_outlined), text: 'Symptômes'),
              Tab(icon: Icon(Icons.checklist_outlined), text: 'Diagnostic'),
              Tab(icon: Icon(Icons.health_and_safety_outlined), text: 'Traitements'),
            ],
          ),
          const SizedBox(height: 12),

          // Tab View Content
          Expanded(
            child: TabBarView(
              children: [
                _buildContentTab(context, 'Définition', definition),
                _buildContentTab(context, 'Symptômes', symptomes),
                _buildContentTab(context, 'Diagnostic', diagnostic),
                _buildContentTab(context, 'Traitements', traitements, showInsertButton: true),
              ],
            ),
          ),

          // Alternative suggestions footer if any
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Suggestions : ${suggestions.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentTab(BuildContext context, String title, String content, {bool showInsertButton = false}) {
    if (content.trim().isEmpty) {
      return Center(
        child: Text(
          'Aucune information disponible pour la section "$title".',
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ),
        if (showInsertButton) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              widget.onInsertTreatment(content);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Traitements insérés dans l\'ordonnance'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.add_task),
            label: const Text('Insérer les traitements dans la prescription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
