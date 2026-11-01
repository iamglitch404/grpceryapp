import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliveryRouteMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const DeliveryRouteMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: highlight ? const Color(0xFFD97706) : const Color(0xFF185B3A)),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: highlight ? const Color(0xFFD97706) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

