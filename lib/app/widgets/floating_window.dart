import 'dart:async';

import 'package:chifa/app/theme/app_theme.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter_material
    show showDatePicker, showDateRangePicker, showTimePicker;
import 'package:flutter/scheduler.dart';

/// Represents a live floating window hosted inside [FloatingWindowsStack].
class FloatingWindowInstance {
  final String id;
  final ValueNotifier<String> titleNotifier;
  final Widget content;
  final double defaultWidth;
  final double defaultHeight;
  final ThemeData? theme;
  final IconData icon;

  Offset position;
  Size size;
  bool isMinimized;
  bool isMaximized;

  FloatingWindowInstance({
    required this.id,
    required this.titleNotifier,
    required this.content,
    required this.position,
    required this.size,
    required this.defaultWidth,
    required this.defaultHeight,
    this.isMinimized = false,
    this.isMaximized = false,
    this.theme,
    this.icon = Icons.open_in_new_rounded,
  });

  String get title => titleNotifier.value;
}

/// Manages non-blocking, draggable, minimizable, maximizable, and resizable
/// floating windows on desktop/tablet, falling back to full-screen routes on phones.
class FloatingWindowManager {
  FloatingWindowManager._();

  static final ValueNotifier<List<FloatingWindowInstance>> windows =
      ValueNotifier([]);
  static OverlayEntry? _overlayEntry;
  static OverlayState? _overlayState;
  static int _dialogCounter = 0;
  static final Map<String, void Function(Object?)> _resolvers = {};
  static final Map<String, Route<Object?>> _routes = {};

  /// Clears lingering entries if a previous root overlay was disposed (e.g. between tests).
  static void _pruneStaleOverlay(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (_overlayState != null &&
        (!_overlayState!.mounted || _overlayState != overlay)) {
      final pending = List<void Function(Object?)>.from(_resolvers.values);
      _resolvers.clear();
      for (final resolve in pending) {
        resolve(null);
      }
      windows.value = [];
      if (_overlayEntry != null &&
          _overlayEntry!.mounted &&
          _overlayState!.mounted) {
        _overlayEntry!.remove();
      }
      _overlayEntry = null;
      _overlayState = null;
    }
  }

  static void _ensureOverlay(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (_overlayEntry == null) {
      final entry = OverlayEntry(builder: (_) => const FloatingWindowsStack());
      _overlayEntry = entry;
      _overlayState = overlay;
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_overlayEntry == entry && !entry.mounted && overlay.mounted) {
            overlay.insert(entry);
          }
        });
      } else {
        overlay.insert(entry);
      }
    }
  }

  static void _setWindowsSafely(List<FloatingWindowInstance> next) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        windows.value = next;
      });
    } else {
      windows.value = next;
    }
  }

  static Offset _computeInitialPosition(Size screenSize, Size windowSize) {
    final cascade = (windows.value.length % 6) * 28.0;
    final centeredLeft =
        ((screenSize.width - windowSize.width) / 2) + cascade - 28.0;
    final centeredTop =
        ((screenSize.height - windowSize.height) / 2) + cascade - 28.0;
    final maxLeft =
        (screenSize.width - windowSize.width - 16.0).clamp(16.0, double.infinity);
    final maxTop =
        (screenSize.height - windowSize.height - 16.0).clamp(16.0, double.infinity);
    return Offset(
      centeredLeft.clamp(16.0, maxLeft),
      centeredTop.clamp(16.0, maxTop),
    );
  }

  /// Opens a persistent floating widget window (or brings an existing [id] to front).
  static void show(
    BuildContext context, {
    required String id,
    required String title,
    required Widget content,
    double defaultWidth = 780,
    double defaultHeight = 600,
    ThemeData? theme,
    IconData icon = Icons.assistant_outlined,
  }) {
    if (context.isMobile) {
      final route = MaterialPageRoute<void>(
        builder: (routeContext) => Theme(
          data: theme ?? Theme.of(routeContext),
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => close(id),
              ),
            ),
            body: content,
          ),
        ),
      );
      _routes[id] = route;
      Navigator.of(context).push(route).then((_) {
        _routes.remove(id);
      });
      return;
    }

    _pruneStaleOverlay(context);

    final existingIndex = windows.value.indexWhere((w) => w.id == id);
    if (existingIndex != -1) {
      final list = List<FloatingWindowInstance>.from(windows.value);
      final instance = list.removeAt(existingIndex);
      instance.isMinimized = false;
      list.add(instance);
      _setWindowsSafely(list);
      _ensureOverlay(context);
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final maxWidth = (screenSize.width - 40.0).clamp(360.0, double.infinity);
    final maxHeight = (screenSize.height - 40.0).clamp(250.0, double.infinity);
    final clampedSize = Size(
      defaultWidth.clamp(360.0, maxWidth),
      defaultHeight.clamp(250.0, maxHeight),
    );

    final newWindow = FloatingWindowInstance(
      id: id,
      titleNotifier: ValueNotifier<String>(title),
      content: content,
      position: _computeInitialPosition(screenSize, clampedSize),
      size: clampedSize,
      defaultWidth: defaultWidth,
      defaultHeight: defaultHeight,
      theme: theme ?? Theme.of(context),
      icon: icon,
    );

    final list = List<FloatingWindowInstance>.from(windows.value)..add(newWindow);
    _setWindowsSafely(list);
    _ensureOverlay(context);
  }

  /// Displays a dialog [builder] inside a draggable, minimizable, maximizable
  /// floating window and resolves with the popped result `T?`.
  static Future<T?> showDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    double defaultWidth = 780,
    double defaultHeight = 600,
    bool barrierDismissible = true,
    Color? barrierColor,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
    String? dialogId,
    ThemeData? theme,
    bool startMaximized = false,
    IconData icon = Icons.open_in_new_rounded,
  }) {
    final id = dialogId ?? 'floating_dialog_${_dialogCounter++}';
    final titleNotifier = ValueNotifier<String>(title ?? 'Fenêtre');

    if (context.isMobile) {
      final baseTheme = theme ?? Theme.of(context);
      final dialogTheme = baseTheme.copyWith(
        dialogTheme: baseTheme.dialogTheme.copyWith(
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      );
      final route = MaterialPageRoute<T>(
        builder: (routeContext) => Theme(
          data: dialogTheme,
          child: Scaffold(
            appBar: AppBar(
              title: ValueListenableBuilder<String>(
                valueListenable: titleNotifier,
                builder: (_, resolved, _) => Text(resolved),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(routeContext).pop(),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _FloatingDialogHost(
                    titleNotifier: titleNotifier,
                    extractTitle: title == null,
                    builder: builder,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      _routes[id] = route;
      return Navigator.of(context).push<T>(route).then((val) {
        _routes.remove(id);
        return val;
      });
    }

    _pruneStaleOverlay(context);

    final completer = Completer<T?>();
    _resolvers[id] = (Object? result) {
      if (!completer.isCompleted) {
        completer.complete(result is T ? result : null);
      }
    };

    final content = Navigator(
      onDidRemovePage: (_) {},
      pages: [
        MaterialPage<Object?>(
          key: ValueKey('floating_page_$id'),
          onPopInvoked: (didPop, result) {
            if (didPop) {
              _resolveAndClose(id, result);
            }
          },
          child: _FloatingDialogHost(
            titleNotifier: titleNotifier,
            extractTitle: title == null,
            builder: builder,
          ),
        ),
      ],
    );

    final screenSize = MediaQuery.of(context).size;
    final maxWidth = (screenSize.width - 40.0).clamp(360.0, double.infinity);
    final maxHeight = (screenSize.height - 40.0).clamp(250.0, double.infinity);
    final clampedSize = Size(
      defaultWidth.clamp(360.0, maxWidth),
      defaultHeight.clamp(250.0, maxHeight),
    );

    final instance = FloatingWindowInstance(
      id: id,
      titleNotifier: titleNotifier,
      content: content,
      position: _computeInitialPosition(screenSize, clampedSize),
      size: clampedSize,
      defaultWidth: defaultWidth,
      defaultHeight: defaultHeight,
      isMaximized: startMaximized,
      theme: theme ?? Theme.of(context),
      icon: icon,
    );

    final list = List<FloatingWindowInstance>.from(windows.value)..add(instance);
    _setWindowsSafely(list);
    _ensureOverlay(context);

    return completer.future;
  }

  /// Closes the floating window (or mobile route) with [id].
  static void close(String id) {
    if (_routes.containsKey(id)) {
      final route = _routes.remove(id);
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
      return;
    }

    final list = List<FloatingWindowInstance>.from(windows.value);
    list.removeWhere((w) => w.id == id);
    _setWindowsSafely(list);

    _resolvers.remove(id)?.call(null);

    if (list.isEmpty && _overlayEntry != null) {
      if (_overlayEntry!.mounted) {
        _overlayEntry!.remove();
      }
      _overlayEntry = null;
      _overlayState = null;
    }
  }

  /// Closes every active floating window and removes the root overlay entry.
  static void closeAll() {
    final routes = List<Route<Object?>>.from(_routes.values);
    _routes.clear();
    for (final route in routes) {
      if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }

    final resolvers = List<void Function(Object?)>.from(_resolvers.values);
    _resolvers.clear();
    for (final resolve in resolvers) {
      resolve(null);
    }

    windows.value = [];
    if (_overlayEntry != null) {
      if (_overlayEntry!.mounted) {
        _overlayEntry!.remove();
      }
      _overlayEntry = null;
      _overlayState = null;
    }
  }

  static void _resolveAndClose(String id, [Object? result]) {
    _resolvers.remove(id)?.call(result);
    close(id);
  }

  /// Resolves the window's pending future with [result] and closes it.
  static void complete(String id, [Object? result]) {
    if (_routes.containsKey(id)) {
      final route = _routes.remove(id);
      if (route != null && route.isActive) {
        route.navigator?.pop(result);
      }
      return;
    }
    _resolveAndClose(id, result);
  }

  /// Moves window [id] to the top of the z-order stack.
  static void bringToFront(String id) {
    final list = List<FloatingWindowInstance>.from(windows.value);
    final index = list.indexWhere((w) => w.id == id);
    if (index != -1 && index != list.length - 1) {
      final instance = list.removeAt(index);
      list.add(instance);
      _setWindowsSafely(list);
    }
  }

  /// Opens a [DatePickerDialog] in a floating window on desktop/tablet,
  /// or uses Material's native picker on mobile phones.
  static Future<DateTime?> showDatePicker({
    required BuildContext context,
    DateTime? initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? currentDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    SelectableDayPredicate? selectableDayPredicate,
    String? helpText,
    String? cancelText,
    String? confirmText,
    Locale? locale,
    DatePickerMode initialDatePickerMode = DatePickerMode.day,
    TransitionBuilder? builder,
  }) {
    if (context.isMobile) {
      return flutter_material.showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: currentDate,
        initialEntryMode: initialEntryMode,
        selectableDayPredicate: selectableDayPredicate,
        helpText: helpText,
        cancelText: cancelText,
        confirmText: confirmText,
        locale: locale,
        initialDatePickerMode: initialDatePickerMode,
        builder: builder,
      );
    }

    final dialogId =
        'floating_date_picker_${DateTime.now().microsecondsSinceEpoch}';
    final baseTheme = Theme.of(context);

    return showDialog<DateTime>(
      context: context,
      dialogId: dialogId,
      title: helpText ?? 'Sélectionner une date',
      defaultWidth: 420,
      defaultHeight: 628,
      startMaximized: false,
      theme: baseTheme,
      icon: Icons.calendar_today_rounded,
      builder: (dialogContext) {
        Widget picker = DatePickerDialog(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          currentDate: currentDate,
          initialEntryMode: initialEntryMode,
          selectableDayPredicate: selectableDayPredicate,
          helpText: helpText,
          cancelText: cancelText ?? 'Annuler',
          confirmText: confirmText ?? 'Valider',
          initialCalendarMode: initialDatePickerMode,
          insetPadding: EdgeInsets.zero,
        );
        if (locale != null) {
          picker = Localizations.override(
            context: dialogContext,
            locale: locale,
            child: picker,
          );
        }
        return builder != null ? builder(dialogContext, picker) : picker;
      },
    );
  }

  /// Opens a [DateRangePickerDialog] in a floating window on desktop/tablet,
  /// or uses Material's native picker on mobile phones.
  static Future<DateTimeRange?> showDateRangePicker({
    required BuildContext context,
    DateTimeRange? initialDateRange,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? currentDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    String? helpText,
    String? cancelText,
    String? confirmText,
    String? saveText,
    Locale? locale,
    TransitionBuilder? builder,
  }) {
    if (context.isMobile) {
      return flutter_material.showDateRangePicker(
        context: context,
        initialDateRange: initialDateRange,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: currentDate,
        initialEntryMode: initialEntryMode,
        helpText: helpText,
        cancelText: cancelText,
        confirmText: confirmText,
        saveText: saveText,
        locale: locale,
        builder: builder,
      );
    }

    final dialogId =
        'floating_date_range_picker_${DateTime.now().microsecondsSinceEpoch}';
    final baseTheme = Theme.of(context);

    return showDialog<DateTimeRange>(
      context: context,
      dialogId: dialogId,
      title: helpText ?? 'Sélectionner une période',
      defaultWidth: 560,
      defaultHeight: 620,
      startMaximized: false,
      theme: baseTheme,
      icon: Icons.date_range_rounded,
      builder: (dialogContext) {
        Widget picker = DateRangePickerDialog(
          initialDateRange: initialDateRange,
          firstDate: firstDate,
          lastDate: lastDate,
          currentDate: currentDate,
          initialEntryMode: initialEntryMode,
          helpText: helpText,
          cancelText: cancelText ?? 'Annuler',
          confirmText: confirmText ?? 'Valider',
          saveText: saveText ?? 'Valider',
        );
        if (locale != null) {
          picker = Localizations.override(
            context: dialogContext,
            locale: locale,
            child: picker,
          );
        }
        return builder != null ? builder(dialogContext, picker) : picker;
      },
    );
  }

  /// Opens a [TimePickerDialog] in a floating window on desktop/tablet,
  /// or uses Material's native picker on mobile phones.
  static Future<TimeOfDay?> showTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    String? helpText,
    String? cancelText,
    String? confirmText,
    TransitionBuilder? builder,
  }) {
    if (context.isMobile) {
      return flutter_material.showTimePicker(
        context: context,
        initialTime: initialTime,
        helpText: helpText,
        cancelText: cancelText,
        confirmText: confirmText,
        builder: builder,
      );
    }

    final dialogId =
        'floating_time_picker_${DateTime.now().microsecondsSinceEpoch}';
    final baseTheme = Theme.of(context);

    return showDialog<TimeOfDay>(
      context: context,
      dialogId: dialogId,
      title: helpText ?? 'Sélectionner une heure',
      defaultWidth: 420,
      defaultHeight: 580,
      startMaximized: false,
      theme: baseTheme,
      icon: Icons.access_time_rounded,
      builder: (dialogContext) {
        final picker = TimePickerDialog(
          initialTime: initialTime,
          cancelText: cancelText ?? 'Annuler',
          confirmText: confirmText ?? 'Valider',
          helpText: helpText,
        );
        return builder != null ? builder(dialogContext, picker) : picker;
      },
    );
  }
}

/// Hosts a dialog builder inside [LayoutBuilder], calling [builder] once and
/// optionally extracting its [AlertDialog.title] into [titleNotifier].
class _FloatingDialogHost extends StatelessWidget {
  final ValueNotifier<String> titleNotifier;
  final bool extractTitle;
  final WidgetBuilder builder;

  const _FloatingDialogHost({
    required this.titleNotifier,
    required this.extractTitle,
    required this.builder,
  });

  static String? _extractDialogTitle(Widget widget) {
    Widget current = widget;
    while (current is Theme) {
      current = current.child;
    }
    if (current is! AlertDialog || current.title == null) {
      return null;
    }
    return _extractTextFromWidget(current.title!);
  }

  static String? _extractTextFromWidget(Widget widget) {
    if (widget is Text && (widget.data?.trim().isNotEmpty ?? false)) {
      return widget.data!.trim();
    }
    if (widget is Row) {
      for (final child in widget.children) {
        final found = _extractTextFromWidget(child);
        if (found != null) return found;
      }
    }
    if (widget is Flexible) {
      return _extractTextFromWidget(widget.child);
    }
    if (widget is Padding && widget.child != null) {
      return _extractTextFromWidget(widget.child!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        final built = builder(layoutContext);
        if (extractTitle) {
          final extracted = _extractDialogTitle(built);
          if (extracted != null && extracted != titleNotifier.value) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              titleNotifier.value = extracted;
            });
          }
        }
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: built,
        );
      },
    );
  }
}

/// Renders all currently open floating windows in z-order inside the root overlay.
class FloatingWindowsStack extends StatelessWidget {
  const FloatingWindowsStack({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<FloatingWindowInstance>>(
      valueListenable: FloatingWindowManager.windows,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();

        return Stack(
          children: [
            for (var i = 0; i < list.length; i++)
              FloatingWindowWidget(
                key: ValueKey(list[i].id),
                instance: list[i],
                isFocused: i == list.length - 1,
              ),
          ],
        );
      },
    );
  }
}

/// Interactive window chrome supporting move, minimize, maximize/restore, resize,
/// and tap-to-focus while keeping child state alive during minimization.
class FloatingWindowWidget extends StatefulWidget {
  final FloatingWindowInstance instance;
  final bool isFocused;

  const FloatingWindowWidget({
    super.key,
    required this.instance,
    this.isFocused = false,
  });

  @override
  State<FloatingWindowWidget> createState() => _FloatingWindowWidgetState();
}

class _FloatingWindowWidgetState extends State<FloatingWindowWidget> {
  static const double _titleBarHeight = 48.0;
  static const double _minWidth = 360.0;
  static const double _minHeight = 250.0;
  static const double _minimizedWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    final instance = widget.instance;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final windowTheme = instance.theme ?? theme;

    final double openWidth = instance.isMaximized
        ? screenSize.width
        : instance.size.width.clamp(
            _minWidth,
            screenSize.width < _minWidth ? _minWidth : screenSize.width,
          );
    final double openHeight = instance.isMaximized
        ? screenSize.height
        : instance.size.height.clamp(
            _minHeight,
            screenSize.height < _minHeight ? _minHeight : screenSize.height,
          );
    final double openBodyHeight =
        (openHeight - _titleBarHeight).clamp(120.0, double.infinity);

    final double displayWidth = instance.isMinimized
        ? _minimizedWidth.clamp(240.0, screenSize.width)
        : openWidth;
    final double displayHeight =
        instance.isMinimized ? _titleBarHeight : openHeight;

    double left = instance.isMaximized ? 0.0 : instance.position.dx;
    double top = instance.isMaximized ? 0.0 : instance.position.dy;
    if (!instance.isMaximized) {
      final maxLeft = (screenSize.width - 100.0).clamp(0.0, double.infinity);
      final maxTop =
          (screenSize.height - _titleBarHeight).clamp(0.0, double.infinity);
      left = left.clamp(0.0, maxLeft);
      top = top.clamp(0.0, maxTop);
    }

    final surfaceColor = windowTheme.colorScheme.surface;
    final borderColor = widget.isFocused && !instance.isMaximized
        ? AppTheme.primary.withValues(alpha: 0.45)
        : AppTheme.divider;
    final borderWidth = widget.isFocused && !instance.isMaximized ? 1.5 : 1.0;

    return Positioned(
      left: left,
      top: top,
      width: displayWidth,
      height: displayHeight,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          FloatingWindowManager.bringToFront(instance.id);
        },
        child: Material(
          elevation: instance.isMinimized ? 10 : (widget.isFocused ? 22 : 12),
          color: surfaceColor,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(
            borderRadius:
                instance.isMaximized ? BorderRadius.zero : BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Body kept mounted via Offstage so minimizing preserves form/search state.
              Positioned(
                left: 0,
                top: _titleBarHeight,
                width: openWidth,
                height: openBodyHeight,
                child: Offstage(
                  offstage: instance.isMinimized,
                  child: TickerMode(
                    enabled: !instance.isMinimized,
                    child: MediaQuery(
                      data: mediaQuery.copyWith(
                        size: Size(openWidth, openBodyHeight),
                      ),
                      child: Container(
                        color: surfaceColor,
                        child: Theme(
                          data: windowTheme.copyWith(
                            dialogTheme: windowTheme.dialogTheme.copyWith(
                              backgroundColor: surfaceColor,
                              elevation: 0,
                              insetPadding: EdgeInsets.zero,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              constraints: const BoxConstraints.expand(),
                            ),
                          ),
                          child: instance.content,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!instance.isMinimized && !instance.isMaximized)
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: 22,
                  height: 22,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onPanUpdate: (details) {
                        setState(() {
                          final maxW = screenSize.width < _minWidth
                              ? _minWidth
                              : screenSize.width;
                          final maxH = screenSize.height < _minHeight
                              ? _minHeight
                              : screenSize.height;
                          instance.size = Size(
                            (instance.size.width + details.delta.dx)
                                .clamp(_minWidth, maxW),
                            (instance.size.height + details.delta.dy)
                                .clamp(_minHeight, maxH),
                          );
                        });
                      },
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.drag_handle_outlined,
                            size: 14,
                            color: AppTheme.primary.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _titleBarHeight,
                child: _buildTitleBar(instance, screenSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(FloatingWindowInstance instance, Size screenSize) {
    final titleBarColors = widget.isFocused
        ? [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.surfaceVariant,
          ]
        : [AppTheme.bgLight, AppTheme.surfaceVariant];

    return Container(
      height: _titleBarHeight,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: titleBarColors,
        ),
        border: Border(
          bottom: BorderSide(color: AppTheme.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: (_) {
                FloatingWindowManager.bringToFront(instance.id);
              },
              onPanUpdate: instance.isMaximized
                  ? null
                  : (details) {
                      setState(() {
                        final maxLeft =
                            (screenSize.width - 100.0).clamp(0.0, double.infinity);
                        final maxTop = (screenSize.height - _titleBarHeight)
                            .clamp(0.0, double.infinity);
                        instance.position = Offset(
                          (instance.position.dx + details.delta.dx)
                              .clamp(0.0, maxLeft),
                          (instance.position.dy + details.delta.dy)
                              .clamp(0.0, maxTop),
                        );
                      });
                    },
              onDoubleTap: () {
                setState(() {
                  if (instance.isMinimized) {
                    instance.isMinimized = false;
                  } else {
                    instance.isMaximized = !instance.isMaximized;
                  }
                });
              },
              child: SizedBox(
                height: _titleBarHeight,
                child: Row(
                  children: [
                    Icon(instance.icon, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: instance.titleNotifier,
                        builder: (_, titleText, _) => Text(
                          titleText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: instance.isMinimized ? 'Restaurer' : 'Réduire',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              instance.isMinimized ? Icons.expand_less : Icons.minimize,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            onPressed: () {
              setState(() {
                instance.isMinimized = !instance.isMinimized;
                if (instance.isMinimized) {
                  instance.isMaximized = false;
                }
              });
            },
          ),
          if (!instance.isMinimized)
            IconButton(
              tooltip: instance.isMaximized ? 'Restaurer' : 'Agrandir',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                instance.isMaximized
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  instance.isMaximized = !instance.isMaximized;
                });
              },
            ),
          IconButton(
            tooltip: 'Fermer',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
            onPressed: () {
              FloatingWindowManager.close(instance.id);
            },
          ),
        ],
      ),
    );
  }
}
