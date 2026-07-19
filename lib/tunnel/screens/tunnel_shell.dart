import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tunnel_service.dart';
import '../services/settings_service.dart';
import '../models/tunnel_config.dart';
import 'home_screen.dart';
import 'file_explorer_screen.dart';
import 'terminal_screen.dart';
import 'devices_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class TunnelShell extends StatefulWidget {
  const TunnelShell({super.key});

  @override
  State<TunnelShell> createState() => _TunnelShellState();
}

class _TunnelShellState extends State<TunnelShell> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersistedTunnels();
    });
  }

  void _loadPersistedTunnels() {
    final settings = context.read<SettingsService>();
    final tunnel = context.read<TunnelService>();
    final raw = settings.rawTunnels;
    if (raw.isNotEmpty) {
      final filtered = raw
          .map(TunnelConfig.fromJson)
          .where((t) => t.profileId == settings.selectedProfileId)
          .toList();
      tunnel.setTunnels(filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lan_outlined,
                  color: Color(0xFF00BFA5), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('TCP Tunnel',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(height: 1, color: const Color(0xFF1A2340)),
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          const HomeScreen(),
          const FileExplorerScreen(),
          const TerminalScreen(),
          DevicesScreen(onTabChange: (i) {
            setState(() => _tabIndex = i);
          }),
          const LogsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: Color(0xFF1A2340), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          backgroundColor: const Color(0xFF0D1120),
          selectedItemColor: const Color(0xFF00BFA5),
          unselectedItemColor: const Color(0xFF4A5568),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.alt_route_rounded,
                  color: _tabIndex == 0
                      ? const Color(0xFF00BFA5)
                      : const Color(0xFF4A5568)),
              label: 'Tunnels',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_open_outlined,
                  color: _tabIndex == 1
                      ? const Color(0xFF00BFA5)
                      : const Color(0xFF4A5568)),
              label: 'Files',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_rounded,
                  color: _tabIndex == 2
                      ? const Color(0xFF00BFA5)
                      : const Color(0xFF4A5568)),
              label: 'Terminal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.usb_rounded,
                  color: _tabIndex == 3
                      ? const Color(0xFF00BFA5)
                      : const Color(0xFF4A5568)),
              label: 'Devices',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined,
                  color: _tabIndex == 4
                      ? const Color(0xFF00BFA5)
                      : const Color(0xFF4A5568)),
              label: 'Logs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined,
                  color: _tabIndex == 5
                      ? const Color(0xFF00BFA5)
                      : const Color(0xFF4A5568)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
