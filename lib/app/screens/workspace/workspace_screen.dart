import 'package:chifa/app/cubits/workspace_cubit.dart';
import 'package:chifa/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: BlocBuilder<WorkspaceCubit, WorkspaceState>(
        builder: (context, state) {
          if (state.tabs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.space_dashboard_outlined,
                      size: 40,
                      color: AppTheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Aucun onglet ouvert',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez un module depuis le menu latéral.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          final isMobile = MediaQuery.of(context).size.width < 800;

          return Column(
            children: [
              // ── Tab Bar (Hidden on Mobile) ────────────────────
              if (!isMobile)
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.divider, width: 1),
                    ),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.tabs.length,
                    itemBuilder: (context, index) {
                      final tab = state.tabs[index];
                      final isActive = index == state.activeTabIndex;

                      return GestureDetector(
                        onTap: () =>
                            context.read<WorkspaceCubit>().switchTab(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.bgLight
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: isActive
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              right: BorderSide(
                                color: AppTheme.divider.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${tab.title}${tab.isDirty ? ' •' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _CloseTabButton(
                                isActive: isActive,
                                onClose: () async {
                                  if (tab.isDirty) {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                          'Modifications non enregistrées',
                                        ),
                                        content: const Text(
                                          'Êtes-vous sûr de vouloir fermer cet onglet ? Vos modifications seront perdues.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Annuler'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              'Fermer',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                  }
                                  if (context.mounted) {
                                    context.read<WorkspaceCubit>().closeTab(
                                      tab.id,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ── Tab Content ───────────────────────────────────
              Expanded(
                child: IndexedStack(
                  index: state.activeTabIndex,
                  children: state.tabs
                      .map(
                        (tab) => KeyedSubtree(
                          key: ValueKey(tab.id),
                          child: tab.content,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


/// Animated close button that appears on hover / when active.
class _CloseTabButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onClose;

  const _CloseTabButton({required this.isActive, required this.onClose});

  @override
  State<_CloseTabButton> createState() => _CloseTabButtonState();
}

class _CloseTabButtonState extends State<_CloseTabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onClose,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.red.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 14,
            color: _hovered
                ? Colors.red
                : widget.isActive
                ? AppTheme.textSecondary
                : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
