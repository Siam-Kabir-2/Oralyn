import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../doctors/doctor_screens.dart';
import '../history/history_screens.dart';
import '../profile/profile_screens.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialIndex = 0,
    this.connectionUnavailable = false,
    this.connectionPending = false,
    this.onRetryConnection,
    this.detailRouteFactory,
  });
  final int initialIndex;
  final bool connectionUnavailable;
  final bool connectionPending;
  final VoidCallback? onRetryConnection;
  final RouteFactory? detailRouteFactory;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex.clamp(0, 3);
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _tabNavigators = List<Widget?>.filled(4, null);
  static const pages = [
    HomeScreen(),
    HistoryScreen(),
    DoctorsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabNavigators[index] = _tabNavigator(index);
  }

  void select(int value) {
    if (index == value) {
      _navigatorKeys[value].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        index = value;
        _tabNavigators[value] ??= _tabNavigator(value);
      });
    }
  }

  Widget _tabNavigator(int tabIndex) => Navigator(
        key: _navigatorKeys[tabIndex],
        onGenerateRoute: (settings) =>
            settings.name == Navigator.defaultRouteName
                ? MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => pages[tabIndex],
                  )
                : widget.detailRouteFactory?.call(settings) ??
                    AppRoutes.onGenerateRoute(settings),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      body: Column(children: [
        if (widget.connectionUnavailable)
          Material(
            color: AppColors.warningSoft,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  widget.connectionPending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_off_outlined,
                          color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.connectionPending
                          ? 'Connecting to the server. You can browse the app now.'
                          : 'Server unavailable. Browse the app, then reconnect for private records and screening.',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retry connection',
                    onPressed: widget.connectionPending
                        ? null
                        : widget.onRetryConnection,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _navigatorKeys[index]
                          .currentState
                          ?.pushNamed(AppRoutes.apiSettings);
                      widget.onRetryConnection?.call();
                    },
                    child: const Text('Set up'),
                  ),
                ]),
              ),
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: List.generate(
                4, (tabIndex) => _tabNavigators[tabIndex] ?? const SizedBox()),
          ),
        ),
      ]),
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
                  onTap: () => _navigatorKeys[index]
                      .currentState
                      ?.pushNamed(AppRoutes.preparation),
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
