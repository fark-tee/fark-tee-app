import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/meetups/meetups_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

const _homeBranchIndex = 0;
const _groupsBranchIndex = 1;
const _profileBranchIndex = 2;

/// Bottom-nav scaffold for the 3 tab roots (Home/Groups/Profile). Each tab
/// keeps its own navigation stack via [StatefulShellRoute.indexedStack] -
/// full-screen flows (Create Meetup, Meetup Detail, Live Meetup, Going Home)
/// are pushed on the *root* navigator instead, so they render above this
/// bar, matching the reference screenshots.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = [
    (image: 'assets/images/nav/home.png', label: 'หน้าหลัก'),
    (image: 'assets/images/nav/meetups.png', label: 'ตี้'),
    (image: 'assets/images/nav/profile.png', label: 'โปรไฟล์'),
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
                      image: _tabs[i].image,
                      label: _tabs[i].label,
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

/// One bottom-bar tab. Every tab renders at the same icon size and the same
/// label style/color regardless of which one is active - the mockup doesn't
/// dim or tint the unselected tabs, so there's no selected-vs-unselected
/// styling here at all.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.image,
    required this.label,
    required this.onTap,
  });

  final String image;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(image, height: 28, fit: BoxFit.contain),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.microSm.copyWith(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
