import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared pill/badge base — extracted so [StatusChip] and [PriorityBadge]
/// (previously two independent, nearly-identical `Container` blocks with
/// the same alpha-tinted-background + alpha-tinted-border pattern) render
/// from ONE implementation. Any future pill-style indicator (e.g. a new
/// badge type) should build on this rather than re-inventing the pattern
/// a third time.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.color,
    required this.label,
    this.icon,
    this.compact = false,
    this.borderAlpha = 0.4,
    this.fontSize,
  });

  final Color color;
  final String label;
  final IconData? icon;
  final bool compact;
  final double borderAlpha;

  /// Explicit override — falls back to the compact/non-compact default
  /// (11 / 12) when null, so existing call sites that don't care keep
  /// the standard scale.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm - 2 : AppSpacing.md - 2,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.badge.copyWith(
              color: color,
              fontSize: fontSize ?? (compact ? 11 : 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small colored chip used across manager/employee screens to display
/// a TaskStatus in Arabic with its associated color.
class StatusChip extends StatelessWidget {
  final String statusName;
  final double fontSize;

  const StatusChip({super.key, required this.statusName, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(statusName);
    // `fontSize` stays a configurable param for backward compatibility
    // with existing call sites that pass a custom size.
    return AppPill(
      color: color,
      label: statusLabelAr(statusName),
      fontSize: fontSize,
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
/// AND criteria. Now built on the shared [AppPill].
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
    return AppPill(
      color: color,
      icon: priorityIcon(priorityName),
      compact: compact,
      borderAlpha: 0.5,
      label: compact
          ? priorityLabelAr(priorityName)
          : 'أولوية ${priorityLabelAr(priorityName)}',
    );
  }
}
