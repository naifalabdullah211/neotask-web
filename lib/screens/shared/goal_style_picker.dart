import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/goal_style_options.dart';

/// Bounded, ready-made color-swatch picker for a Goal — renders exactly
/// the 5 fixed RCJY brand colors from [goalColorNames] as tappable
/// circles. Deliberately NOT a free/custom color picker (no `ColorPicker`
/// widget, no hex input field) — per the explicit requirement to avoid
/// visual chaos if goals multiply. Shared verbatim between
/// create_goal_dialog.dart and edit_goal_dialog.dart.
class GoalColorPicker extends StatelessWidget {
  const GoalColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: goalColorNames.map((name) {
        final color = goalColorSwatches[name]!;
        final isSelected = name == selected;
        return GestureDetector(
          onTap: () => onChanged(name),
          child: Tooltip(
            message: goalColorLabelsAr[name] ?? name,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.textPrimary : Colors.white,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Bounded, ready-made icon-set picker for a Goal — renders exactly the
/// fixed icons from [goalIconNames] as tappable chips. Deliberately NOT a
/// free icon search. Shared verbatim between create_goal_dialog.dart and
/// edit_goal_dialog.dart.
class GoalIconPicker extends StatelessWidget {
  const GoalIconPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accentColor = AppColors.deepBlue,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: goalIconNames.map((name) {
        final icon = goalIconChoices[name]!;
        final isSelected = name == selected;
        return GestureDetector(
          onTap: () => onChanged(name),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.15)
                  : AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? accentColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? accentColor : AppColors.textSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
