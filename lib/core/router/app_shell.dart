import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/meetups/meetups_controller.dart';
import '../../features/notifications/notifications_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

const _homeBranchIndex = 0;
const _groupsBranchIndex = 1;
const _notificationsBranchIndex = 2;
const _profileBranchIndex = 3;

/// Bottom-nav scaffold for the 4 tab roots (Home/Groups/Notifications/
/// Profile). Each tab keeps its own navigation stack via
/// [StatefulShellRoute.indexedStack] - full-screen flows (Create Meetup,
/// Meetup Detail, Live Meetup, Going Home) are pushed on the *root*
/// navigator instead, so they render above this bar, matching the reference
/// screenshots.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.groups_rounded, label: 'Groups'),
    (icon: Icons.notifications_rounded, label: 'Notif'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Every tab screen lives inside an IndexedStack branch, so it's built
    // once and never re-mounted when switching tabs back to it - refetch
    // here instead, every time a tab becomes the active branch.
    final oldIndex = oldWidget.navigationShell.currentIndex;
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex == oldIndex) return;

    switch (newIndex) {
      case _homeBranchIndex:
        context.read<MeetupsController>().loadHome();
      case _groupsBranchIndex:
        context.read<MeetupsController>().loadGroups();
        context.read<MeetupsController>().loadInvites();
      case _notificationsBranchIndex:
        context.read<NotificationsController>().load();
      case _profileBranchIndex:
        context.read<AuthController>().refreshUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bgBase,
          border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 0.6)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: i == navigationShell.currentIndex,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.microSm.copyWith(color: color)),
        ],
      ),
    );
  }
}
