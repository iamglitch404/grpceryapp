import 'package:flutter/material.dart';

/// Floating buttons on top of map (Back, Layer Switcher, Recenter, Steps)
class PositionBarFloating extends StatelessWidget {
  final VoidCallback onBack;
  final String mapLayer;
  final VoidCallback onToggleLayer;
  final VoidCallback onRecenter;
  final VoidCallback onToggleSteps;
  final int stepsCount;

  const PositionBarFloating({
    super.key,
    required this.onBack,
    required this.mapLayer,
    required this.onToggleLayer,
    required this.onRecenter,
    required this.onToggleSteps,
    required this.stepsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 14,
      right: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          _buildCircleBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
            tooltip: 'Back to Details',
          ),

          // Right Controls Stack
          Row(
            children: [
              // Turn-by-Turn Steps Toggle
              if (stepsCount > 0) ...[
                _buildCircleBtn(
                  icon: Icons.alt_route_rounded,
                  onTap: onToggleSteps,
                  tooltip: 'Show Steps ($stepsCount)',
                ),
                const SizedBox(width: 8),
              ],

              // Satellite / Standard Toggle
              _buildCircleBtn(
                icon: mapLayer == 'satellite' ? Icons.map_outlined : Icons.satellite_alt_rounded,
                onTap: onToggleLayer,
                tooltip: 'Toggle Satellite',
              ),
              const SizedBox(width: 8),

              // Recenter Route
              _buildCircleBtn(
                icon: Icons.my_location_rounded,
                onTap: onRecenter,
                tooltip: 'Fit Route',
                iconColor: const Color(0xFF16A34A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 20),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }
}

