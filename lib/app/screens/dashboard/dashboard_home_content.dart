import 'dart:math' as math;

import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/dashboard_cubit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dashboard Home Content with Statistics and Charts
class DashboardHomeContent extends StatefulWidget {
  const DashboardHomeContent({super.key});

  @override
  State<DashboardHomeContent> createState() => _DashboardHomeContentState();
}

class _DashboardHomeContentState extends State<DashboardHomeContent> {
  int _timeRange = 6; // Default to 6 months
  final Map<String, int> _timeOptions = {
    '1 Month': 1,
    '3 Months': 3,
    '6 Months': 6,
    '1 Year': 12,
    'All Time': 1200,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardCubit>().loadDashboardStatistics();
      context.read<DashboardCubit>().loadMonthlyRevenueData(_timeRange);
      context.read<DashboardCubit>().loadMonthlyAppointmentsData(_timeRange);
    });
  }

  void _updateTimeRange(int months) {
    setState(() {
      _timeRange = months;
    });
    context.read<DashboardCubit>().loadMonthlyRevenueData(_timeRange);
    context.read<DashboardCubit>().loadMonthlyAppointmentsData(_timeRange);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DashboardError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<DashboardCubit>().loadDashboardStatistics();
                    context.read<DashboardCubit>().loadMonthlyRevenueData(
                      _timeRange,
                    );
                    context.read<DashboardCubit>().loadMonthlyAppointmentsData(
                      _timeRange,
                    );
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is! DashboardStatisticsLoaded) {
          return const Center(child: Text('No statistics available'));
        }

        final statistics = state.statistics;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<DashboardCubit>().loadDashboardStatistics();
            context.read<DashboardCubit>().loadMonthlyRevenueData(_timeRange);
            context.read<DashboardCubit>().loadMonthlyAppointmentsData(
              _timeRange,
            );
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 12 : 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Welcome Header with Logout
                    _buildWelcomeHeader(),
                    const SizedBox(height: 16),

                    // Time Range Selector
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _timeOptions.entries.map((entry) {
                            final isSelected = _timeRange == entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (bool selected) {
                                  if (selected) {
                                    _updateTimeRange(entry.value);
                                  }
                                },
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                backgroundColor: Theme.of(context).cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.of(context).size.width < 600
                                      ? 8
                                      : 12,
                                  vertical:
                                      MediaQuery.of(context).size.width < 600
                                      ? 8
                                      : 12,
                                ),
                                elevation: isSelected ? 4 : 0,
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Statistics Cards
                    _buildStatsGrid(statistics),
                    const SizedBox(height: 24),

                    // Charts Section Header
                    _buildSectionHeader('Analytics & Reports'),
                    const SizedBox(height: 16),

                    // Charts Row
                    if (MediaQuery.of(context).size.width > 900)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRevenueChart(statistics)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildAppointmentsChart(statistics)),
                        ],
                      )
                    else if (MediaQuery.of(context).size.width > 600)
                      Column(
                        children: [
                          _buildRevenueChart(statistics),
                          const SizedBox(height: 24),
                          _buildAppointmentsChart(statistics),
                        ],
                      )
                    else
                      Column(
                        children: [
                          // On small mobile, maybe make charts a bit shorter
                          SizedBox(
                            height: 250,
                            child: _buildRevenueChart(statistics),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 250,
                            child: _buildAppointmentsChart(statistics),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Status Breakdown Header
                    _buildSectionHeader('Status Overview'),
                    const SizedBox(height: 16),

                    // Status Cards
                    if (MediaQuery.of(context).size.width > 900) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildAppointmentStatusCard(statistics),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: _buildPatientStatusCard(statistics)),
                        ],
                      ),
                    ] else ...[
                      _buildAppointmentStatusCard(statistics),
                      const SizedBox(height: 24),
                      _buildPatientStatusCard(statistics),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, Dr. ${user?.fullName ?? 'Unknown'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user?.specialization != null)
                      Text(
                        user!.specialization!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isMobile) _buildLogoutButton(context),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildLogoutButton(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          if (!mounted) return;
          context.read<AuthCubit>().logout();
        }
      },
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('Sign Out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  (isMobile
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineMedium)
                      ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DashboardCubit>().loadDashboardStatistics();
              context.read<DashboardCubit>().loadMonthlyRevenueData(_timeRange);
              context.read<DashboardCubit>().loadMonthlyAppointmentsData(
                _timeRange,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStatistics statistics) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 1200) {
      crossAxisCount = 2;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: width < 600 ? 12 : 20,
      mainAxisSpacing: width < 600 ? 12 : 20,
      childAspectRatio: width < 400 ? 1.8 : (width < 600 ? 2.2 : 1.1),
      children: [
        _StatCard(
          title: 'Total Patients',
          value: statistics.totalPatients.toString(),
          icon: Icons.people,
          color: Colors.blue,
          onTap: () => _navigateToSection('patients'),
        ),
        _StatCard(
          title: 'Total Appointments',
          value: statistics.totalAppointments.toString(),
          icon: Icons.calendar_today,
          color: Colors.green,
          onTap: () => _navigateToSection('appointments'),
        ),
        _StatCard(
          title: 'Medical Records',
          value: statistics.totalMedicalRecords.toString(),
          icon: Icons.description,
          color: Colors.purple,
          onTap: () => _navigateToSection('medical_records'),
        ),
        _StatCard(
          title: 'Total Revenue',
          value: '${statistics.totalRevenue.toStringAsFixed(2)} DA',
          icon: Icons.attach_money,
          color: Colors.teal,
          onTap: () => _navigateToSection('revenue'),
        ),
        _StatCard(
          title: 'Certificates',
          value: statistics.totalCertificates.toString(),
          icon: Icons.verified,
          color: Colors.orange,
          onTap: () => _navigateToSection('certificates'),
        ),
        _StatCard(
          title: 'Lab Orders',
          value: statistics.totalLabOrders.toString(),
          icon: Icons.biotech,
          color: Colors.red,
          onTap: () => _navigateToSection('lab_orders'),
        ),
        _StatCard(
          title: "Today's Appts",
          value: statistics.todayAppointments.toString(),
          icon: Icons.event_available,
          color: Colors.indigo,
          onTap: () => _navigateToSection('today_appointments'),
        ),
        _StatCard(
          title: 'Low Stock Items',
          value: statistics.lowStockItems.toString(),
          icon: Icons.warning,
          color: statistics.lowStockItems > 0 ? Colors.red : Colors.green,
          onTap: () => _navigateToSection('inventory'),
        ),
      ],
    );
  }

  void _navigateToSection(String section) {
    // Implement navigation to specific sections
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Navigating to $section')));
  }

  Widget _buildRevenueChart(DashboardStatistics statistics) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Monthly Revenue',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Icons.monetization_on, color: Colors.teal),
              ],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final maxRevenue = statistics.revenueByMonth.isEmpty
                    ? 0.0
                    : statistics.revenueByMonth.reduce((a, b) => a > b ? a : b);
                final chartMaxY = math.max(1000.0, maxRevenue * 1.2);
                final sideInterval = math.max(1.0, chartMaxY / 5);

                return SizedBox(
                  height: 200,
                  child: statistics.revenueByMonth.isEmpty
                      ? const Center(child: Text('No data available'))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: chartMaxY,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (group) => Colors.blueGrey,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                      final monthNames = _getMonthNames(
                                        _timeRange,
                                      );
                                      final month = monthNames[group.x.toInt()];
                                      return BarTooltipItem(
                                        '$month\n${rod.toY.toStringAsFixed(0)} DA',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    final monthNames = _getMonthNames(
                                      _timeRange,
                                    );
                                    final index = value.toInt();
                                    if (index >= 0 &&
                                        index < monthNames.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          monthNames[index],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: sideInterval,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value ~/ 1000}k',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: statistics.revenueByMonth
                                .asMap()
                                .entries
                                .map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value,
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.tealAccent.shade400,
                                            Colors.teal,
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                        width: 22,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(6),
                                          topRight: Radius.circular(6),
                                        ),
                                      ),
                                    ],
                                  );
                                })
                                .toList(),
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsChart(DashboardStatistics statistics) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Monthly Appointments',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Icons.calendar_month, color: Colors.blue),
              ],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final maxAppts = statistics.appointmentsByMonth.isEmpty
                    ? 0.0
                    : statistics.appointmentsByMonth
                          .reduce((a, b) => a > b ? a : b)
                          .toDouble();
                final chartMaxY = math.max(10.0, maxAppts * 1.2);
                final sideInterval = math.max(1.0, chartMaxY / 5);

                return SizedBox(
                  height: 200,
                  child: statistics.appointmentsByMonth.isEmpty
                      ? const Center(child: Text('No data available'))
                      : LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (group) => Colors.blueGrey,
                                getTooltipItems: (group) => group.map((spot) {
                                  final monthNames = _getMonthNames(_timeRange);
                                  final month = monthNames[spot.x.toInt()];
                                  return LineTooltipItem(
                                    '$month\n${spot.y.toInt()} appts',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    final monthNames = _getMonthNames(
                                      _timeRange,
                                    );
                                    final index = value.toInt();
                                    if (index >= 0 &&
                                        index < monthNames.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          monthNames[index],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: sideInterval,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: statistics.appointmentsByMonth
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      return FlSpot(
                                        entry.key.toDouble(),
                                        entry.value.toDouble(),
                                      );
                                    })
                                    .toList(),
                                isCurved: true,
                                gradient: const LinearGradient(
                                  colors: [Colors.blue, Colors.indigo],
                                ),
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) =>
                                          FlDotCirclePainter(
                                            radius: 4,
                                            color: Colors.white,
                                            strokeWidth: 2,
                                            strokeColor: Colors.indigo,
                                          ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.blue.withValues(alpha: 0.3),
                                      Colors.blue.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getMonthNames(int range) {
    final now = DateTime.now();
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Return last N months
    final result = <String>[];
    for (int i = range - 1; i >= 0; i--) {
      final monthIndex = (now.month - 1 - i) % 12;
      final adjustedIndex = monthIndex < 0 ? monthIndex + 12 : monthIndex;
      result.add(monthNames[adjustedIndex]);
    }
    return result;
  }

  Widget _buildAppointmentStatusCard(DashboardStatistics statistics) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pie_chart, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Text(
                  'Appointments Status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...statistics.appointmentsByStatus.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatStatus(entry.key),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: statistics.totalAppointments == 0
                              ? 0
                              : entry.value / statistics.totalAppointments,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStatusColor(entry.key),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientStatusCard(DashboardStatistics statistics) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_alt, color: Colors.cyan),
                ),
                const SizedBox(width: 12),
                Text(
                  'Patients Status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...statistics.patientsByStatus.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatStatus(entry.key),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: statistics.totalPatients == 0
                              ? 0
                              : entry.value / statistics.totalPatients,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStatusColor(entry.key),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }

  String _formatStatus(String status) {
    return status
        .split('_')
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a pseudo-trend based on the title length for demo purposes
    final isPositive = title.length % 2 == 0;
    final trendValue = (title.length * 1.5).toStringAsFixed(1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Glassmorphism subtle background gradient
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 600 ? 16.0 : 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              icon,
                              color: color,
                              size: MediaQuery.of(context).size.width < 600
                                  ? 22
                                  : 28,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: isPositive ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$trendValue%',
                                  style: TextStyle(
                                    color: isPositive
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        value,
                        style:
                            (MediaQuery.of(context).size.width < 600
                                    ? Theme.of(context).textTheme.titleLarge
                                    : Theme.of(
                                        context,
                                      ).textTheme.headlineMedium)
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}
