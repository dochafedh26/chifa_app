import 'dart:typed_data';
import 'package:chifa/app/printing/pvc_appointment_card_pdf.dart';
import 'package:chifa/app/cubits/settings_cubit.dart';
import 'package:chifa/services/db/models/models.dart';
import 'package:chifa/services/db/repositories/repositories.dart';
import 'package:chifa/services/pdf_generation_service.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Interactive dialog for configuring, previewing, and printing PVC Appointment Cards.
/// Features automated slot detection, doctor alerts for pre-printed cards, and selective printing.
class PvcAppointmentCardDialog extends StatefulWidget {
  final Patient patient;
  final Appointment appointment;
  final List<Appointment>? previousAppointments;

  const PvcAppointmentCardDialog({
    super.key,
    required this.patient,
    required this.appointment,
    this.previousAppointments,
  });

  /// Helper to show this dialog directly
  static Future<void> show({
    required BuildContext context,
    required Patient patient,
    required Appointment appointment,
    List<Appointment>? previousAppointments,
  }) {
    SettingsCubit? settingsCubit;
    try {
      settingsCubit = context.read<SettingsCubit>();
    } catch (_) {}

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final dialog = PvcAppointmentCardDialog(
          patient: patient,
          appointment: appointment,
          previousAppointments: previousAppointments,
        );
        if (settingsCubit != null) {
          return BlocProvider<SettingsCubit>.value(
            value: settingsCubit,
            child: dialog,
          );
        }
        return dialog;
      },
    );
  }

  @override
  State<PvcAppointmentCardDialog> createState() =>
      _PvcAppointmentCardDialogState();
}

class _PvcAppointmentCardDialogState extends State<PvcAppointmentCardDialog> {
  PvcCardSize _selectedCardSize = PvcCardSize.cr80;
  PvcPrintMode _selectedPrintMode = PvcPrintMode.both;
  int _targetSlotIndex = 1;
  bool _isLoadingPastAppointments = true;
  List<Appointment> _pastAppointments = [];
  bool _isPrePrintedCard = false;

  // Selected tab for preview: 0 = Verso (Appointments), 1 = Recto (Patient/QR)
  int _previewSide = 0;
  // Mobile responsive tab: 0 = Paramètres, 1 = Aperçu
  int _mobileViewTab = 0;

  @override
  void initState() {
    super.initState();
    _loadPastAppointments();
  }

  Future<void> _loadPastAppointments() async {
    if (widget.previousAppointments != null) {
      _processAppointments(widget.previousAppointments!);
      return;
    }

    try {
      final patientId = widget.patient.patientId;
      if (patientId != null) {
        final repo = AppointmentRepository();
        final res = await repo.getByPatientId(patientId);
        res.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _isLoadingPastAppointments = false;
                _targetSlotIndex = 1;
                _selectedPrintMode = PvcPrintMode.both;
              });
            }
          },
          (list) {
            _processAppointments(list);
          },
        );
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPastAppointments = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPastAppointments = false;
        });
      }
    }
  }

  void _processAppointments(List<Appointment> allAppointments) {
    // Filter past appointments (prior to or excluding current appointment)
    final past = allAppointments.where((a) {
      if (widget.appointment.appointmentId != null &&
          a.appointmentId == widget.appointment.appointmentId) {
        return false;
      }
      return a.appointmentDate.isBefore(widget.appointment.appointmentDate) ||
          a.status == AppointmentStatus.completed;
    }).toList();

    past.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

    final pastCount = past.length;
    // Automatic slot calculation: (pastCount % slotsCount) + 1
    final nextSlot = (pastCount % _selectedCardSize.slotsCount) + 1;
    final isPrePrinted = pastCount > 0;

    if (mounted) {
      setState(() {
        _pastAppointments = past;
        _isLoadingPastAppointments = false;
        _isPrePrintedCard = isPrePrinted;
        _targetSlotIndex = nextSlot;
        // If card already has data, default to backSlotOnly (selective) and preview Verso
        _selectedPrintMode =
            isPrePrinted ? PvcPrintMode.backSlotOnly : PvcPrintMode.both;
        _previewSide = isPrePrinted ? 0 : 1;
      });
    }
  }

  Future<Uint8List> _generatePdfBytes({bool forPrinting = false}) async {
    String clinicName = 'CLINIQUE MÉDICALE CHIFA';
    String clinicAddress = 'Cabinet Médical Chifa';
    String clinicPhone = '05 50 00 00 00';
    String doctorName = 'Dr. Médecin Traitant';

    try {
      final settings = context.read<SettingsCubit>().settings;
      if (settings.clinicName.trim().isNotEmpty) {
        clinicName = settings.clinicName.trim();
      }
      if (settings.clinicAddress.trim().isNotEmpty) {
        clinicAddress = settings.clinicAddress.trim();
      }
      if (settings.clinicPhone.trim().isNotEmpty) {
        clinicPhone = settings.clinicPhone.trim();
      }
      if (settings.doctorName.trim().isNotEmpty) {
        doctorName = settings.doctorName.trim();
      }
    } catch (_) {
      // Fallback defaults in case SettingsCubit is not available
    }

    PvcPrintMode modeToUse = _selectedPrintMode;
    if (!forPrinting) {
      if (_previewSide == 1) {
        modeToUse = PvcPrintMode.frontOnly;
      } else {
        modeToUse = _selectedPrintMode == PvcPrintMode.frontOnly
            ? PvcPrintMode.backFull
            : _selectedPrintMode;
      }
    }

    return PvcAppointmentCardPdf.generate(
      patient: widget.patient,
      currentAppointment: widget.appointment,
      previousAppointments: _pastAppointments,
      cardSize: _selectedCardSize,
      printMode: modeToUse,
      targetSlotIndex: _targetSlotIndex,
      clinicName: clinicName,
      clinicAddress: clinicAddress,
      clinicPhone: clinicPhone,
      doctorName: doctorName,
    );
  }

  Future<void> _handlePrint() async {
    try {
      final pdfBytes = await _generatePdfBytes(forPrinting: true);
      if (!mounted) return;

      await PdfGenerationService().printPdfBytes(
        pdfBytes,
        name:
            'carte_pvc_${widget.patient.lastName}_slot$_targetSlotIndex.pdf',
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'impression : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth > 1150 ? 1080.0 : screenWidth * 0.94;
    final dialogHeight = screenHeight > 780 ? 720.0 : screenHeight * 0.92;
    final sidebarWidth = dialogWidth < 900 ? 340.0 : 400.0;

    final isMobile = context.isMobile;

    final controlPanel = SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. ALERT BANNER IF CARD ALREADY PRINTED
          if (_isPrePrintedCard)
            _buildWarningAlertBanner()
          else
            _buildNewCardBanner(),

          const SizedBox(height: 18),

          // B. CARD FORMAT SELECTOR (CR-80 vs CR-100 vs A7)
          _buildFormatSelector(),

          const SizedBox(height: 18),

          // C. PRINT MODE SELECTOR
          _buildPrintModeSelector(),

          const SizedBox(height: 18),

          // D. TARGET SLOT PICKER (Line 1 to N)
          _buildSlotPicker(),

          const SizedBox(height: 18),

          // E. SUMMARY INFO CARD
          _buildAppointmentSummaryCard(),
        ],
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: isMobile ? 8 : 16,
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 1. DIALOG HEADER
            _buildDialogHeader(theme, isDark),

            // 2. MAIN CONTENT: Mobile Tabs or Desktop Row
            Expanded(
              child: _isLoadingPastAppointments
                  ? const Center(child: CircularProgressIndicator())
                  : isMobile
                      ? Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              child: SegmentedButton<int>(
                                segments: const [
                                  ButtonSegment<int>(
                                    value: 0,
                                    label: Text('1. Configuration'),
                                    icon: Icon(Icons.tune, size: 16),
                                  ),
                                  ButtonSegment<int>(
                                    value: 1,
                                    label: Text('2. Aperçu'),
                                    icon: Icon(Icons.visibility, size: 16),
                                  ),
                                ],
                                selected: {_mobileViewTab},
                                onSelectionChanged: (set) {
                                  setState(() => _mobileViewTab = set.first);
                                },
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _mobileViewTab == 0
                                  ? controlPanel
                                  : _buildPreviewArea(isDark),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Control Panel
                            Container(
                              width: sidebarWidth,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                border: Border(
                                  right: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              child: controlPanel,
                            ),

                            // Live Card Preview Area
                            Expanded(
                              child: _buildPreviewArea(isDark),
                            ),
                          ],
                        ),
            ),

            // 3. DIALOG FOOTER ACTIONS
            _buildDialogFooter(theme, isDark),
          ],
        ),
      ),
    );
  }

  /// Header with Title, Patient Badge & Close button
  Widget _buildDialogHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F5B9E),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Impression Carte PVC de Rendez-vous (ID-Card)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Patient: ${widget.patient.fullName} (ID: #${widget.patient.patientId ?? 0})',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  /// High-visibility Doctor Warning Alert when printing on a pre-existing PVC card
  Widget _buildWarningAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFB45309), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ATTENTION : CARTE DÉJÀ IMPRIMÉE DÉTECTÉE',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF78350F),
                fontSize: 12,
                height: 1.4,
              ),
              children: [
                const TextSpan(
                  text:
                      'Le recto et les rendez-vous antérieurs sont déjà imprimés sur cette carte.\n',
                ),
                const TextSpan(
                  text: '👉 Action requise : ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text:
                      'Insérez la carte côté ',
                ),
                TextSpan(
                  text: 'VERSO (face arrière)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
                const TextSpan(
                  text: ' dans l\'imprimante.\n',
                ),
                const TextSpan(
                  text: '🎯 Positionnement automatique : ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: 'Ligne N° $_targetSlotIndex',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F5B9E),
                  ),
                ),
                const TextSpan(
                  text:
                      ' (seule cette ligne recevra l\'encre, les rendez-vous précédents sont préservés).',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Friendly banner for fresh blank cards
  Widget _buildNewCardBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
      ),
      child: Row(
        children: const [
          Icon(Icons.check_circle_outline, color: Color(0xFF15803D), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Première impression : Carte vierge détectée. Le recto (Patient + QR) et la ligne 1 du verso seront imprimés.',
              style: TextStyle(
                color: Color(0xFF15803D),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PVC Card Size Selector
  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Format de Carte PVC :',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PvcCardSize>(
          value: _selectedCardSize,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: PvcCardSize.values.map((size) {
            return DropdownMenuItem<PvcCardSize>(
              value: size,
              child: Text(
                size.name,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (newSize) {
            if (newSize != null) {
              setState(() {
                _selectedCardSize = newSize;
                if (_targetSlotIndex > newSize.slotsCount) {
                  _targetSlotIndex = newSize.slotsCount;
                }
              });
            }
          },
        ),
      ],
    );
  }

  /// Print Mode Selector
  Widget _buildPrintModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mode d\'Impression :',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        // Mode: Selective Slot (Recommended)
        _buildModeRadio(
          title: 'Ligne Sélective Seule (Recommandé)',
          subtitle:
              'Imprime UNIQUEMENT sur la ligne ciblée. Ne touche pas aux lignes existantes.',
          mode: PvcPrintMode.backSlotOnly,
          icon: Icons.my_location_rounded,
          badgeColor: Colors.amber,
        ),
        const SizedBox(height: 6),
        // Mode: Both Sides
        _buildModeRadio(
          title: 'Carte Complète (Recto + Verso)',
          subtitle: 'Idéal pour une carte plastique neuve et vierge.',
          mode: PvcPrintMode.both,
          icon: Icons.flip_rounded,
        ),
        const SizedBox(height: 6),
        // Mode: Front Only
        _buildModeRadio(
          title: 'Recto Seul (Infos Patient + QR)',
          subtitle: 'Pour remplacer ou préparer la face avant.',
          mode: PvcPrintMode.frontOnly,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 6),
        // Mode: Full Back
        _buildModeRadio(
          title: 'Verso Complet (Quadrillage + Lignes)',
          subtitle: 'Réimprime toutes les lignes jusqu\'à la cible.',
          mode: PvcPrintMode.backFull,
          icon: Icons.table_rows_rounded,
        ),
      ],
    );
  }

  Widget _buildModeRadio({
    required String title,
    required String subtitle,
    required PvcPrintMode mode,
    required IconData icon,
    Color? badgeColor,
  }) {
    final isSelected = _selectedPrintMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPrintMode = mode;
          if (mode == PvcPrintMode.frontOnly) {
            _previewSide = 1;
          } else {
            _previewSide = 0;
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F5B9E).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F5B9E)
                : Colors.grey.withOpacity(0.25),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF0F5B9E) : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12.5,
                      color: isSelected ? const Color(0xFF0F5B9E) : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio<PvcPrintMode>(
              value: mode,
              groupValue: _selectedPrintMode,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPrintMode = val;
                    if (val == PvcPrintMode.frontOnly) {
                      _previewSide = 1;
                    } else {
                      _previewSide = 0;
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Slot Picker (Ligne 1 to N)
  Widget _buildSlotPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Emplacement (Ligne) :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            Text(
              'Cible : Ligne $_targetSlotIndex',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: Color(0xFF0F5B9E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: List.generate(_selectedCardSize.slotsCount, (index) {
            final slotNum = index + 1;
            final isTarget = slotNum == _targetSlotIndex;
            final isPast = slotNum < _targetSlotIndex && _isPrePrintedCard;

            Color bgColor;
            Color textColor;
            Border? border;

            if (isTarget) {
              bgColor = const Color(0xFF0F5B9E);
              textColor = Colors.white;
            } else if (isPast) {
              bgColor = const Color(0xFFE2E8F0);
              textColor = const Color(0xFF64748B);
            } else {
              bgColor = Colors.white;
              textColor = const Color(0xFF1E293B);
              border = Border.all(color: const Color(0xFFCBD5E1));
            }

            return InkWell(
              onTap: () {
                setState(() {
                  _targetSlotIndex = slotNum;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: border,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPast)
                      const Icon(Icons.check, size: 13, color: Color(0xFF64748B))
                    else if (isTarget)
                      const Icon(Icons.radio_button_checked,
                          size: 13, color: Colors.white)
                    else
                      const Icon(Icons.radio_button_unchecked,
                          size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Ligne $slotNum',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isTarget ? FontWeight.bold : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Appointment Details Card
  Widget _buildAppointmentSummaryCard() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final dateStr =
        dateFormat.format(widget.appointment.appointmentDate);
    final timeStr =
        timeFormat.format(widget.appointment.appointmentDate);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails du Rendez-vous à imprimer :',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Color(0xFF0F5B9E)),
              const SizedBox(width: 6),
              Text(
                '$dateStr à $timeStr',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.medical_services_outlined,
                  size: 16, color: Color(0xFF0F5B9E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.appointment.notes?.isNotEmpty == true
                      ? widget.appointment.notes!
                      : 'Consultation de suivi',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Live PDF Preview area with Front/Back switcher
  Widget _buildPreviewArea(bool isDark) {
    return Column(
      children: [
        // Tab switcher: Verso (Back) vs Recto (Front)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Aperçu Carte PVC :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SegmentedButton<int>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Verso'),
                    icon: Icon(Icons.table_chart_outlined, size: 15),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Recto'),
                    icon: Icon(Icons.badge_outlined, size: 15),
                  ),
                ],
                selected: {_previewSide},
                onSelectionChanged: (set) {
                  setState(() {
                    _previewSide = set.first;
                  });
                },
              ),
            ],
          ),
        ),

        // PdfPreview viewer
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF090D16) : const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(16),
            child: PdfPreview(
              key: ValueKey(
                'pvc_preview_${_selectedCardSize.name}_${_selectedPrintMode.name}_${_targetSlotIndex}_$_previewSide',
              ),
              build: (format) => _generatePdfBytes(forPrinting: false),
              pageFormats: <String, PdfPageFormat>{
                _selectedCardSize.name: _selectedCardSize.pageFormat,
              },
              initialPageFormat: _selectedCardSize.pageFormat,
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              useActions: false,
              maxPageWidth: 460,
              onError: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Aperçu indisponible',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              pdfPreviewPageDecoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Dialog Footer with Print & Cancel buttons
  Widget _buildDialogFooter(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_selectedPrintMode == PvcPrintMode.backSlotOnly) ...[
            const Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Verso : Impression ciblée sur la Ligne sélectionnée.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            const Spacer(),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F5B9E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(
              _selectedPrintMode == PvcPrintMode.backSlotOnly
                  ? 'Imprimer sur Verso (Ligne $_targetSlotIndex)'
                  : 'Imprimer Carte PVC',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _handlePrint,
          ),
        ],
      ),
    );
  }
}
