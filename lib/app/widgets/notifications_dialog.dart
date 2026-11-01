import 'package:flutter/material.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/local_sqlite_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chifa/services/activation/activation_service.dart';

class NotificationsDialog extends StatefulWidget {
  final VoidCallback? onNotificationsUpdated;

  const NotificationsDialog({super.key, this.onNotificationsUpdated});

  static Future<void> show(BuildContext context, {VoidCallback? onUpdated}) {
    return showDialog(
      context: context,
      builder: (ctx) => NotificationsDialog(onNotificationsUpdated: onUpdated),
    );
  }

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> rows = [];

      // 1. Try remote/primary database
      if (DatabaseManager.isInitialized && DatabaseManager.instance.isConnected) {
        try {
          rows = await DatabaseManager.instance.query('''
            SELECT n.*, 
                   CONCAT(p.first_name, ' ', p.last_name) as patient_name,
                   p.phone as patient_phone,
                   u.file_path, u.original_name, u.category as doc_category, u.notes as doc_notes
            FROM notifications n
            LEFT JOIN patients p ON n.patient_id = p.patient_id
            LEFT JOIN patient_portal_uploads u ON n.reference_id = u.id AND n.type = 'patient_upload'
            WHERE n.is_deleted = 0
            ORDER BY n.created_at DESC
            LIMIT 50
          ''');
        } catch (_) {}
      }

      // 2. Fallback to local SQLite if remote is offline or empty
      if (rows.isEmpty) {
        try {
          rows = await LocalSqliteService.instance.query('''
            SELECT n.*, 
                   (p.first_name || ' ' || p.last_name) as patient_name,
                   p.phone as patient_phone,
                   u.file_path, u.original_name, u.category as doc_category, u.notes as doc_notes
            FROM notifications n
            LEFT JOIN patients p ON n.patient_id = p.patient_id
            LEFT JOIN patient_portal_uploads u ON n.reference_id = u.id AND n.type = 'patient_upload'
            WHERE n.is_deleted = 0
            ORDER BY n.created_at DESC
            LIMIT 50
          ''');
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _notifications = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      if (DatabaseManager.isInitialized && DatabaseManager.instance.isConnected) {
        await DatabaseManager.instance.execute(
          'UPDATE notifications SET is_read = 1, needs_sync = 1 WHERE id = ?',
          [id],
        );
      }
      await LocalSqliteService.instance.execute(
        'UPDATE notifications SET is_read = 1, needs_sync = 1 WHERE id = ?',
        [id],
      );

      _loadNotifications();
      widget.onNotificationsUpdated?.call();
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      if (DatabaseManager.isInitialized && DatabaseManager.instance.isConnected) {
        await DatabaseManager.instance.execute(
          'UPDATE notifications SET is_read = 1, needs_sync = 1 WHERE is_read = 0',
        );
      }
      await LocalSqliteService.instance.execute(
        'UPDATE notifications SET is_read = 1, needs_sync = 1 WHERE is_read = 0',
      );

      _loadNotifications();
      widget.onNotificationsUpdated?.call();
    } catch (_) {}
  }

  void _openDocument(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final urlString = '${ActivationService.backendBaseUrl}/api/portal/document/$filePath';
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le document : $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth - 32 : 580,
          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.85 : 680,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_active_rounded,
                        color: AppTheme.primary, size: isMobile ? 18 : 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMobile ? 'Notifications' : 'Notifications & Résultats',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_notifications.any(
                      (n) => n['is_read'] == 0 || n['is_read'] == false))
                    isMobile
                        ? IconButton(
                            icon: const Icon(Icons.done_all, size: 20),
                            tooltip: 'Tout marquer comme lu',
                            onPressed: _markAllAsRead,
                          )
                        : TextButton(
                            onPressed: _markAllAsRead,
                            child: const Text('Tout marquer comme lu',
                                style: TextStyle(fontSize: 12)),
                          ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Erreur : $_error', style: const TextStyle(color: Colors.red)))
                        : _notifications.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text('Aucune notification', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _notifications.length,
                                itemBuilder: (context, index) {
                                  final notif = _notifications[index];
                                  final isUnread = notif['is_read'] == 0 || notif['is_read'] == false;
                                  final patientName = notif['patient_name']?.toString() ?? 'Patient #${notif['patient_id']}';
                                  final originalName = notif['original_name']?.toString();
                                  final filePath = notif['file_path']?.toString();
                                  final docNotes = notif['doc_notes']?.toString();

                                  DateTime? createdAt;
                                  try {
                                    createdAt = DateTime.parse(notif['created_at'].toString());
                                  } catch (_) {}

                                  final formattedDate = createdAt != null
                                      ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                                      : notif['created_at']?.toString() ?? '';

                                  return Card(
                                    elevation: isUnread ? 2 : 0,
                                    color: isUnread ? Colors.teal.shade50.withValues(alpha: 0.5) : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isUnread ? AppTheme.primary.withValues(alpha: 0.3) : Colors.grey.shade200,
                                      ),
                                    ),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: isUnread ? AppTheme.primary : Colors.grey.shade300,
                                                child: Icon(
                                                  notif['type'] == 'patient_upload'
                                                      ? Icons.upload_file_rounded
                                                      : Icons.event_available_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            notif['title']?.toString() ?? 'Notification',
                                                            style: TextStyle(
                                                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          formattedDate,
                                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Patient : $patientName',
                                                      style: TextStyle(
                                                        color: AppTheme.primaryDark,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      notif['message']?.toString() ?? '',
                                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                                    ),
                                                    if (docNotes != null && docNotes.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Note du patient : "$docNotes"',
                                                        style: TextStyle(color: Colors.indigo.shade700, fontStyle: FontStyle.italic, fontSize: 12),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (filePath != null && filePath.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                if (isUnread && notif['id'] != null)
                                                  TextButton(
                                                    onPressed: () => _markAsRead(int.parse(notif['id'].toString())),
                                                    child: const Text('Marquer comme lu', style: TextStyle(fontSize: 12)),
                                                  ),
                                                const SizedBox(width: 8),
                                                FilledButton.icon(
                                                  onPressed: () {
                                                    if (notif['id'] != null) {
                                                      _markAsRead(int.parse(notif['id'].toString()));
                                                    }
                                                    _openDocument(filePath);
                                                  },
                                                  icon: const Icon(Icons.visibility_rounded, size: 16),
                                                  label: Text(originalName != null ? 'Voir $originalName' : 'Voir le document'),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: AppTheme.primary,
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

