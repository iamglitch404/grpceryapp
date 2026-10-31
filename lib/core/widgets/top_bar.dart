import 'package:flutter/material.dart';

/// Reusable application top bar shell displaying brand identity and injectable action widgets.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? customActions;
  final double horizontalPadding;
  final double verticalPadding;
  final Widget? leading;
  final Color? backgroundColor;

  const TopBar({
    super.key,
    this.customActions,
    this.horizontalPadding = 20.0,
    this.verticalPadding = 0.0,
    this.leading,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Brand Name Section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              const Text(
                'Dovan',
                style: TextStyle(
                  color: Color(0xFF185B3A), // Dark Green Theme Color
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.eco, color: Color(0xFF39A968), size: 20),
            ],
          ),
          // Actions Section
          if (customActions != null && customActions!.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: customActions!,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef DovanTopBar = TopBar;
