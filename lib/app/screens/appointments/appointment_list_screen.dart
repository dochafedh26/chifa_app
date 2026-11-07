import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chifa/app/cubits/appointment_cubit.dart';
import 'package:chifa/app/printing/appointment_pdf.dart';
import 'package:chifa/app/printing/preview.dart';
import 'package:chifa/app/screens/appointments/appointment_form_dialog.dart';
import 'package:chifa/app/screens/appointments/pvc_appointment_card_dialog.dart';
import 'package:chifa/app/screens/appointments/waiting_room_tv_screen.dart';
import 'package:chifa/app/screens/billing/invoice_print_dialog.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/models/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_code_vision/qr_code_vision.dart' as qrcv;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  DateTime _selectedDate = DateTime.now();
  AppointmentDateFilterMode _dateFilterMode = AppointmentDateFilterMode.day;
  AppointmentStatus? _statusFilter; // null = All
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cache patient names to avoid repeated DB calls
  final Map<int, String> _patientNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadAppointments() {
    final cubit = context.read<AppointmentCubit>();
    switch (_dateFilterMode) {
      case AppointmentDateFilterMode.day:
        cubit.loadAppointmentsByDate(_selectedDate);
        break;
      case AppointmentDateFilterMode.month:
        cubit.loadAppointmentsByMonth(_selectedDate);
        break;
      case AppointmentDateFilterMode.year:
        cubit.loadAppointmentsByYear(_selectedDate.year);
        break;
      case AppointmentDateFilterMode.allTime:
        cubit.loadAllAppointments();
        break;
    }
  }

  void _previousPeriod() {
    setState(() {
      switch (_dateFilterMode) {
        case AppointmentDateFilterMode.day:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case AppointmentDateFilterMode.month:
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
          break;
        case AppointmentDateFilterMode.year:
          _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
          break;
        case AppointmentDateFilterMode.allTime:
          break;
      }
    });
    _loadAppointments();
  }

  void _nextPeriod() {
    setState(() {
      switch (_dateFilterMode) {
        case AppointmentDateFilterMode.day:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case AppointmentDateFilterMode.month:
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
          break;
        case AppointmentDateFilterMode.year:
          _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
          break;
        case AppointmentDateFilterMode.allTime:
          break;
      }
    });
    _loadAppointments();
  }

  void _goToCurrentPeriod() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadAppointments();
  }

  Future<void> _pickPeriod() async {
    if (_dateFilterMode == AppointmentDateFilterMode.allTime) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: _dateFilterMode == AppointmentDateFilterMode.year
          ? DatePickerMode.year
          : DatePickerMode.day,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadAppointments();
    }
  }

  String _getPeriodTitle() {
    switch (_dateFilterMode) {
      case AppointmentDateFilterMode.day:
        return DateFormat('EEEE').format(_selectedDate);
      case AppointmentDateFilterMode.month:
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case AppointmentDateFilterMode.year:
        return 'Year ${_selectedDate.year}';
      case AppointmentDateFilterMode.allTime:
        return 'All Time History';
    }
  }

  String _getPeriodSubtitle() {
    switch (_dateFilterMode) {
      case AppointmentDateFilterMode.day:
        return DateFormat('dd MMMM yyyy').format(_selectedDate);
      case AppointmentDateFilterMode.month:
        return 'All appointments for this month';
      case AppointmentDateFilterMode.year:
        return 'All appointments for this year';
      case AppointmentDateFilterMode.allTime:
        return 'All registered appointments';
    }
  }

  String _getCurrentPeriodButtonLabel() {
    switch (_dateFilterMode) {
      case AppointmentDateFilterMode.day:
        return 'Today';
      case AppointmentDateFilterMode.month:
        return 'This Month';
      case AppointmentDateFilterMode.year:
        return 'This Year';
      case AppointmentDateFilterMode.allTime:
        return 'Current';
    }
  }

  String _formatAppointmentDateTime(DateTime date) {
    switch (_dateFilterMode) {
      case AppointmentDateFilterMode.day:
        return DateFormat('HH:mm').format(date);
      case AppointmentDateFilterMode.month:
        return '${DateFormat('dd MMMM').format(date)} (${DateFormat('EEE').format(date)}) at ${DateFormat('HH:mm').format(date)}';
      case AppointmentDateFilterMode.year:
      case AppointmentDateFilterMode.allTime:
        return '${DateFormat('dd/MM/yyyy').format(date)} at ${DateFormat('HH:mm').format(date)}';
    }
  }

  Future<String> _getPatientName(int patientId) async {
    if (_patientNameCache.containsKey(patientId)) {
      return _patientNameCache[patientId]!;
    }
    try {
      final db = DatabaseManager.instance;
      final results = await db.query(
        'SELECT first_name, last_name FROM patients WHERE patient_id = ?',
        [patientId],
      );
      if (results.isNotEmpty) {
        final name =
            '${results.first['first_name']} ${results.first['last_name']}';
        _patientNameCache[patientId] = name;
        return name;
      }
    } catch (_) {}
    return 'Patient #$patientId';
  }

  List<Appointment> _applyFilters(List<Appointment> appointments) {
    var filtered = appointments;

    // Status filter
    if (_statusFilter != null) {
      filtered = filtered.where((a) => a.status == _statusFilter).toList();
    }

    // Search filter (by patient name from cache)
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) {
        final name = _patientNameCache[a.patientId]?.toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AppointmentFormDialog(
        selectedDate: _selectedDate,
        onSave: (appointment) {
          context.read<AppointmentCubit>().createAppointment(appointment);
        },
      ),
    );
  }

  Widget _buildPeriodSelector({bool isCompact = false}) {
    return SegmentedButton<AppointmentDateFilterMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity:
            isCompact ? VisualDensity.compact : VisualDensity.standard,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: Theme.of(context).colorScheme.primary,
      ),
      segments: const [
        ButtonSegment(
          value: AppointmentDateFilterMode.day,
          label: Text('Day'),
          icon: Icon(Icons.today_outlined, size: 16),
        ),
        ButtonSegment(
          value: AppointmentDateFilterMode.month,
          label: Text('Month'),
          icon: Icon(Icons.calendar_view_month_outlined, size: 16),
        ),
        ButtonSegment(
          value: AppointmentDateFilterMode.year,
          label: Text('Annual'),
          icon: Icon(Icons.calendar_today_outlined, size: 16),
        ),
        ButtonSegment(
          value: AppointmentDateFilterMode.allTime,
          label: Text('All Time'),
          icon: Icon(Icons.all_inclusive, size: 16),
        ),
      ],
      selected: {_dateFilterMode},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) {
          setState(() => _dateFilterMode = set.first);
          _loadAppointments();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return BlocBuilder<AppointmentCubit, AppointmentState>(
      builder: (context, state) {
        return Column(
          children: [
            // Calendar Header
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: isMobile
                    ? Column(
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildPeriodSelector(isCompact: true),
                          ),
                          const SizedBox(height: 12),
                          if (_dateFilterMode !=
                              AppointmentDateFilterMode.allTime)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: _previousPeriod,
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickPeriod,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Column(
                                      children: [
                                        Text(
                                          _getPeriodTitle(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          _getPeriodSubtitle(),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _nextPeriod,
                                ),
                              ],
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    _getPeriodTitle(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _getPeriodSubtitle(),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (_dateFilterMode !=
                                  AppointmentDateFilterMode.allTime) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _goToCurrentPeriod,
                                    child: Text(_getCurrentPeriodButtonLabel()),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton.filledTonal(
                                icon: const Icon(Icons.tv),
                                tooltip: 'Écran TV Salle d\'attente',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const WaitingRoomTvScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.qr_code_scanner),
                                tooltip: 'Scan Arrivée / Check-in',
                                onPressed: () => _showQuickCheckInDialog(context),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddDialog(context),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('New Appt'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 1120;
                          final isPortraitTablet = constraints.maxWidth < 740;

                          if (isPortraitTablet) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: _buildPeriodSelector(
                                          isCompact: true,
                                        ),
                                      ),
                                    ),
                                    if (_dateFilterMode !=
                                        AppointmentDateFilterMode.allTime) ...[
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: _goToCurrentPeriod,
                                        child: Text(
                                          _getCurrentPeriodButtonLabel(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (_dateFilterMode !=
                                        AppointmentDateFilterMode.allTime) ...[
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        tooltip: 'Précédent',
                                        onPressed: _previousPeriod,
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: _pickPeriod,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _getPeriodTitle(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  _getPeriodSubtitle(),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        tooltip: 'Suivant',
                                        onPressed: _nextPeriod,
                                      ),
                                    ] else
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _getPeriodTitle(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              _getPeriodSubtitle(),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.tv, size: 18),
                                      tooltip: 'Écran TV Salle d\'attente',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const WaitingRoomTvScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton.filledTonal(
                                      icon: const Icon(
                                        Icons.qr_code_scanner,
                                        size: 18,
                                      ),
                                      tooltip: 'Scan Check-in',
                                      onPressed: () =>
                                          _showQuickCheckInDialog(context),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddDialog(context),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Appointment'),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Ligne 1 : Sélecteur de période + Navigation Date
                                Row(
                                  children: [
                                    _buildPeriodSelector(isCompact: true),
                                    const SizedBox(width: 12),
                                    if (_dateFilterMode !=
                                        AppointmentDateFilterMode.allTime) ...[
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        tooltip: 'Précédent',
                                        onPressed: _previousPeriod,
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: _pickPeriod,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _getPeriodTitle(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  _getPeriodSubtitle(),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        tooltip: 'Suivant',
                                        onPressed: _nextPeriod,
                                      ),
                                      TextButton(
                                        onPressed: _goToCurrentPeriod,
                                        child: Text(_getCurrentPeriodButtonLabel()),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Ligne 2 : Boutons d'Action (TV, Check-in, Nouveau RDV)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const WaitingRoomTvScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.tv, size: 18),
                                      label: const Text('Écran TV'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0F172A),
                                        side: const BorderSide(
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showQuickCheckInDialog(context),
                                      icon: const Icon(Icons.qr_code_scanner,
                                          size: 18),
                                      label: const Text('Scan Check-in'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0F5B9E),
                                        side: const BorderSide(
                                          color: Color(0xFF0F5B9E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddDialog(context),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Appointment'),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          // Large Desktop : Ligne unique aérée avec date visible sans compression
                          return Row(
                            children: [
                              _buildPeriodSelector(isCompact: false),
                              const SizedBox(width: 14),
                              if (_dateFilterMode !=
                                  AppointmentDateFilterMode.allTime) ...[
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  tooltip: 'Précédent',
                                  onPressed: _previousPeriod,
                                ),
                                InkWell(
                                  onTap: _pickPeriod,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _getPeriodTitle(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                        ),
                                        Text(
                                          _getPeriodSubtitle(),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  tooltip: 'Suivant',
                                  onPressed: _nextPeriod,
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: _goToCurrentPeriod,
                                  child: Text(_getCurrentPeriodButtonLabel()),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getPeriodTitle(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        _getPeriodSubtitle(),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const WaitingRoomTvScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.tv, size: 18),
                                label: const Text('Écran TV'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showQuickCheckInDialog(context),
                                icon: const Icon(Icons.qr_code_scanner, size: 18),
                                label: const Text('Scan Check-in'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F5B9E),
                                  side: const BorderSide(
                                    color: Color(0xFF0F5B9E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showAddDialog(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Appointment'),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),

            // Filters Row
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompactFilter =
                        isMobile || constraints.maxWidth < 880;
                    if (isCompactFilter) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.filter_list,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip('Tous', null),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Programmés',
                                  AppointmentStatus.scheduled,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'En salle d\'attente',
                                  AppointmentStatus.waitingRoom,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Terminés',
                                  AppointmentStatus.completed,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Annulés',
                                  AppointmentStatus.cancelled,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by patient name...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        // Status Filter Chips
                        const Icon(
                          Icons.filter_list,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip('Tous', null),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'Programmés',
                          AppointmentStatus.scheduled,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'En salle d\'attente',
                          AppointmentStatus.waitingRoom,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'Terminés',
                          AppointmentStatus.completed,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'Annulés',
                          AppointmentStatus.cancelled,
                        ),

                        const SizedBox(width: 16),
                        // Search Field
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by patient name...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  size: 18,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Appointments List
            Expanded(child: _buildAppointmentsContent(state)),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, AppointmentStatus? status) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = status),
      selectedColor: _getStatusChipColor(status),
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? _getStatusChipColor(status)
              : Colors.grey.shade300,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getStatusChipColor(AppointmentStatus? status) {
    if (status == null) return Theme.of(context).colorScheme.primary;
    return _getStatusColor(status);
  }

  Widget _buildAppointmentsContent(AppointmentState state) {
    if (state is AppointmentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is AppointmentError) {
      return Center(child: Text('Error: ${state.message}'));
    }

    if (state is AppointmentsLoaded) {
      final filtered = _applyFilters(state.appointments);

      if (state.appointments.isEmpty) {
        final emptyText = switch (_dateFilterMode) {
          AppointmentDateFilterMode.day => 'No appointments for this day',
          AppointmentDateFilterMode.month => 'No appointments for this month',
          AppointmentDateFilterMode.year => 'No appointments for this year',
          AppointmentDateFilterMode.allTime =>
            'No appointments found in database',
        };
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                emptyText,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            ],
          ),
        );
      }

      if (filtered.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_list_off,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No appointments match your filters',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _statusFilter = null;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: const Text('Clear filters'),
              ),
            ],
          ),
        );
      }

      // Count per status for info
      final totalCount = state.appointments.length;
      final filteredCount = filtered.length;

      return Column(
        children: [
          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Text(
                  _statusFilter != null || _searchQuery.isNotEmpty
                      ? '$filteredCount of $totalCount appointments'
                      : '$totalCount appointment${totalCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final appointment = filtered[index];
                return _buildAppointmentCard(appointment);
              },
            ),
          ),
        ],
      );
    }

    return const Center(child: Text('Select a date to view appointments'));
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getStatusColor(appointment.status).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.access_time,
            color: _getStatusColor(appointment.status),
            size: 22,
          ),
        ),
        title: FutureBuilder<String>(
          future: _getPatientName(appointment.patientId),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? 'Loading...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatAppointmentDateTime(appointment.appointmentDate)} - ${appointment.notes ?? "No notes"}',
            ),
            FutureBuilder<Payment?>(
              future: _getLatestPatientPayment(
                appointment.patientId,
                appointment.appointmentDate,
              ),
              builder: (context, snapshot) {
                final payment = snapshot.data;
                if (payment == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => _openPatientPayment(appointment),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.point_of_sale,
                            size: 14,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Total validé : ${payment.amount.toStringAsFixed(2)} DA',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.print, size: 12, color: Colors.teal),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        trailing: Builder(
          builder: (context) {
            final isMobile = context.isMobile;
            final statusWidget = PopupMenuButton<AppointmentStatus>(
              tooltip: 'Modifier le statut',
              onSelected: (status) {
                context.read<AppointmentCubit>().updateAppointmentStatus(
                  appointment.appointmentId!,
                  status,
                );
              },
              itemBuilder: (context) => AppointmentStatus.values.map((s) {
                return PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getStatusColor(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(s.label),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getStatusColor(appointment.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appointment.status == AppointmentStatus.waitingRoom) ...[
                      const Icon(Icons.meeting_room, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      appointment.status.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (isMobile) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  statusWidget,
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Actions',
                    onSelected: (val) {
                      switch (val) {
                        case 'whatsapp':
                          _sendWhatsAppReminder(appointment);
                          break;
                        case 'pvc':
                          _printPvcCard(appointment);
                          break;
                        case 'print_a5':
                          _printAppointment(appointment);
                          break;
                        case 'caisse':
                          _openPatientPayment(appointment);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'whatsapp',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                          title: Text('WhatsApp'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'pvc',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.badge_outlined, color: Color(0xFF0F5B9E)),
                          title: Text('Carte PVC (ID)'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'print_a5',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.print_outlined, color: Colors.blueGrey),
                          title: Text('Fiche RDV (A5)'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'caisse',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.point_of_sale_outlined, color: Colors.teal),
                          title: Text('Caisse / Reçu'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                  tooltip: 'Envoyer rappel WhatsApp',
                  onPressed: () => _sendWhatsAppReminder(appointment),
                ),
                IconButton(
                  icon: const Icon(Icons.badge_outlined, color: Color(0xFF0F5B9E)),
                  tooltip: 'Imprimer la Carte PVC (ID-Card)',
                  onPressed: () => _printPvcCard(appointment),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: Colors.blueGrey),
                  tooltip: 'Imprimer la fiche de rendez-vous A5',
                  onPressed: () => _printAppointment(appointment),
                ),
                IconButton(
                  icon: const Icon(Icons.point_of_sale_outlined, color: Colors.teal),
                  tooltip: 'Caisse / Reçu validé du médecin',
                  onPressed: () => _openPatientPayment(appointment),
                ),
                const SizedBox(width: 4),
                statusWidget,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<Payment?> _getLatestPatientPayment(int patientId, DateTime date) async {
    try {
      final db = DatabaseManager.instance;
      final startStr = DateFormat('yyyy-MM-dd 00:00:00').format(date);
      final endStr = DateFormat('yyyy-MM-dd 23:59:59').format(date);
      final results = await db.query(
        'SELECT * FROM payments WHERE patient_id = ? AND payment_date >= ? AND payment_date <= ? AND is_deleted = 0 ORDER BY payment_date DESC LIMIT 1',
        [patientId, startStr, endStr],
      );
      if (results.isNotEmpty) {
        return Payment.fromMap(results.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _openPatientPayment(Appointment appointment) async {
    try {
      final payment = await _getLatestPatientPayment(
        appointment.patientId,
        appointment.appointmentDate,
      );
      if (!mounted) return;
      if (payment != null) {
        showDialog(
          context: context,
          builder: (context) => InvoicePrintDialog(payment: payment),
        );
      } else {
        // Check if there is any payment for this patient overall
        final db = DatabaseManager.instance;
        final anyResults = await db.query(
          'SELECT * FROM payments WHERE patient_id = ? AND is_deleted = 0 ORDER BY payment_date DESC LIMIT 1',
          [appointment.patientId],
        );
        if (!mounted) return;
        if (anyResults.isNotEmpty) {
          final p = Payment.fromMap(anyResults.first);
          showDialog(
            context: context,
            builder: (context) => InvoicePrintDialog(payment: p),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun paiement ou encaissement validé pour ce patient.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _printPvcCard(Appointment appointment) async {
    try {
      final db = DatabaseManager.instance;
      final results = await db.query(
        'SELECT * FROM patients WHERE patient_id = ?',
        [appointment.patientId],
      );
      if (results.isNotEmpty) {
        final patient = Patient.fromMap(results.first);
        if (!mounted) return;
        PvcAppointmentCardDialog.show(
          context: context,
          patient: patient,
          appointment: appointment,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient introuvable pour ce rendez-vous')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _printAppointment(Appointment appointment) async {
    try {
      final db = DatabaseManager.instance;
      final results = await db.query(
        'SELECT * FROM patients WHERE patient_id = ?',
        [appointment.patientId],
      );
      if (results.isNotEmpty) {
        final patient = Patient.fromMap(results.first);
        if (!mounted) return;
        final pdfBytes = generateAppointmentPdf(
          patient: patient,
          appointment: appointment,
        );
        showPdfPreview(context: context, generatedPdfBytes: pdfBytes);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient introuvable pour ce rendez-vous')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'impression : $e')),
      );
    }
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return const Color(0xFF0F5B9E);
      case AppointmentStatus.waitingRoom:
        return Colors.orange.shade800;
      case AppointmentStatus.completed:
        return const Color(0xFF16A34A);
      case AppointmentStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  Future<void> _sendWhatsAppReminder(Appointment appointment) async {
    try {
      final db = DatabaseManager.instance;
      final results = await db.query(
        'SELECT * FROM patients WHERE patient_id = ?',
        [appointment.patientId],
      );
      if (results.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dossier patient introuvable')),
        );
        return;
      }
      final patient = Patient.fromMap(results.first);
      final phone = patient.phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      if (phone.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun numéro de téléphone renseigné pour ce patient',
            ),
          ),
        );
        return;
      }

      // Format for international WhatsApp (Algeria 05/06/07 -> 2135/2136/2137)
      String waNumber = phone;
      if (waNumber.startsWith('0')) {
        waNumber = '213${waNumber.substring(1)}';
      }

      final dateFormatted = DateFormat(
        'dd/MM/yyyy à HH:mm',
      ).format(appointment.appointmentDate);
      final portalUrl =
          'https://chifa.medevsync.com/?phone=${patient.phone ?? patient.patientId}&pin=${patient.dateOfBirth.year}';

      final message =
          'Bonjour ${patient.firstName} ${patient.lastName},\n\n'
          'La Clinique Chifa vous rappelle votre rendez-vous prévu le *$dateFormatted*.\n\n'
          '📱 Vous pouvez consulter vos documents sur votre espace patient :\n$portalUrl\n\n'
          'Merci de bien vouloir nous confirmer votre présence.';

      final uri = Uri.parse(
        'https://wa.me/$waNumber?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi WhatsApp : $e')),
      );
    }
  }

  void _showQuickCheckInDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _QuickCheckInDialog(
        onCheckedIn: () {
          _loadAppointments();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOGUE SCAN D'ARRIVÉE & CHECK-IN SALLE D'ATTENTE
// ─────────────────────────────────────────────────────────────────────────────
class _QuickCheckInDialog extends StatefulWidget {
  final VoidCallback onCheckedIn;

  const _QuickCheckInDialog({required this.onCheckedIn});

  @override
  State<_QuickCheckInDialog> createState() => _QuickCheckInDialogState();
}

class _QuickCheckInDialogState extends State<_QuickCheckInDialog> {
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSearching = false;
  Patient? _foundPatient;
  Appointment? _todayAppointment;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus input for immediate USB barcode / QR scanner reading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _processScan(String rawInput) async {
    final query = rawInput.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _statusMessage = null;
      _isError = false;
      _foundPatient = null;
      _todayAppointment = null;
    });

    try {
      final db = DatabaseManager.instance;
      dynamic resolvedPatientId;
      String? resolvedPhone;

      // 1. Détection format JSON (Carte PVC Chifa)
      if (query.startsWith('{') && query.endsWith('}')) {
        try {
          final data = jsonDecode(query) as Map<String, dynamic>;
          resolvedPatientId = data['chifa_id'] ?? data['id'];
          resolvedPhone = data['tel']?.toString();
        } catch (_) {}
      }
      // 2. Détection format URL (medevsync.com/chifa/?phone=...&id=...)
      else if (query.contains('http') || query.contains('chifa') || query.contains('portal')) {
        try {
          final uri = Uri.parse(query);
          resolvedPatientId = uri.queryParameters['id'] ?? uri.queryParameters['patient_id'];
          resolvedPhone = uri.queryParameters['phone'] ?? uri.queryParameters['tel'];
        } catch (_) {}
      }

      // Si pas encore extrait, utiliser le texte brut
      resolvedPatientId ??= int.tryParse(query.replaceAll('#', ''));
      resolvedPhone ??= query;

      // Requête SQLite pour trouver le patient
      List<Map<String, dynamic>> results = [];
      if (resolvedPatientId != null && resolvedPatientId is int) {
        results = await db.query(
          'SELECT * FROM patients WHERE patient_id = ? AND is_deleted = 0 LIMIT 1',
          [resolvedPatientId],
        );
      }

      if (results.isEmpty && resolvedPhone.isNotEmpty) {
        results = await db.query(
          'SELECT * FROM patients WHERE (phone = ? OR national_id = ?) AND is_deleted = 0 LIMIT 1',
          [resolvedPhone, resolvedPhone],
        );
      }

      if (results.isEmpty) {
        // Recherche par nom / prénom
        results = await db.query(
          'SELECT * FROM patients WHERE (first_name LIKE ? OR last_name LIKE ?) AND is_deleted = 0 LIMIT 1',
          ['%$query%', '%$query%'],
        );
      }

      if (results.isEmpty) {
        setState(() {
          _isSearching = false;
          _isError = true;
          _statusMessage = 'Aucun patient trouvé correspondant à "$query".';
        });
        return;
      }

      final patient = Patient.fromMap(results.first);

      // Chercher le rendez-vous d'aujourd'hui pour ce patient
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final apptResults = await db.query(
        'SELECT * FROM appointments WHERE patient_id = ? AND date(appointment_date) = date(?) AND is_deleted = 0 ORDER BY appointment_date ASC LIMIT 1',
        [patient.patientId, todayStr],
      );

      Appointment? appt;
      if (apptResults.isNotEmpty) {
        appt = Appointment.fromMap(apptResults.first);
      }

      setState(() {
        _foundPatient = patient;
        _todayAppointment = appt;
      });

      // Si le patient a un RDV programmé aujourd'hui, enregistrer automatiquement en Salle d'Attente
      if (appt != null && appt.status == AppointmentStatus.scheduled) {
        await _checkInPatient();
      } else {
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _isError = true;
        _statusMessage = 'Erreur lors de la recherche : $e';
      });
    }
  }

  Future<void> _checkInPatient() async {
    if (_todayAppointment == null || _todayAppointment!.appointmentId == null) return;

    setState(() {
      _isSearching = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final apptId = _todayAppointment!.appointmentId!;
      final db = DatabaseManager.instance;

      // 1. Adapter la colonne status dans MySQL si elle est encore en ENUM('Scheduled'...)
      try {
        await db.execute(
          'ALTER TABLE `appointments` MODIFY COLUMN `status` VARCHAR(50) DEFAULT "Scheduled"',
        );
      } catch (_) {}

      // 2. Mettre à jour directement dans la base de données active
      await db.execute(
        'UPDATE appointments SET status = ?, needs_sync = 1 WHERE appointment_id = ?',
        [AppointmentStatus.waitingRoom.name, apptId],
      );

      // 3. Avertir le Cubit et attendre la fin de la mise à jour et du rechargement
      if (mounted) {
        await context.read<AppointmentCubit>().updateAppointmentStatus(
          apptId,
          AppointmentStatus.waitingRoom,
        );
      }

      // 4. Recharger la liste d'affichage principale
      widget.onCheckedIn();

      if (mounted) {
        setState(() {
          _isSearching = false;
          _todayAppointment = _todayAppointment!.copyWith(
            status: AppointmentStatus.waitingRoom,
          );
          _statusMessage = 'Patient enregistré avec succès en Salle d\'Attente !';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'Erreur lors du check-in : $e';
          _isError = true;
        });
      }
    }
  }

  Future<void> _pickAndScanImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isSearching = true;
        _statusMessage = 'Analyse de l\'image du QR code en cours...';
        _isError = false;
      });

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      final qr = qrcv.QrCode();
      qr.scanImageBytes(bytes);
      final text = qr.content?.text;

      if (text != null && text.trim().isNotEmpty) {
        _scanController.text = text.trim();
        await _processScan(text.trim());
      } else {
        setState(() {
          _isSearching = false;
          _isError = true;
          _statusMessage =
              'Aucun code QR lisible n\'a été détecté dans cette image. Assurez-vous que le QR code est bien cadré et net.';
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _isError = true;
        _statusMessage = 'Erreur lors de la lecture de l\'image : $e';
      });
    }
  }

  Future<void> _openCameraOrPhoneScanner() async {
    final sessionId = 'scan_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final scannerUrl = 'https://chifa.medevsync.com/scanner?session=$sessionId';

    Timer? pollTimer;
    bool isDialogClosed = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        pollTimer = Timer.periodic(const Duration(milliseconds: 1300), (timer) async {
          if (isDialogClosed) {
            timer.cancel();
            return;
          }
          try {
            final res = await http.get(
              Uri.parse('https://chifa.medevsync.com/api/tv/scan-session/$sessionId'),
            ).timeout(const Duration(seconds: 2));

            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              final scanResult = data['scanResult'] as String?;
              if (scanResult != null && scanResult.trim().isNotEmpty) {
                timer.cancel();
                if (!isDialogClosed && dialogContext.mounted && Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  _scanController.text = scanResult;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Données QR reçues avec succès depuis la caméra !'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  await _processScan(scanResult);
                }
              }
            }
          } catch (_) {}
        });


        final isMobileDlg = dialogContext.isMobile;
        final dlgWidth = isMobileDlg
            ? MediaQuery.of(dialogContext).size.width - 32
            : 440.0;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: dlgWidth,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobileDlg ? 16.0 : 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code_scanner, color: Color(0xFF0F5B9E), size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  isMobileDlg ? 'Scanner QR' : 'Scanner Caméra & Smartphone',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: scannerUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Option A : Téléphone Portable (Sans fil)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Scannez ce QR Code avec l\'appareil photo de votre smartphone pour ouvrir le scanner et viser la carte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Option B : Webcam du Laptop / Ordinateur',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(scannerUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text('Ouvrir la Webcam du PC'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'En attente de détection du code QR...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );

    isDialogClosed = true;
    pollTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = isMobile ? screenWidth - 32 : 550.0;
    final dialogPadding = isMobile ? 16.0 : 24.0;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(dialogPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F5B9E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFF0F5B9E),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Arrivée & Check-in Patient',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Scannez la carte PVC ou entrez l\'ID / N° Tél du patient',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Champ Scan / Saisie
              TextField(
                controller: _scanController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'Données scannées / N° Patient / Téléphone',
                  hintText: 'Ex: #0012, 0661234567, ou QR Code...',
                  prefixIcon: const Icon(Icons.barcode_reader),
                  suffixIcon: _scanController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _scanController.clear();
                            setState(() {
                              _foundPatient = null;
                              _todayAppointment = null;
                              _statusMessage = null;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: _processScan,
              ),
              const SizedBox(height: 12),

              // Barre d'options de Scan (Image QR, Caméra/Smartphone, Recherche)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSearching ? null : _pickAndScanImage,
                        icon: const Icon(Icons.image_search, size: 18),
                        label: const Text('Image QR'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed:
                            _isSearching ? null : _openCameraOrPhoneScanner,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Caméra / Tél'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _isSearching
                        ? null
                        : () => _processScan(_scanController.text),
                    icon: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: const Text('Rechercher'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),

              // Messages d'état / Erreur
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isError
                          ? Colors.red.shade200
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isError ? Icons.error_outline : Icons.check_circle,
                        color: _isError
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _isError
                                ? Colors.red.shade900
                                : Colors.green.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Résultat Patient Trouvé
              if (_foundPatient != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête Patient
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF0F5B9E),
                            child: Text(
                              '${_foundPatient!.firstName.isNotEmpty ? _foundPatient!.firstName[0].toUpperCase() : ""}'
                              '${_foundPatient!.lastName.isNotEmpty ? _foundPatient!.lastName[0].toUpperCase() : ""}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_foundPatient!.lastName.toUpperCase()} ${_foundPatient!.firstName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: #${_foundPatient!.patientId} • Tél: ${_foundPatient!.phone ?? "Non renseigné"} • Âge: ${_foundPatient!.formattedAge}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Statut du RDV d'aujourd'hui
                      if (_todayAppointment != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Color(0xFF0F5B9E),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'RDV aujourd\'hui à ${DateFormat("HH:mm").format(_todayAppointment!.appointmentDate)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _todayAppointment!.status ==
                                        AppointmentStatus.waitingRoom
                                    ? Colors.orange.shade800
                                    : const Color(0xFF0F5B9E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _todayAppointment!.status.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action Check-in
                        if (_todayAppointment!.status ==
                            AppointmentStatus.scheduled)
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _checkInPatient,
                              icon: const Icon(Icons.meeting_room),
                              label: const Text(
                                'Confirmer Arrivée (En Salle d\'Attente)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        else if (_todayAppointment!.status ==
                            AppointmentStatus.waitingRoom)
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Patient déjà en salle d\'attente',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.amber.shade900,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Aucun rendez-vous prévu aujourd\'hui pour ce patient.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }
}