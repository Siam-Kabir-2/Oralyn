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
  late int index = widget.initialIndex.clamp(0, 3);
  final pages = const [
    HomeScreen(),
    HistoryScreen(),
    DoctorsScreen(),
    ProfileScreen(),
  ];

  void select(int value) {
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: .1),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        label: 'Home',
                        selected: index == 0,
                        onTap: () => select(0),
                      ),
                      _NavItem(
                        icon: Icons.history_outlined,
                        selectedIcon: Icons.history_rounded,
                        label: 'History',
                        selected: index == 1,
                        onTap: () => select(1),
                      ),
                      _NavItem(
                        icon: Icons.medical_services_outlined,
                        selectedIcon: Icons.medical_services_rounded,
                        label: 'Care',
                        selected: index == 2,
                        onTap: () => select(2),
                      ),
                      _NavItem(
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profile',
                        selected: index == 3,
                        onTap: () => select(3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.coral,
                shape: const CircleBorder(),
                elevation: 5,
                shadowColor: AppColors.coral,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.preparation),
                  child: const SizedBox(
                    width: 62,
                    height: 62,
                    child:
                        Icon(Icons.add_rounded, color: Colors.white, size: 29),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 52,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF6F6F3) : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon,
                    size: 20,
                    color: selected ? AppColors.ink : AppColors.secondaryText),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.ink : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
