import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';

import '../theme/app_theme.dart';

/// Shared visual chrome for the manager workspaces introduced after the
/// Work Plan redesign.  It intentionally owns presentation only; each
/// feature keeps its existing provider, routes and write actions.
class NeoWorkspaceMetric {
  const NeoWorkspaceMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class NeoWorkspaceMetricsBar extends StatelessWidget {
  const NeoWorkspaceMetricsBar({super.key, required this.items});

  final List<NeoWorkspaceMetric> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          textDirection: Directionality.of(context),
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _MetricView(data: items[index]),
              if (index != items.length - 1)
                const SizedBox(
                  height: 42,
                  child: VerticalDivider(
                    width: 28,
                    color: AppColors.divider,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricView extends StatelessWidget {
  const _MetricView({required this.data});

  final NeoWorkspaceMetric data;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                data.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NeoWorkspacePanel extends StatelessWidget {
  const NeoWorkspacePanel({
    super.key,
    required this.child,
    this.width,
    this.backgroundColor = Colors.white,
    this.borderStart = false,
    this.borderEnd = false,
  });

  final Widget child;
  final double? width;
  final Color backgroundColor;
  final bool borderStart;
  final bool borderEnd;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: BorderDirectional(
          start: borderStart
              ? const BorderSide(color: AppColors.divider)
              : BorderSide.none,
          end: borderEnd
              ? const BorderSide(color: AppColors.divider)
              : BorderSide.none,
        ),
      ),
      child: child,
    );
    return width == null ? content : SizedBox(width: width, child: content);
  }
}

class NeoWorkspaceSectionHeader extends StatelessWidget {
  const NeoWorkspaceSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class NeoWorkspaceEmptyState extends StatelessWidget {
  const NeoWorkspaceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.deepBlue.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: AppColors.deepBlue, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}
