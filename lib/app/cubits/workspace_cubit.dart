import "package:equatable/equatable.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

/// Represents a single tab in the workspace
class WorkspaceTab extends Equatable {
  final String id;
  final String title;
  final Widget content;
  final bool isDirty;

  const WorkspaceTab({
    required this.id,
    required this.title,
    required this.content,
    this.isDirty = false,
  });

  WorkspaceTab copyWith({
    String? id,
    String? title,
    Widget? content,
    bool? isDirty,
  }) {
    return WorkspaceTab(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [id, title, content, isDirty];
}

/// State holding the open tabs and the currently active one
class WorkspaceState extends Equatable {
  final List<WorkspaceTab> tabs;
  final int activeTabIndex;

  const WorkspaceState({this.tabs = const [], this.activeTabIndex = 0});

  WorkspaceState copyWith({List<WorkspaceTab>? tabs, int? activeTabIndex}) {
    return WorkspaceState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
    );
  }

  @override
  List<Object?> get props => [tabs, activeTabIndex];
}

/// Cubit to manage the workspace tabs
class WorkspaceCubit extends Cubit<WorkspaceState> {
  WorkspaceCubit() : super(const WorkspaceState());

  void openTab(WorkspaceTab tab) {
    final tabs = List<WorkspaceTab>.from(state.tabs);

    // Check if a tab with this ID already exists
    final existingIndex = tabs.indexWhere((t) => t.id == tab.id);
    if (existingIndex != -1) {
      emit(state.copyWith(activeTabIndex: existingIndex));
      return;
    }

    tabs.add(tab);
    emit(state.copyWith(tabs: tabs, activeTabIndex: tabs.length - 1));
  }

  void closeTab(String id) {
    final tabs = List<WorkspaceTab>.from(state.tabs);
    final indexToRemove = tabs.indexWhere((t) => t.id == id);

    if (indexToRemove == -1) return;

    tabs.removeAt(indexToRemove);

    // Adjust the active tab index if necessary
    int newActiveIndex = state.activeTabIndex;
    if (tabs.isEmpty) {
      newActiveIndex = 0;
    } else if (indexToRemove <= newActiveIndex && newActiveIndex > 0) {
      newActiveIndex--;
    }

    emit(state.copyWith(tabs: tabs, activeTabIndex: newActiveIndex));
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      emit(state.copyWith(activeTabIndex: index));
    }
  }

  void setTabDirty(String id, bool isDirty) {
    final tabs = List<WorkspaceTab>.from(state.tabs);
    final index = tabs.indexWhere((t) => t.id == id);
    if (index != -1 && tabs[index].isDirty != isDirty) {
      tabs[index] = tabs[index].copyWith(isDirty: isDirty);
      emit(state.copyWith(tabs: tabs));
    }
  }
}
