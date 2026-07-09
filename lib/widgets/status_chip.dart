import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small colored chip used across manager/employee screens to display
/// a TaskStatus in Arabic with its associated color.
class StatusChip extends StatelessWidget {
  final String statusName;
  final double fontSize;

  const StatusChip({super.key, required this.statusName, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(statusName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        statusLabelAr(statusName),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// Small colored dot + label used in priority indicators.
class PriorityBadge extends StatelessWidget {
  final String priorityName; // low | medium | high

  const PriorityBadge({super.key, required this.priorityName});

  Color get _color {
    switch (priorityName) {
      case 'high':
        return AppColors.statusRejected;
      case 'medium':
        return AppColors.statusPending;
      default:
        return AppColors.statusApproved;
    }
  }

  String get _label {
    switch (priorityName) {
      case 'high':
        return 'أولوية عالية';
      case 'medium':
        return 'أولوية متوسطة';
      default:
        return 'أولوية منخفضة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
