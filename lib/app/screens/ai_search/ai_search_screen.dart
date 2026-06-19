import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/pathology/pathology_scraper_service.dart';
import '../../theme/app_theme.dart';

class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({super.key});

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;
  bool _driveContextUsed = false;
  List<Map<String, dynamic>> _driveSources = [];
  final List<String> _searchHistory = [];
  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _suggestedPathologies = [
    'Pneumonie', 'Diabète type 2', 'HTA', 'AVC',
    'Asthme', 'Tuberculose', 'Paludisme', 'Angine',
    'Insuffisance cardiaque', 'Sepsis',
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _searchController.text).trim();
    if (q.isEmpty) return;

    if (query != null) _searchController.text = query;

    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
      _driveContextUsed = false;
    });
    _fadeController.reset();

    if (!_searchHistory.contains(q)) {
      setState(() => _searchHistory.insert(0, q));
      if (_searchHistory.length > 10) _searchHistory.removeLast();
    }

    try {
      final res = await PathologyScraperService.instance.scrapePathology(q);
      if (!mounted) return;

      if (res != null && res['status'] == 'success') {
        final sources = (res['drive_sources'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _result = res;
          _driveSources = sources;
          _driveContextUsed = sources.isNotEmpty;
        });
        _fadeController.forward();
      } else {
        setState(() {
          _error = res?['message'] ?? 'Pathologie introuvable.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left sidebar: history + suggestions
                _buildLeftPanel(),
                // Main content
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.sidebarBackground,
            const Color(0xFF1E293B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assistant IA Clinique',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Guides cliniques enrichis par vos protocoles Google Drive',
                    style: TextStyle(
                      color: AppTheme.sidebarText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Drive badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a73e8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1a73e8).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_done_rounded,
                        size: 13, color: Color(0xFF4fc3f7)),
                    const SizedBox(width: 5),
                    Text(
                      'Google Drive PDFs',
                      style: TextStyle(
                        color: const Color(0xFF4fc3f7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText:
                          'Rechercher une pathologie (ex: Pneumonie, HTA, Asthme...)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      filled: false,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          children: [
                            Icon(Icons.send_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Analyser',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppTheme.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggested
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'SUGGESTIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ..._suggestedPathologies.map((p) => _buildSuggestionTile(p)),

          if (_searchHistory.isNotEmpty) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'RÉCENTES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _searchHistory.clear()),
                    child: Text(
                      'Effacer',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ..._searchHistory.map(
              (h) => _buildHistoryTile(h),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(String label) {
    return InkWell(
      onTap: () => _search(label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.arrow_right_rounded,
                size: 16, color: AppTheme.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(String label) {
    return InkWell(
      onTap: () => _search(label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState(_error!);
    if (_result != null) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: _buildResultView(_result!),
      );
    }
    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_information_outlined,
              size: 56,
              color: AppTheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recherche clinique assistée par IA',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Entrez le nom d\'une pathologie pour générer un guide\nclinique complet enrichi par vos documents Drive.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: ['Pneumonie', 'HTA', 'Diabète', 'AVC', 'Asthme']
                .map((p) => ActionChip(
                      label: Text(p),
                      onPressed: () => _search(p),
                      avatar: Icon(Icons.flash_on_rounded,
                          size: 14, color: AppTheme.primary),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    startAngle: 0,
                    endAngle: 6.28,
                    transform: GradientRotation(
                        _shimmerController.value * 6.28),
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.1),
                      AppTheme.primary,
                      AppTheme.primaryLight,
                      AppTheme.primary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Analyse en cours...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recherche dans vos protocoles Drive, puis génération par IA',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 32),
          // Steps
          ...[
            (Icons.travel_explore_outlined, 'Interrogation Google Drive PDFs'),
            (Icons.psychology_outlined, 'Synthèse par modèle IA clinique'),
            (Icons.assignment_turned_in_outlined, 'Génération du guide structuré'),
          ].map(
            (step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(step.$1, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    step.$2,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              'Une erreur est survenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(Map<String, dynamic> data) {
    final definition = data['definition'] as String? ?? '';
    final symptomes = data['symptomes'] as String? ?? '';
    final diagnostic = data['diagnostic'] as String? ?? '';
    final traitements = data['traitements'] as String? ?? '';
    final matchedPathology = data['matched_pathology'] as String? ?? '';

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result header banner
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.08),
                  AppTheme.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                      children: [
                        const TextSpan(text: 'Résultats pour : '),
                        TextSpan(
                          text: matchedPathology,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Drive context badge
                if (_driveContextUsed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a73e8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            const Color(0xFF1a73e8).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_rounded,
                            size: 12, color: Color(0xFF1a73e8)),
                        SizedBox(width: 4),
                        Text(
                          'Drive PDFs utilisés',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1a73e8),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 6),
                // AI badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 12, color: Colors.purple.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Optimisé par IA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TabBar(
              isScrollable: false,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline, size: 16), text: 'Définition'),
                Tab(
                    icon: Icon(Icons.warning_amber_outlined, size: 16),
                    text: 'Symptômes'),
                Tab(
                    icon: Icon(Icons.checklist_outlined, size: 16),
                    text: 'Diagnostic'),
                Tab(
                    icon: Icon(Icons.health_and_safety_outlined, size: 16),
                    text: 'Traitements'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildTabContent(definition, 'Définition'),
                _buildTabContent(symptomes, 'Symptômes'),
                _buildTabContent(diagnostic, 'Diagnostic'),
                _buildTabContent(traitements, 'Traitements',
                    isTreatment: true),
              ],
            ),
          ),

          // ── Drive Sources Panel ─────────────────────────────────
          if (_driveSources.isNotEmpty)
            _buildSourcesPanel(),
        ],
      ),
    );
  }

  Widget _buildTabContent(String content, String title,
      {bool isTreatment = false}) {
    if (content.trim().isEmpty) {
      return Center(
        child: Text(
          'Aucune information disponible pour la section "$title".',
          style: TextStyle(
              color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: isTreatment
                        ? const Color(0xFF0F172A)
                        : AppTheme.textSecondary,
                    fontFamily: isTreatment ? 'monospace' : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Section "$title" copiée'),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copier'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesPanel() {
    // Group pages and track file IDs by filename
    final byFile = <String, _SourceFile>{};
    for (final s in _driveSources) {
      final name = s['source']?.toString() ?? 'Unknown';
      final page = (s['page'] as num?)?.toInt() ?? 0;
      final fileId = s['id']?.toString();
      byFile.putIfAbsent(name, () => _SourceFile()).pages.add(page);
      if (fileId != null && fileId.isNotEmpty) {
        byFile[name]!.fileId = fileId;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF1a73e8).withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.source_outlined,
              size: 18, color: Color(0xFF1a73e8)),
          title: Row(
            children: [
              const Text(
                'Sources consultées',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1a73e8),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a73e8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${byFile.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          children: byFile.entries.map((entry) {
            final fileName = entry.key;
            final info = entry.value;
            final pages = info.pages..sort();
            final pagesStr = pages.map((p) => 'p.$p').join(', ');
            final displayName = fileName.split(RegExp(r'[/\\]')).last;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: InkWell(
                onTap: info.fileId != null
                    ? () => _openPdfSource(info.fileId!)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(
                        info.fileId != null
                            ? Icons.open_in_new
                            : Icons.picture_as_pdf_outlined,
                        size: 15,
                        color: info.fileId != null
                            ? const Color(0xFF1a73e8)
                            : const Color(0xFFE53935),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: info.fileId != null
                                ? const Color(0xFF1a73e8)
                                : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w500,
                            decoration: info.fileId != null
                                ? TextDecoration.underline
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pagesStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openPdfSource(String fileId) async {
    final uri = Uri.parse('https://drive.google.com/file/d/$fileId/view');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _SourceFile {
  final List<int> pages = [];
  String? fileId;
}

