import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/services/db/sync_manager.dart';
import 'package:flutter/material.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncProgress>(
      valueListenable: SyncManager().syncProgress,
      builder: (context, progress, child) {
        if (!progress.isSyncing && progress.error == null)
          return const SizedBox.shrink();

        final hasError = progress.error != null;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.sidebarSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? Colors.red.withValues(alpha: 0.5)
                  : AppTheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  hasError
                      ? const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 18,
                        )
                      : _RotatingSyncIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasError ? 'Sync Error' : 'Synchronizing...',
                          style: TextStyle(
                            color: hasError ? Colors.red[300] : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (progress.error != null)
                          Text(
                            progress.error!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (progress.currentTable != null)
                          Text(
                            'Table: ${progress.currentTable}',
                            style: TextStyle(
                              color: AppTheme.sidebarText,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (hasError)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 14,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        SyncManager().syncProgress.value = SyncProgress(
                          isSyncing: false,
                        );
                      },
                    ),
                ],
              ),
              if (!hasError) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryLight,
                    ),
                    minHeight: 3,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RotatingSyncIcon extends StatefulWidget {
  @override
  State<_RotatingSyncIcon> createState() => _RotatingSyncIconState();
}

class _RotatingSyncIconState extends State<_RotatingSyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.sync_rounded, color: AppTheme.primaryLight, size: 18),
    );
  }
}
