import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Consistent, RTL-correct day/week/month range-navigation arrow button,
/// shared by every "day/week/month" task-range screen (manager dashboard,
/// manager reports, manager calendar, employee tasks tab).
///
/// Uses two SEMANTIC factory constructors — [next]/[previous] — instead of
/// a raw `icon` parameter, so the chevron glyph can never be mismatched
/// with the wrong direction handler by a future edit: [next] ALWAYS
/// renders a right-pointing rounded chevron and calls its handler to move
/// forward; [previous] ALWAYS renders a left-pointing one and moves
/// backward.
///
/// Under this app's forced RTL `Directionality` (see main.dart), a Row's
/// FIRST child renders on the visual RIGHT and its LAST child on the
/// visual LEFT. Placing [next] first and [previous] last in a Row (the
/// pattern used at every call site) therefore makes the RIGHT-hand arrow
/// advance forward and the LEFT-hand arrow go back — matching the
/// explicit design requirement: "السهم لليمين = اليوم التالي، لليسار =
/// اليوم السابق" (right arrow = next, left arrow = previous).
///
/// Each button also carries a [Tooltip] (long-press/hover reveal) with an
/// explicit Arabic label built from [periodLabel] (e.g. "اليوم" for day
/// mode, "الأسبوع" for week, "الشهر" for month), producing "اليوم التالي"
/// / "اليوم السابق" etc. — this avoids hardcoding "يوم" wording while the
/// screen is actually in week/month mode.
class DateNavArrowButton extends StatelessWidget {
  const DateNavArrowButton._({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  factory DateNavArrowButton.next({
    required VoidCallback onTap,
    required String periodLabel,
  }) {
    return DateNavArrowButton._(
      icon: Icons.chevron_right_rounded,
      tooltip: '$periodLabel التالي',
      onTap: onTap,
    );
  }

  factory DateNavArrowButton.previous({
    required VoidCallback onTap,
    required String periodLabel,
  }) {
    return DateNavArrowButton._(
      icon: Icons.chevron_left_rounded,
      tooltip: '$periodLabel السابق',
      onTap: onTap,
    );
  }

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.deepBlue.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            label: tooltip,
            button: true,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, color: AppColors.deepBlue, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
