import 'package:flutter/material.dart';
import '../utils/constants.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        height: 65,
        indicatorColor: AppColors.coralLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.coral),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.event_rounded, color: AppColors.coral),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_num_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.confirmation_num_rounded, color: AppColors.coral),
            label: 'My Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.coral),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
