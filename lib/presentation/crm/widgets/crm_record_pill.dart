import 'package:flutter/material.dart';

/// Standard record-count pill used next to primary actions on list screens.
/// Keeps height/typography aligned with [CrmActionButton].
class CrmRecordPill extends StatelessWidget {
  const CrmRecordPill({
    super.key,
    required this.text,
    required this.color,
    required this.isMobile,
  });

  final String text;
  final Color color;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final double height = isMobile ? 44 : 48;
    final double iconSize = isMobile ? 16 : 18;
    final double fontSize = isMobile ? 13 : 14;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.22),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_list_bulleted_outlined,
                color: color,
                size: iconSize,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

