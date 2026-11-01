import 'dart:async';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/models/models.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WaitingRoomItem {
  final Appointment appointment;
  final Patient patient;
  final int ticketNumber;

  WaitingRoomItem({
    required this.appointment,
    required this.patient,
    required this.ticketNumber,
  });

  /// Nom anonymisé pour le respect du secret médical & RGPD
  /// Ex: "M. KADER B." ou "Mme FATIMA Z."
  String get maskedName {
    final title = patient.gender == Gender.male ? 'M.' : 'Mme';
    final initial = patient.lastName.trim().isNotEmpty
        ? '${patient.lastName.trim()[0].toUpperCase()}.'
        : '';
    final firstName = patient.firstName.trim().toUpperCase();
    return '$title $firstName $initial'.trim();
  }
}

class WaitingRoomTvScreen extends StatefulWidget {
  const WaitingRoomTvScreen({super.key});

  @override
  State<WaitingRoomTvScreen> createState() => _WaitingRoomTvScreenState();
}

class _WaitingRoomTvScreenState extends State<WaitingRoomTvScreen>
    with SingleTickerProviderStateMixin {
  Timer? _clockTimer;
  Timer? _refreshTimer;
  DateTime _currentTime = DateTime.now();

  List<WaitingRoomItem> _waitingPatients = [];
  WaitingRoomItem? _currentlyCalledPatient;
  String _currentCabinet = 'Cabinet N° 1';
  bool _isLoading = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _healthTips = [
    'Bienvenue à la Clinique Chifa • Nous prenons soin de votre santé.',
    'Merci de préparer votre pièce d\'identité et vos examens récents.',
    'En cas d\'urgence médicale signalée, veuillez avertir l\'accueil immédiatement.',
    'Veuillez respecter le calme et couper la sonnerie de votre téléphone.',
    'Le port du masque reste recommandé en cas de symptômes grippaux.',
    'Portail patient disponible en scannant le QR code sur votre carte Chifa.',
  ];
  int _tipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();

    // Pulse animation for called patient
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Live Clock timer
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    // Health tips rotation timer
    _tipTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {
          _tipIndex = (_tipIndex + 1) % _healthTips.length;
        });
      }
    });

    // Initial load & periodic auto-refresh (every 4 seconds)
    _loadWaitingQueue();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadWaitingQueue(silent: true);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    _tipTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadWaitingQueue({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final db = DatabaseManager.instance;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch appointments for today that are waiting or in consultation
      final rows = await db.query(
        '''SELECT a.*, p.first_name, p.last_name, p.gender, p.date_of_birth, p.phone, p.national_id, p.created_at
           FROM appointments a
           JOIN patients p ON a.patient_id = p.patient_id
           WHERE a.is_deleted = 0 
             AND (DATE(a.appointment_date) = DATE(?) OR a.appointment_date LIKE ?)
             AND (
               LOWER(a.status) = 'waitingroom' 
               OR a.status = 'waitingRoom' 
               OR a.status = 'WaitingRoom'
               OR a.status LIKE '%waiting%'
               OR LOWER(a.status) = 'inconsultation'
               OR a.status = 'inConsultation'
             )
           ORDER BY 
             CASE 
               WHEN LOWER(a.status) = 'inconsultation' OR a.status = 'inConsultation' THEN 1 
               ELSE 2 
             END,
             a.appointment_date ASC''',
        [todayStr, '$todayStr%'],
      );

      final List<WaitingRoomItem> items = [];
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        try {
          final appointment = Appointment.fromMap(row);
          final patient = Patient.fromMap(row);
          items.add(
            WaitingRoomItem(
              appointment: appointment,
              patient: patient,
              ticketNumber: i + 1,
            ),
          );
        } catch (e) {
          debugPrint('[TV Screen Row Parse Warning] $e');
        }
      }

      if (mounted) {
        setState(() {
          _waitingPatients = items;
          _isLoading = false;

          // If no one is called yet, or the currently called patient is no longer in the list, keep or set first
          if (_currentlyCalledPatient != null) {
            final exists = items.any(
              (item) =>
                  item.appointment.appointmentId ==
                  _currentlyCalledPatient!.appointment.appointmentId,
            );
            if (!exists && items.isNotEmpty) {
              _currentlyCalledPatient = items.first;
            } else if (!exists) {
              _currentlyCalledPatient = null;
            }
          } else if (items.isNotEmpty && _currentlyCalledPatient == null) {
            _currentlyCalledPatient = items.first;
          }
        });
      }
    } catch (e, stack) {
      debugPrint('[TV Screen Error] $e\n$stack');
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _callPatient(WaitingRoomItem item, {String? cabinet}) {
    setState(() {
      _currentlyCalledPatient = item;
      if (cabinet != null) _currentCabinet = cabinet;
    });

    _pulseController.reset();
    _pulseController.repeat(reverse: true);
  }

  void _showCabinetSelector() {
    showDialog(
      context: context,
      builder: (ctx) {
        final cabinets = [
          'Cabinet N° 1 (Dr. BENALI)',
          'Cabinet N° 2 (Consultations)',
          'Cabinet N° 3 (Soins & Triage)',
          'Cabinet Dentaire',
          'Salle d\'Analyses',
        ];
        return SimpleDialog(
          title: const Text('Sélectionner le Cabinet / Médecin'),
          children: cabinets.map((cab) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() => _currentCabinet = cab);
                Navigator.pop(ctx);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.meeting_room, color: Color(0xFF0F5B9E)),
                    const SizedBox(width: 12),
                    Text(cab, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm:ss');

    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128), // Deep clinic modern navy
      body: SafeArea(
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────────
            // 1. TOP BAR : HEADER CLINIQUE + HORLOGE GÉANTE LIVE
            // ─────────────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 32,
                vertical: isMobile ? 10 : 18,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF101F42),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E3A78), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  // Logo & Titre Clinique
                  Container(
                    width: isMobile ? 36 : 50,
                    height: isMobile ? 36 : 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F5B9E),
                      borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F5B9E).withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.local_hospital,
                      color: Colors.white,
                      size: isMobile ? 20 : 30,
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLINIQUE CHIFA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 16 : 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: isMobile ? 1 : 1.8,
                          ),
                        ),
                        Text(
                          isMobile
                              ? _currentCabinet.toUpperCase()
                              : 'ESPACE D\'ACCUEIL & SALLE D\'ATTENTE • ${_currentCabinet.toUpperCase()}',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8), // Cyan accent
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Actions pour le personnel
                  IconButton(
                    icon: Icon(Icons.room_preferences, color: Colors.white70, size: isMobile ? 20 : 24),
                    tooltip: 'Changer de Cabinet',
                    onPressed: _showCabinetSelector,
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white70, size: isMobile ? 20 : 24),
                    tooltip: 'Rafraîchir maintenant',
                    onPressed: () => _loadWaitingQueue(),
                  ),
                  IconButton(
                    icon: Icon(Icons.fullscreen_exit, color: Colors.white70, size: isMobile ? 20 : 24),
                    tooltip: 'Quitter le mode TV',
                    onPressed: () => Navigator.pop(context),
                  ),

                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    // Date & Heure Grand Format (Desktop / TV)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1128),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E3A78)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Color(0xFF38BDF8), size: 28),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeFormat.format(_currentTime),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                dateFormat.format(_currentTime).toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────────────
            // 2. MAIN VIEW : ADAPTATIVE (COLONNE EN PORTRAIT, 2 COLONNES EN PAYSAGE)
            // ─────────────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12.0 : 28.0),
                child: isPortrait
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildCurrentlyCalledSection(isMobile: isMobile),
                            const SizedBox(height: 16),
                            _buildWaitingQueueSection(isMobile: isMobile, shrinkWrap: true),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Colonne Gauche : Grand Panneau d'Appel Patient (60%)
                          Expanded(
                            flex: 6,
                            child: _buildCurrentlyCalledSection(isMobile: isMobile),
                          ),
                          SizedBox(width: isMobile ? 14 : 28),

                          // Colonne Droite : File d'Attente Ordonnée (40%)
                          Expanded(
                            flex: 4,
                            child: _buildWaitingQueueSection(isMobile: isMobile),
                          ),
                        ],
                      ),
              ),
            ),

            // ─────────────────────────────────────────────────────────────
            // 3. BOTTOM BANNER : TICKER DÉFILANT D'INFORMATIONS SANTÉ
            // ─────────────────────────────────────────────────────────────
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(
                  top: BorderSide(color: Color(0xFF1E3A78), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'INFO PATIENTS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        _healthTips[_tipIndex],
                        key: ValueKey<int>(_tipIndex),
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'medevsync.com/chifa',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET : GRAND PANNEAU D'APPEL DU PATIENT (GAUCHE)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCurrentlyCalledSection({bool isMobile = false}) {
    if (_currentlyCalledPatient == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101F42),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1E3A78), width: 1.5),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: isMobile ? 48 : 80,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                SizedBox(height: isMobile ? 12 : 20),
                Text(
                  'AUCUN PATIENT EN SALLE D\'ATTENTE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMobile ? 14 : 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isMobile ? 6 : 10),
                Text(
                  'Les patients enregistrés à l\'accueil apparaîtront ici automatiquement.',
                  style: TextStyle(color: Colors.white38, fontSize: isMobile ? 12 : 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final item = _currentlyCalledPatient!;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F3B66), Color(0xFF091C36)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
              blurRadius: 36,
              spreadRadius: 6,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: isMobile ? 16 : 32,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge Supérieur Clignotant
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 24,
                  vertical: isMobile ? 6 : 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E), // Vert lumineux d'appel
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up, color: Colors.white, size: isMobile ? 18 : 24),
                    SizedBox(width: isMobile ? 6 : 10),
                    Text(
                      'PATIENT APPELÉ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 14 : 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 16 : 36),

              // Numéro de Ticket Géant
              Text(
                'TICKET N° ${item.ticketNumber.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: const Color(0xFF38BDF8),
                  fontSize: isMobile ? 20 : 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: isMobile ? 8 : 12),

              // Nom Anonymisé du Patient
              Text(
                item.maskedName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 28 : 54,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isMobile ? 16 : 32),

              // Destination : Cabinet / Médecin
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: isMobile ? 10 : 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF101F42),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward_rounded,
                        color: const Color(0xFF38BDF8), size: isMobile ? 24 : 36),
                    SizedBox(width: isMobile ? 10 : 16),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VEUILLEZ VOUS PRÉSENTER AU :',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: isMobile ? 10 : 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            _currentCabinet.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 16 : 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET : LISTE D'ATTENTE DES PROCHAINS PATIENTS (DROITE)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWaitingQueueSection({bool isMobile = false, bool shrinkWrap = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101F42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E3A78), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de la liste
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF162955),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered,
                    color: Color(0xFF38BDF8), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PROCHAINS PATIENTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F5B9E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_waitingPatients.length} en attente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des patients
          if (shrinkWrap)
            // Mode portrait (dans SingleChildScrollView) : pas d'Expanded
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    ),
                  )
                : _waitingPatients.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Aucun patient en file d\'attente',
                            style: TextStyle(color: Colors.white38, fontSize: 16),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _waitingPatients.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _waitingPatients[index];
                          final isCurrent = _currentlyCalledPatient?.appointment
                                  .appointmentId ==
                              item.appointment.appointmentId;
                          return _buildPatientTile(item, isCurrent);
                        },
                      )
          else
            // Mode paysage / desktop : Expanded normal avec ListView scrollable
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    )
                  : _waitingPatients.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun patient en file d\'attente',
                            style: TextStyle(color: Colors.white38, fontSize: 16),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _waitingPatients.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _waitingPatients[index];
                            final isCurrent = _currentlyCalledPatient?.appointment
                                    .appointmentId ==
                                item.appointment.appointmentId;
                            return _buildPatientTile(item, isCurrent);
                          },
                        ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientTile(dynamic item, bool isCurrent) {
    return InkWell(
      onTap: () => _callPatient(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF0F3B66)
              : const Color(0xFF0B1733),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF38BDF8)
                : const Color(0xFF1E3A78),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Numéro de Ticket
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF162955),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#${item.ticketNumber}',
                  style: TextStyle(
                    color: isCurrent
                        ? const Color(0xFF0A1128)
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Nom masqué
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.maskedName,
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.white
                          : const Color(0xFFE2E8F0),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Arrivé à ${DateFormat("HH:mm").format(item.appointment.appointmentDate)}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // État / Action d'appel
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'EN COURS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              const Icon(
                Icons.touch_app_outlined,
                color: Colors.white30,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
