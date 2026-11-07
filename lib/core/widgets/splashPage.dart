import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/main.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();

    // Navigate to MainScreen after splash duration
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF185B3A),
      body: Stack(
        children: [
          // Background subtle ambient circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Main Center Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon Container
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          color: Color(0xFF185B3A),
                          size: 46,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Dovan',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fresh Groceries Delivered Fast',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Loading Bar Indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading application...',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
