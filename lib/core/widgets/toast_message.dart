import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, warning, info }

class ToastMessage {
  static const Color tealGreen = Color(0xFF4db1b3);
  
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    bool useRootNavigator = false,
  }) {
    final OverlayEntry overlayEntry = _createOverlayEntry(
      context,
      message: message,
      type: type,
      icon: icon,
    );

    // Use root navigator's overlay if requested (for dialogs/modals)
    final OverlayState? overlayState = useRootNavigator
        ? Navigator.of(context, rootNavigator: true).overlay
        : Overlay.of(context);
    if (overlayState == null) return;

    overlayState.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  static OverlayEntry _createOverlayEntry(
    BuildContext context, {
    required String message,
    required ToastType type,
    IconData? icon,
  }) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    IconData defaultIcon;
    
    switch (type) {
      case ToastType.success:
        backgroundColor = const Color(0xFF2DBE64);
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.check_circle;
        break;
      case ToastType.error:
        backgroundColor = const Color(0xFFE74C3C);
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.error;
        break;
      case ToastType.warning:
        backgroundColor = const Color(0xFFFFA41C);
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.warning;
        break;
      case ToastType.info:
        backgroundColor = tealGreen;
        textColor = Colors.white;
        iconColor = Colors.white;
        defaultIcon = Icons.info;
        break;
    }

    return OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        iconColor: iconColor,
        icon: icon ?? defaultIcon,
        isTablet: isTablet,
        isMobile: isMobile,
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.icon,
    required this.isTablet,
    required this.isMobile,
  });

  final String message;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;
  final bool isTablet;
  final bool isMobile;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + (widget.isTablet ? 16 : 12),
      left: widget.isTablet ? MediaQuery.of(context).size.width * 0.1 : 16,
      right: widget.isTablet ? MediaQuery.of(context).size.width * 0.1 : 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isTablet ? 20 : 16,
                vertical: widget.isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(widget.isTablet ? 16 : 14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: widget.isTablet ? 32 : 28,
                    height: widget.isTablet ? 32 : 28,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: widget.isTablet ? 18 : 16,
                    ),
                  ),
                  SizedBox(width: widget.isTablet ? 14 : 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        fontSize: widget.isTablet ? 13 : 12,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

