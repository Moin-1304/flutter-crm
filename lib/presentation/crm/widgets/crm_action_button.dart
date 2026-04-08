import 'package:flutter/material.dart';

/// Standard action button used across listing screens (DCR, Deviation, Tour Plan, etc).
/// Enforces consistent height/padding/typography and avoids label truncation by scaling down.
class CrmActionButton extends StatelessWidget {
  const CrmActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isMobile,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isMobile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;
    final double height = isMobile ? 44 : 48;
    final double iconSize = isMobile ? 18 : 20;
    final double fontSize = isMobile ? 14 : 15;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isEnabled ? color : Colors.grey,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: iconSize),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
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

