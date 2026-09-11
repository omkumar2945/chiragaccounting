import 'package:flutter/material.dart';

class ChiragAssociatesLogo extends StatelessWidget {
  const ChiragAssociatesLogo({
    super.key,
    this.horizontal = true,
    this.compact = false,
    this.onDark = false,
    this.showTagline = true,
  });

  final bool horizontal;
  final bool compact;
  final bool onDark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : const Color(0xFF0E4C92);
    final muted = onDark ? Colors.white70 : const Color(0xFF4A6178);
    final iconSize = compact ? 28.0 : 36.0;

    final mark = Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        'CA',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 11 : 14,
          letterSpacing: 0.5,
        ),
      ),
    );

    final textBlock = Column(
      crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          'Chirag Associates',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 12 : 15,
          ),
        ),
        if (showTagline)
          Text(
            'Accounting and Compliance',
            style: TextStyle(
              color: muted,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 8),
          textBlock,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 6),
        textBlock,
      ],
    );
  }
}
