import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SeverityBadge extends StatelessWidget {
  final String severity;
  final bool compact;

  const SeverityBadge({super.key, required this.severity, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(context, severity);
    final label = AppTheme.severityLabel(severity);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(severity), size: compact ? 12 : 14, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String s) => switch (s.toUpperCase()) {
        'CRITICAL' => Icons.error_outline,
        'WARNING' => Icons.warning_amber_outlined,
        'INFO' => Icons.info_outline,
        _ => Icons.circle,
      };
}
