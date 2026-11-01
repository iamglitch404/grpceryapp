// Animated search bar widget for HomePage.
// Extracted from homePage.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/home/screens/filterPage.dart';

/// The search input box used in home page.
class HomeSearchBox extends ConsumerStatefulWidget {
  final bool isFloating;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearchOpen;
  final VoidCallback onTap;

  const HomeSearchBox({
    super.key,
    required this.isFloating,
    required this.controller,
    required this.focusNode,
    required this.isSearchOpen,
    required this.onTap,
  });

  @override
  ConsumerState<HomeSearchBox> createState() => _HomeSearchBoxState();
}

class _HomeSearchBoxState extends ConsumerState<HomeSearchBox> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              color: Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: widget.isFloating
                  ? TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      readOnly: !widget.isSearchOpen,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search for fruits, vegetables, meat...',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(
                      'Search for fruits, vegetables, meat...',
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (widget.isFloating)
              AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  if (widget.isSearchOpen && widget.controller.text.isNotEmpty) {
                    return GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.close, size: 18, color: Colors.grey),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FilterPage()),
                );
              },
              child: Icon(
                Icons.tune,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
