import 'package:flutter/material.dart';

/// Reusable animated shimmer box for building skeleton placeholders.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFFE2E8F0),
      end: const Color(0xFFCBD5E1),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Home catalog skeleton loader showing banner, category circles, and product card placeholders.
class HomeCatalogSkeleton extends StatelessWidget {
  const HomeCatalogSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Banner Skeleton
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerBox(
            width: double.infinity,
            height: 150,
            borderRadius: 16,
          ),
        ),
        const SizedBox(height: 18),

        // Categories Header Skeleton
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 140, height: 16, borderRadius: 6),
              ShimmerBox(width: 50, height: 14, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Categories Circle Skeleton List
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, __) => const Column(
              children: [
                ShimmerBox(width: 62, height: 62, borderRadius: 31),
                SizedBox(height: 6),
                ShimmerBox(width: 48, height: 10, borderRadius: 4),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Section Title Skeleton
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 120, height: 16, borderRadius: 6),
              ShimmerBox(width: 50, height: 14, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Product Cards Horizontal Skeleton List
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 154,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: double.infinity, height: 98, borderRadius: 12),
                  SizedBox(height: 8),
                  ShimmerBox(width: 110, height: 12, borderRadius: 4),
                  SizedBox(height: 6),
                  ShimmerBox(width: 70, height: 10, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(width: 60, height: 14, borderRadius: 4),
                  Spacer(),
                  ShimmerBox(width: double.infinity, height: 28, borderRadius: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
