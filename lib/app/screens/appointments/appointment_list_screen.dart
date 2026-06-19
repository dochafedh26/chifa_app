import 'package:chifa/app/cubits/appointment_cubit.dart';
import 'package:chifa/app/screens/appointments/appointment_form_dialog.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/models/appointment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  DateTime _selectedDate = DateTime.now();
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
    context.read<AppointmentCubit>().loadAppointmentsByDate(_selectedDate);
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadAppointments();
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
      builder: (context) => AppointmentFormDialog(
        selectedDate: _selectedDate,
        onSave: (appointment) {
          context.read<AppointmentCubit>().createAppointment(appointment);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = _selectedDate.subtract(
                                      const Duration(days: 1),
                                    );
                                  });
                                  _loadAppointments();
                                },
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedDate = picked);
                                      _loadAppointments();
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      Text(
                                        DateFormat(
                                          'EEEE',
                                        ).format(_selectedDate),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd MMMM yyyy',
                                        ).format(_selectedDate),
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
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = _selectedDate.add(
                                      const Duration(days: 1),
                                    );
                                  });
                                  _loadAppointments();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _goToToday,
                                  child: const Text('Today'),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                    : Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Previous day',
                            onPressed: () {
                              setState(() {
                                _selectedDate = _selectedDate.subtract(
                                  const Duration(days: 1),
                                );
                              });
                              _loadAppointments();
                            },
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                  _loadAppointments();
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('EEEE').format(_selectedDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'dd MMMM yyyy',
                                      ).format(_selectedDate),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Next day',
                            onPressed: () {
                              setState(() {
                                _selectedDate = _selectedDate.add(
                                  const Duration(days: 1),
                                );
                              });
                              _loadAppointments();
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _goToToday,
                            child: const Text('Today'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showAddDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Appointment'),
                          ),
                        ],
                      ),
              ),
            ),

            // Filters Row
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('All', null),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Scheduled',
                                  AppointmentStatus.scheduled,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Completed',
                                  AppointmentStatus.completed,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Cancelled',
                                  AppointmentStatus.cancelled,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 42,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by patient name...',
                                prefixIcon: const Icon(Icons.search, size: 18),
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
                      )
                    : Row(
                        children: [
                          // Status Filter Chips
                          const Icon(
                            Icons.filter_list,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip('All', null),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'Scheduled',
                            AppointmentStatus.scheduled,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'Completed',
                            AppointmentStatus.completed,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'Cancelled',
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
        return const Center(child: Text('No appointments for this day'));
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
        subtitle: Text(
          '${DateFormat('HH:mm').format(appointment.appointmentDate)} - ${appointment.notes ?? "No notes"}',
        ),
        trailing: PopupMenuButton<AppointmentStatus>(
          onSelected: (status) {
            context.read<AppointmentCubit>().updateAppointmentStatus(
              appointment.appointmentId!,
              status,
            );
          },
          itemBuilder: (context) => AppointmentStatus.values.map((s) {
            return PopupMenuItem(value: s, child: Text(s.name));
          }).toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _getStatusColor(appointment.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              appointment.status.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Colors.blue;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }
}
