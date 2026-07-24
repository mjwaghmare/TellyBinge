import 'package:flutter/material.dart';

class ActionCircleButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeIconColor;
  final Color inactiveIconColor;
  final Color activeBgColor;
  final Color inactiveBgColor;
  final double size;
  final double iconSize;

  const ActionCircleButton({
    super.key,
    required this.isActive,
    required this.onTap,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeIconColor,
    required this.inactiveIconColor,
    required this.activeBgColor,
    required this.inactiveBgColor,
    this.size = 36.0,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : inactiveBgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? activeIconColor : inactiveIconColor,
          size: iconSize,
        ),
      ),
    );
  }
}
