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

/// Distinct, high-contrast colors for the 3 priority levels — deliberately
/// DIFFERENT from the TaskStatus palette above (statusRejected/statusPending/
/// statusApproved) so priority and status never visually collide when shown
/// side-by-side on the same card. Chosen per explicit request: "عاليه متوسطة
/// منخفضه حط لها علامات و خليها بالوان احسن" (give priority levels clear
/// markers/icons and better/more distinct colors).
Color priorityColor(String priorityName) {
  switch (priorityName) {
    case 'high':
      return const Color(0xFFDC2626); // strong red
    case 'medium':
      return const Color(0xFFF59E0B); // amber/orange
    default:
      return const Color(0xFF16A34A); // strong green
  }
}

IconData priorityIcon(String priorityName) {
  switch (priorityName) {
    case 'high':
      return Icons.keyboard_double_arrow_up;
    case 'medium':
      return Icons.drag_handle;
    default:
      return Icons.keyboard_double_arrow_down;
  }
}

String priorityLabelAr(String priorityName) {
  switch (priorityName) {
    case 'high':
      return 'عالية';
    case 'medium':
      return 'متوسطة';
    default:
      return 'منخفضة';
  }
}

/// Colored pill with a directional arrow icon (▲ high / ▬ medium / ▼ low)
/// used wherever [TaskPriority]/priority-level is displayed, for both tasks
/// AND criteria.
class PriorityBadge extends StatelessWidget {
  final String priorityName; // low | medium | high
  final bool compact;

  const PriorityBadge({
    super.key,
    required this.priorityName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priorityName);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priorityIcon(priorityName), size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            compact ? priorityLabelAr(priorityName) : 'أولوية ${priorityLabelAr(priorityName)}',
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
