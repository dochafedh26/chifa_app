import 'package:chifa/app/cubits/settings_cubit.dart';
import 'package:chifa/app/screens/settings/clinic_settings_dialog.dart';
import 'package:chifa/app/screens/settings/services_settings_tab.dart';
import 'package:chifa/app/screens/settings/user_form_dialog.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:chifa/services/db/sync_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chifa/app/utils/responsive.dart';

/// Settings Screen - User management and clinic settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<SettingsCubit>().loadUsers();
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateUserDialog() {
    showDialog(context: context, builder: (context) => const UserFormDialog());
  }

  void _showClinicSettings() {
    showDialog(
      context: context,
      builder: (context) => const ClinicSettingsDialog(),
    );
  }

  void _showFullSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Full Sync'),
        content: const Text(
          'This will pull ALL data from the remote database, overwriting any local changes. '
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SyncManager().trySync(forceFullSync: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Full Sync'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Column(
      children: [
        // Tabs
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.people),
              text: isMobile ? 'Users' : 'Users Management',
            ),
            Tab(
              icon: const Icon(Icons.business),
              text: isMobile ? 'Clinic' : 'Clinic Settings',
            ),
            Tab(
              icon: const Icon(Icons.medical_services_outlined),
              text: isMobile ? 'Tarifs' : 'Services & Tarifs',
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UsersTab(onCreateUser: _showCreateUserDialog),
              _SettingsTab(
                onShowClinicSettings: _showClinicSettings,
                onFullSync: () => _showFullSyncDialog(context),
              ),
              const ServicesSettingsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== USERS TAB ====================

class _UsersTab extends StatelessWidget {
  final VoidCallback onCreateUser;

  const _UsersTab({required this.onCreateUser});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: onCreateUser,
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
              ),
            ],
          ),
        ),

        // Users List
        Expanded(
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              if (state is SettingsLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is SettingsError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text('Error: ${state.message}'),
                    ],
                  ),
                );
              }

              if (state is UsersLoaded) {
                if (state.users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.users.length,
                  itemBuilder: (context, index) {
                    final user = state.users[index];
                    return _UserCard(user: user);
                  },
                );
              }

              return const Center(child: Text('No data available'));
            },
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final Employee user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isPending = !user.isActive;
    final isMobile = context.isMobile;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPending
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 8 : 16,
        ),
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
          child: Icon(_getRoleIcon(user.role), color: _getRoleColor(user.role)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isPending)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 6 : 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 12, color: Colors.orange.shade800),
                    if (!isMobile) ...[
                      const SizedBox(width: 4),
                      Text(
                        'En attente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Email: ${user.email}', overflow: TextOverflow.ellipsis),
            Text('Role: ${_formatRole(user.role)}'),
            if (user.specialization != null && user.specialization!.isNotEmpty)
              Text('Specialization: ${user.specialization}', overflow: TextOverflow.ellipsis),
            if (isPending) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  if (user.employeeId != null) {
                    context.read<SettingsCubit>().approveUser(user.employeeId!);
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(isMobile ? 'Approuver' : 'Approuver le compte'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<int>(
          onSelected: (value) {
            if (value == 1) {
              _showEditUserDialog(context, user);
            } else if (value == 2) {
              _showDeleteConfirmation(context, user);
            } else if (value == 3 && user.employeeId != null) {
              context.read<SettingsCubit>().toggleUserActive(user.employeeId!, !user.isActive);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 1, child: Text('Edit')),
            PopupMenuItem(
              value: 3,
              child: Text(user.isActive ? 'Désactiver le compte' : 'Activer / Approuver'),
            ),
            const PopupMenuItem(value: 2, child: Text('Delete')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, Employee user) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(employee: user),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Employee user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsCubit>().deleteUser(user.employeeId!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.admin:
        return Colors.red;
      case EmployeeRole.doctor:
        return Colors.blue;
      case EmployeeRole.nurse:
        return Colors.green;
      case EmployeeRole.patient:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.admin:
        return Icons.admin_panel_settings;
      case EmployeeRole.doctor:
        return Icons.medical_services;
      case EmployeeRole.nurse:
        return Icons.local_hospital;
      case EmployeeRole.patient:
        return Icons.person;
    }
  }

  String _formatRole(EmployeeRole role) {
    return role.name[0].toUpperCase() + role.name.substring(1).toLowerCase();
  }
}

// ==================== SETTINGS TAB ====================

class _SettingsTab extends StatelessWidget {
  final VoidCallback onShowClinicSettings;
  final VoidCallback onFullSync;

  const _SettingsTab({
    required this.onShowClinicSettings,
    required this.onFullSync,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = (state is SettingsLoaded)
            ? state.settings
            : const ClinicSettings();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clinic Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Clinic Information',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: onShowClinicSettings,
                            tooltip: 'Edit Settings',
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _SettingRow(
                        icon: Icons.business,
                        label: 'Clinic Name',
                        value: settings.clinicName,
                      ),
                      _SettingRow(
                        icon: Icons.location_on,
                        label: 'Address',
                        value: settings.clinicAddress,
                      ),
                      _SettingRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: settings.clinicPhone,
                      ),
                      _SettingRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: settings.clinicEmail,
                      ),
                      _SettingRow(
                        icon: Icons.medical_services,
                        label: 'Doctor',
                        value: settings.doctorName,
                      ),
                      _SettingRow(
                        icon: Icons.work,
                        label: 'Specialization',
                        value: settings.doctorSpecialization,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Preferences Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferences',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _SettingRow(
                        icon: Icons.language,
                        label: 'Language',
                        value: _formatLanguage(settings.language),
                      ),
                      _SettingRow(
                        icon: Icons.palette,
                        label: 'Theme',
                        value: _formatTheme(settings.theme),
                      ),
                      _SettingRow(
                        icon: Icons.attach_money,
                        label: 'Currency',
                        value: settings.currency,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cloud Sync Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Synchronization',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.cloud_sync,
                            size: 24,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Force Synchronization',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Update local data from cloud and push changes.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ValueListenableBuilder<SyncProgress>(
                            valueListenable: SyncManager().syncProgress,
                            builder: (context, progress, child) {
                              if (progress.isSyncing) {
                                return Column(
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(progress.progress * 100).toInt()}%',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                );
                              }
                              return Builder(
                                builder: (context) {
                                  final isMobile = context.isMobile;
                                  final syncButtons = [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (DatabaseManager.secondary == null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'You are directly connected to the cloud. Synchronization is automatic.',
                                              ),
                                            ),
                                          );
                                        } else {
                                          SyncManager().trySync();
                                        }
                                      },
                                      icon: const Icon(Icons.sync),
                                      label: const Text('Sync'),
                                    ),
                                    SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 8 : 0),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (DatabaseManager.secondary == null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'You are directly connected to the cloud. Synchronization is automatic.',
                                              ),
                                            ),
                                          );
                                        } else {
                                          onFullSync();
                                        }
                                      },
                                      icon: const Icon(Icons.sync),
                                      label: const Text('Full Sync'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                      ),
                                    ),
                                  ];
                                  return isMobile
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: syncButtons,
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: syncButtons,
                                        );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Statistics Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistics',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _SettingRow(
                        icon: Icons.people,
                        label: 'Total Users',
                        value: context
                            .read<SettingsCubit>()
                            .usersCount
                            .toString(),
                      ),
                      _SettingRow(
                        icon: Icons.medical_services,
                        label: 'Doctors',
                        value: context
                            .read<SettingsCubit>()
                            .doctorsCount
                            .toString(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatLanguage(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }

  String _formatTheme(String theme) {
    switch (theme) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'system':
        return 'System Default';
      default:
        return theme;
    }
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(value, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
