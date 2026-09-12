import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../doctors/doctor_screens.dart';
import '../history/history_screens.dart';
import '../profile/profile_screens.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex;
  final pages = const [
    HomeScreen(),
    SizedBox.shrink(),
    DoctorsScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  void select(int value) {
    if (value == 1) {
      Navigator.pushNamed(context, AppRoutes.preparation);
      return;
    }
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCEFEB),
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: _ScreenIcon(active: false),
            selectedIcon: _ScreenIcon(active: true),
            label: 'Screen',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services_rounded),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ScreenIcon extends StatelessWidget {
  const _ScreenIcon({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : AppColors.teal,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.center_focus_strong_rounded,
          color: Colors.white,
          size: 20,
        ),
      );
}
