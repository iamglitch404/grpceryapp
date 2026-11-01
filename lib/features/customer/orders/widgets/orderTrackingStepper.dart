import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderTrackingStepper extends StatelessWidget {
  final int activeStep;

  const OrderTrackingStepper({
    super.key,
    required this.activeStep,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'label': 'Placed', 'icon': Icons.receipt_long_rounded},
      {'label': 'Packed', 'icon': Icons.inventory_2_rounded},
      {'label': 'On the Way', 'icon': Icons.local_shipping_rounded},
      {'label': 'Delivered', 'icon': Icons.home_rounded},
    ];

    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final lineIdx = i ~/ 2;
              final done = activeStep > lineIdx;
              return Expanded(
                child: Container(
                  height: 3,
                  color: done ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                ),
              );
            }
            final idx = i ~/ 2;
            final reached = activeStep >= idx;
            final isCurrent = activeStep == idx;
            return Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: reached ? const Color(0xFF185B3A) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: const Color(0xFF86EFAC), width: 3)
                    : null,
              ),
              child: Icon(
                steps[idx]['icon'] as IconData,
                size: 16,
                color: reached ? Colors.white : const Color(0xFF94A3B8),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (idx) {
            final reached = activeStep >= idx;
            return Text(
              steps[idx]['label'] as String,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: reached ? FontWeight.bold : FontWeight.w500,
                color: reached ? const Color(0xFF185B3A) : const Color(0xFF94A3B8),
              ),
            );
          }),
        ),
      ],
    );
  }
}

