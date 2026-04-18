import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/connectivity_service.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/planner/presentation/planner_controller.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/todo/presentation/todo_screen.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _currentIndex = 0;
  StreamSubscription<bool>? _connectivitySubscription;

  final List<Widget> _pages = const [
    DashboardScreen(),
    AssistantScreen(),
    TodoScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(plannerControllerProvider.notifier).syncLocalAlarms();
      ref.read(plannerControllerProvider.notifier).syncOfflineTasks();
      _connectivitySubscription =
          ref.read(connectivityServiceProvider).onlineChanges.listen((isOnline) {
        if (!isOnline || !mounted) {
          return;
        }

        ref.read(plannerControllerProvider.notifier).syncOfflineTasks();
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'To-Do',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
