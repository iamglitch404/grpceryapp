import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliveryHeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const DeliveryHeaderStat({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFFD97706) : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class DeliveryRatingBar extends StatelessWidget {
  final String label;
  final double rating;
  final Color color;

  const DeliveryRatingBar({
    super.key,
    required this.label,
    required this.rating,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (rating / 5.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
            Text(rating.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

