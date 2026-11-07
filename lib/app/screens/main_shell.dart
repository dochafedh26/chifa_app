import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/utils/role_permissions.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:chifa/app/screens/appointments/appointment_list_screen.dart';
import 'package:chifa/app/screens/bilan/bilan_screen.dart';
import 'package:chifa/app/screens/billing/billing_screen.dart';
import 'package:chifa/app/screens/certificates/certificates_screen.dart';
import 'package:chifa/app/screens/dashboard/dashboard_screen.dart';
import 'package:chifa/app/screens/inventory/inventory_screen.dart';
import 'package:chifa/app/screens/medical_records/medical_records_screen.dart';
import 'package:chifa/app/screens/patients/patient_list_screen.dart';
import 'package:chifa/app/screens/prescriptions/prescription_screen.dart';
import 'package:chifa/app/screens/ai_search/ai_search_screen.dart';
import 'package:chifa/app/screens/settings/settings_screen.dart';
import 'package:chifa/app/screens/workspace/workspace_screen.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/app/widgets/notification_bell_widget.dart';
import 'package:chifa/app/widgets/sync_indicator.dart';
import 'package:chifa/app/widgets/xampp_connection_dialog.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:chifa/services/db/sync_manager.dart';
import 'package:chifa/tunnel/screens/tunnel_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _hasShownXamppDialog = false;

  static const _allNavItems = <_NavItem>[
    _NavItem('dashboard', Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(
      'appointments',
      Icons.calendar_today_outlined,
      Icons.calendar_today,
      'Appointments',
    ),
    _NavItem('patients', Icons.people_outline, Icons.people, 'Patients'),
    _NavItem('medical_records', Icons.folder_shared_outlined, Icons.folder_shared, 'Records'),
    _NavItem('billing', Icons.receipt_long_outlined, Icons.receipt_long, 'Billing'),
    _NavItem('prescriptions', Icons.medication_outlined, Icons.medication, 'Prescriptions'),
    _NavItem('inventory', Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
    _NavItem('bilan', Icons.biotech_outlined, Icons.biotech, 'Bilan'),
    _NavItem('certificates', Icons.description_outlined, Icons.description, 'Certifs'),
    _NavItem('ai_search', Icons.auto_awesome_outlined, Icons.auto_awesome, 'IA Clinique'),
    _NavItem('tunnel', Icons.lan_outlined, Icons.lan, 'Tunnel'),
    _NavItem('settings', Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  List<_NavItem> _buildVisibleNavItems(EmployeeRole? role) {
    return _allNavItems
        .where((item) => RolePermissions.canAccessTab(role, item.id))
        .map((item) {
          if (item.id == 'billing' && role == EmployeeRole.nurse) {
            return const _NavItem(
              'billing',
              Icons.point_of_sale_outlined,
              Icons.point_of_sale,
              'Caisse',
            );
          }
          return item;
        })
        .toList();
  }

  List<_NavItem> _getVisibleNavItems() {
    final role = context.watch<AuthCubit>().currentRole;
    return _buildVisibleNavItems(role);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final role = context.read<AuthCubit>().currentRole;
      final visible = _buildVisibleNavItems(role);
      _onDestinationSelected(0, visible);
      _listenToSyncErrors();
    });
  }

  void _listenToSyncErrors() {
    SyncManager().syncProgress.addListener(_onSyncProgressChanged);
  }

  void _onSyncProgressChanged() {
    final progress = SyncManager().syncProgress.value;
    if (progress.error != null && !_hasShownXamppDialog) {
      final errorStr = progress.error!.toLowerCase();
      if (errorStr.contains('econnrefused') ||
          errorStr.contains('connection refused') ||
          errorStr.contains('connect econnrefused')) {
        _hasShownXamppDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            XamppConnectionDialog.show(
              context,
              errorMessage: progress.error,
              onRetry: () {
                _hasShownXamppDialog = false;
                SyncManager().syncProgress.value = SyncProgress(
                  isSyncing: false,
                );
                SyncManager().trySync(forceFullSync: true);
              },
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    SyncManager().syncProgress.removeListener(_onSyncProgressChanged);
    super.dispose();
  }

  void _onDestinationSelected(int index, List<_NavItem> items) {
    if (index < 0 || index >= items.length) return;
    setState(() => _selectedIndex = index);

    final workspaceCubit = context.read<WorkspaceCubit>();
    final screens = <String, Widget>{
      'dashboard': const DashboardScreen(),
      'appointments': const AppointmentListScreen(),
      'patients': const PatientListScreen(),
      'medical_records': const MedicalRecordsScreen(),
      'billing': const BillingScreen(),
      'prescriptions': const PrescriptionScreen(),
      'inventory': const InventoryScreen(),
      'bilan': const BilanScreen(),
      'certificates': const CertificatesScreen(),
      'ai_search': const AiSearchScreen(),
      'tunnel': const TunnelShell(),
      'settings': const SettingsScreen(),
    };

    final item = items[index];
    final id = item.id;
    final title = item.label;
    if (screens.containsKey(id)) {
      workspaceCubit.openTab(
        WorkspaceTab(id: id, title: title, content: screens[id]!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getVisibleNavItems();
    if (_selectedIndex >= navItems.length && navItems.isNotEmpty) {
      _selectedIndex = 0;
    }

    return Builder(
      builder: (context) {
        final isMobile = context.isMobile;
        final isLandscapePhone = context.isPhoneLandscape;

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: isLandscapePhone ? 46 : 56,
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isLandscapePhone ? 26 : 32,
                    height: isLandscapePhone ? 26 : 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryLight, AppTheme.primary],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: isLandscapePhone ? 14 : 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CHIFA',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: isLandscapePhone ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              actions: const [
                NotificationBellWidget(),
                SizedBox(width: 8),
              ],
            ),
            drawer: _buildDrawer(navItems),
            body: const WorkspaceScreen(),
            bottomNavigationBar: isLandscapePhone ? null : _buildBottomNav(navItems),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _buildSidebar(navItems),
              const Expanded(child: WorkspaceScreen()),
            ],
          ),
        );
      },
    );
  }

  // ─── Mobile Navigation ──────────────────────────────────────────────

  Widget _buildBottomNav(List<_NavItem> items) {
    // Show only up to first 5 items on bottom nav
    final bottomItems = items.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex < bottomItems.length ? _selectedIndex : 0,
        onTap: (i) => _onDestinationSelected(i, items),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textTertiary,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 0,
        items: bottomItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDrawer(List<_NavItem> items) {
    return Drawer(
      backgroundColor: AppTheme.sidebarBackground,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.sidebarSurface),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryLight, AppTheme.primary],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CHIFA CMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isSelected = _selectedIndex == i;
                return ListTile(
                  leading: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected
                        ? AppTheme.primaryLight
                        : AppTheme.sidebarText,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.sidebarText,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    Navigator.pop(context);
                    _onDestinationSelected(i, items);
                  },
                );
              },
            ),
          ),
          const SyncIndicator(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Premium Dark Sidebar (Desktop & Tablet) ───────────────────────
  Widget _buildSidebar(List<_NavItem> items) {
    final isCompactSidebar = context.screenWidth < 1100;
    return Container(
      width: isCompactSidebar ? 124 : 180,
      decoration: BoxDecoration(
        color: AppTheme.sidebarBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Logo / Brand ──────────────────────────────
          SizedBox(height: isCompactSidebar ? 12 : 16),
          Container(
            width: isCompactSidebar ? 40 : 46,
            height: isCompactSidebar ? 40 : 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryLight, AppTheme.primary],
              ),
              borderRadius: BorderRadius.circular(isCompactSidebar ? 12 : 14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.local_hospital_rounded,
              color: Colors.white,
              size: isCompactSidebar ? 20 : 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'CHIFA',
            style: TextStyle(
              color: AppTheme.sidebarTextActive,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: isCompactSidebar ? 12 : 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 1,
            color: AppTheme.sidebarSurface,
          ),
          SizedBox(height: isCompactSidebar ? 8 : 12),

          // ── Nav Items ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  // Insert a divider before Settings if present
                  if (item.id == 'settings') {
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          height: 1,
                          color: AppTheme.sidebarSurface,
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem(i, items, isCompact: isCompactSidebar),
                      ],
                    );
                  }
                  return _buildNavItem(i, items, isCompact: isCompactSidebar);
                }),
              ),
            ),
          ),
          const SyncIndicator(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    List<_NavItem> items, {
    bool isCompact = false,
  }) {
    final item = items[index];
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _onDestinationSelected(index, items),
          borderRadius: BorderRadius.circular(14),
          splashColor: AppTheme.primary.withValues(alpha: 0.15),
          hoverColor: AppTheme.sidebarSurface.withValues(alpha: 0.6),
          child: AnimatedContainer(
            width: isCompact ? 104.0 : 120.0,
            height: isCompact ? 64.0 : 80.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 6 : 10,
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Active indicator dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 20 : 0,
                  height: 3,
                  margin: EdgeInsets.only(bottom: isCompact ? 4 : 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: isCompact ? 20 : 22,
                  color: isSelected
                      ? AppTheme.primaryLight
                      : AppTheme.sidebarText,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: isCompact ? 11.5 : 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.sidebarTextActive
                        : AppTheme.sidebarText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String id;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.id, this.icon, this.activeIcon, this.label);
}
