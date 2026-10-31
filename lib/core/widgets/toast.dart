import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  static OverlayEntry? _currentEntry;

  /// Display a floating animated top toast
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
    String? title,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    // Provide subtle haptic feedback
    if (type == ToastType.error) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback to custom floating snackbar if overlay not ready
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: _getColor(type),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: duration,
        ),
      );
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        title: title,
        type: type,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry?.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.success, title: title);
  }

  static void error(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.error, title: title);
  }

  static void info(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.info, title: title);
  }

  static void warning(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.warning, title: title);
  }

  static Color _getColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return const Color(0xFF185B3A);
      case ToastType.error:
        return const Color(0xFFE11D48);
      case ToastType.warning:
        return const Color(0xFFD97706);
      case ToastType.info:
        return const Color(0xFF0284C7);
    }
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  Color _getPrimaryColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF185B3A);
      case ToastType.error:
        return const Color(0xFFE11D48);
      case ToastType.warning:
        return const Color(0xFFD97706);
      case ToastType.info:
        return const Color(0xFF0284C7);
    }
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFFF0FDF4);
      case ToastType.error:
        return const Color(0xFFFFF1F2);
      case ToastType.warning:
        return const Color(0xFFFFFBEB);
      case ToastType.info:
        return const Color(0xFFF0F9FF);
    }
  }

  Color _getBorderColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFFBBF7D0);
      case ToastType.error:
        return const Color(0xFFFECDD3);
      case ToastType.warning:
        return const Color(0xFFFDE68A);
      case ToastType.info:
        return const Color(0xFFBAE6FD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final primaryColor = _getPrimaryColor();

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getBorderColor(), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(),
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null) ...[
                            Text(
                              widget.title!,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            widget.message,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
