import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/services/db/models/print_template.dart';
import 'package:flutter/material.dart';

/// Expandable Floating Action Button Speed Dial for mobile medical record forms.
///
/// Replaces the fixed multi-row bottom bar on narrow/mobile screens so the form
/// fills the viewport while keeping print, template, date, preview, cancel,
/// and submit actions one tap away.
class RecordActionsSpeedDial extends StatefulWidget {
  final PrintTemplate selectedTemplate;
  final ValueChanged<PrintTemplate> onTemplateChanged;
  final bool includeDateInOrdonnance;
  final VoidCallback onToggleIncludeDate;
  final VoidCallback onCancel;
  final VoidCallback onBlankOrdonnance;
  final VoidCallback onPreview;
  final VoidCallback onPrint;
  final VoidCallback onSubmit;
  final bool isEditing;
  final bool isLoading;

  const RecordActionsSpeedDial({
    super.key,
    required this.selectedTemplate,
    required this.onTemplateChanged,
    required this.includeDateInOrdonnance,
    required this.onToggleIncludeDate,
    required this.onCancel,
    required this.onBlankOrdonnance,
    required this.onPreview,
    required this.onPrint,
    required this.onSubmit,
    required this.isEditing,
    required this.isLoading,
  });

  @override
  State<RecordActionsSpeedDial> createState() => _RecordActionsSpeedDialState();
}

class _RecordActionsSpeedDialState extends State<RecordActionsSpeedDial>
    with SingleTickerProviderStateMixin {
  static const int _itemCount = 7;

  bool _isOpen = false;
  late final AnimationController _controller;
  late final CurvedAnimation _backdropAnimation;
  late final List<CurvedAnimation> _opacityAnimations;
  late final List<CurvedAnimation> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _backdropAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _opacityAnimations = List.generate(_itemCount, (index) {
      final (start, end) = _itemInterval(index);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _scaleAnimations = List.generate(_itemCount, (index) {
      final (start, end) = _itemInterval(index);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });
  }

  /// Staggers items from bottom (closest to the main FAB) to top.
  static (double, double) _itemInterval(int index) {
    final reverseIndex = (_itemCount - 1) - index;
    final start = (reverseIndex * 0.06).clamp(0.0, 0.55);
    final end = (start + 0.45).clamp(0.0, 1.0);
    return (start, end);
  }

  @override
  void dispose() {
    for (final anim in _opacityAnimations) {
      anim.dispose();
    }
    for (final anim in _scaleAnimations) {
      anim.dispose();
    }
    _backdropAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_isOpen) {
      // Dismiss any open mobile keyboard before revealing the speed dial.
      FocusScope.of(context).unfocus();
      setState(() => _isOpen = true);
      _controller.forward();
    } else {
      _close();
    }
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
  }

  void _runAndClose(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final showOverlay = !_controller.isDismissed;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (showOverlay)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_isOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: Container(
                      color: Colors.white.withValues(
                        alpha: 0.84 * _backdropAnimation.value,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
            if (showOverlay)
              Positioned(
                right: 16,
                left: 16,
                top: 12,
                bottom: 82,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IgnorePointer(
                    ignoring: !_isOpen,
                    child: SingleChildScrollView(
                      reverse: true,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _buildMenuItems(),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                // Required because WorkspaceScreen keeps multiple tabs alive in IndexedStack.
                heroTag: null,
                onPressed: _toggle,
                backgroundColor:
                    _isOpen ? AppTheme.sidebarBackground : AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 6,
                tooltip: _isOpen ? 'Fermer le menu' : 'Actions',
                child: widget.isLoading && !_isOpen
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            RotationTransition(
                          turns: Tween<double>(begin: 0.75, end: 1.0)
                              .animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          ),
                        ),
                        child: _isOpen
                            ? const Icon(
                                Icons.close_rounded,
                                key: ValueKey('close'),
                              )
                            : const Icon(
                                Icons.apps_rounded,
                                key: ValueKey('menu'),
                              ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildMenuItems() {
    final dateEnabled = widget.includeDateInOrdonnance;
    final items = <Widget>[
      _buildActionRow(
        label: 'Cancel',
        icon: Icons.close_rounded,
        circleColor: Colors.red.shade500,
        onTap: () => _runAndClose(widget.onCancel),
      ),
      _buildActionRow(
        label: dateEnabled ? 'Date ON' : 'Date OFF',
        icon: dateEnabled
            ? Icons.calendar_today
            : Icons.calendar_today_outlined,
        circleColor:
            dateEnabled ? Colors.blue.shade700 : Colors.grey.shade400,
        pillColor: dateEnabled ? Colors.blue.shade700 : Colors.white,
        labelColor: dateEnabled ? Colors.white : Colors.grey.shade600,
        onTap: widget.onToggleIncludeDate,
      ),
      _buildTemplateRow(),
      _buildActionRow(
        label: 'Blank Ordonnance',
        icon: Icons.note_alt_outlined,
        circleColor: Colors.purple.shade600,
        onTap: () => _runAndClose(widget.onBlankOrdonnance),
      ),
      _buildActionRow(
        label: 'Preview',
        icon: Icons.visibility_rounded,
        circleColor: Colors.lightBlue.shade600,
        onTap: () => _runAndClose(widget.onPreview),
      ),
      _buildActionRow(
        label: 'Print',
        icon: Icons.print_rounded,
        circleColor: AppTheme.secondary,
        onTap: () => _runAndClose(widget.onPrint),
      ),
      _buildActionRow(
        label: widget.isEditing ? 'Save Changes' : 'Create Record',
        icon: Icons.check_rounded,
        circleColor: AppTheme.primary,
        pillColor: AppTheme.primary,
        labelColor: Colors.white,
        fontWeight: FontWeight.w700,
        isLoading: widget.isLoading,
        onTap: widget.isLoading ? null : () => _runAndClose(widget.onSubmit),
      ),
    ];

    return List.generate(
      items.length,
      (index) => FadeTransition(
        opacity: _opacityAnimations[index],
        child: ScaleTransition(
          scale: _scaleAnimations[index],
          alignment: Alignment.centerRight,
          child: items[index],
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required String label,
    required IconData icon,
    required Color circleColor,
    Color pillColor = Colors.white,
    Color? labelColor,
    FontWeight fontWeight = FontWeight.w600,
    bool isLoading = false,
    required VoidCallback? onTap,
  }) {
    final pill = Material(
      elevation: 3,
      color: pillColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: fontWeight,
              color: labelColor ?? AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );

    return _buildSpeedDialRow(
      pill: pill,
      circleColor: circleColor,
      icon: icon,
      isLoading: isLoading,
      onCircleTap: onTap,
    );
  }

  Widget _buildTemplateRow() {
    final nextTemplate = widget.selectedTemplate == PrintTemplate.chifa
        ? PrintTemplate.eph
        : PrintTemplate.chifa;

    final pill = Material(
      elevation: 3,
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTemplateOption(PrintTemplate.chifa),
            const SizedBox(width: 2),
            _buildTemplateOption(PrintTemplate.eph),
          ],
        ),
      ),
    );

    return _buildSpeedDialRow(
      pill: pill,
      circleColor: Colors.blue.shade700,
      icon: widget.selectedTemplate == PrintTemplate.chifa
          ? Icons.description_outlined
          : Icons.local_hospital_outlined,
      onCircleTap: () => widget.onTemplateChanged(nextTemplate),
    );
  }

  Widget _buildTemplateOption(PrintTemplate template) {
    final isSelected = widget.selectedTemplate == template;
    return Material(
      color: isSelected ? Colors.blue.shade700 : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => widget.onTemplateChanged(template),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            template.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedDialRow({
    required Widget pill,
    required Color circleColor,
    required IconData icon,
    bool isLoading = false,
    required VoidCallback? onCircleTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: pill),
          const SizedBox(width: 12),
          Material(
            elevation: 4,
            color: circleColor,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onCircleTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
