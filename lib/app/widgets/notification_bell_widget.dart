import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/app/widgets/notifications_dialog.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/local_sqlite_service.dart';

class NotificationBellWidget extends StatefulWidget {
  final Color? iconColor;

  const NotificationBellWidget({super.key, this.iconColor});

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget> {
  int _unreadCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    // Poll every 25 seconds
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _fetchUnreadCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      int count = 0;

      // 1. Try Remote MySQL
      if (DatabaseManager.isInitialized && DatabaseManager.instance.isConnected) {
        try {
          final res = await DatabaseManager.instance.query(
            'SELECT COUNT(*) as cnt FROM notifications WHERE is_read = 0 AND is_deleted = 0',
          );
          if (res.isNotEmpty) {
            count = int.tryParse(res.first['cnt']?.toString() ?? '0') ?? 0;
          }
        } catch (_) {}
      }

      // 2. Fallback / add local SQLite
      if (count == 0) {
        try {
          final res = await LocalSqliteService.instance.query(
            'SELECT COUNT(*) as cnt FROM notifications WHERE is_read = 0 AND is_deleted = 0',
          );
          if (res.isNotEmpty) {
            count = int.tryParse(res.first['cnt']?.toString() ?? '0') ?? 0;
          }
        } catch (_) {}
      }

      if (mounted && count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            _unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
            color: widget.iconColor ?? AppTheme.primaryDark,
            size: 24,
          ),
          tooltip: 'Notifications ($_unreadCount non lues)',
          onPressed: () {
            NotificationsDialog.show(
              context,
              onUpdated: _fetchUnreadCount,
            );
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

