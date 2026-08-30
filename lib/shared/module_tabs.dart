import 'package:flutter/material.dart';

/// A screen with a TabBar and a list of tab bodies. Used to merge related
/// features (e.g. Pomodoro + Time Tracking) into a single module.
///
/// Uses a [DefaultTabController] and keeps tab state alive via [IndexedStack].
class ModuleTabHost extends StatelessWidget {
  const ModuleTabHost({
    super.key,
    required this.title,
    required this.tabs,
    this.actions,
    this.showTitle = true,
  });

  final String title;
  final List<({String label, IconData icon, Widget body})> tabs;
  final List<Widget>? actions;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: showTitle ? kToolbarHeight : 0,
          title: showTitle ? Text(title) : null,
          actions: actions,
          bottom: TabBar(
            isScrollable: tabs.length > 4,
            tabs: [
              for (final t in tabs) Tab(icon: Icon(t.icon), text: t.label),
            ],
          ),
        ),
        body: TabBarView(children: [for (final t in tabs) t.body]),
      ),
    );
  }
}
