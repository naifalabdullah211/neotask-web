import 'package:flutter/material.dart';

/// Fixed, bounded style options for a [Goal] — EXPLICITLY NOT a free
/// color picker / free icon search. Both the color and icon a manager may
/// choose for a goal come from these two small, fixed enumerations only,
/// per the explicit requirement: "لا تسمح بلون حر مخصص (custom picker)
/// لتفادي فوضى بصرية لو تعددت الأهداف".
///
/// COLOR: exactly the 5 RCJY brand colors specified, verbatim hex values:
///   navy #1B3A6B, mint #33D6A6, gold #E8B84B, purple #6B3FA0, teal #00A3C4.
/// This is a DELIBERATELY SEPARATE palette from `AppColors` in
/// app_theme.dart (which has its own `deepBlue`/`mintAccent`/`favoriteGold`
/// with slightly different hex values used elsewhere in the app) — do not
/// conflate the two; a goal's color must render as EXACTLY one of these 5
/// literal hex values, not a nearby existing brand constant.
///
/// USAGE SCOPE (per explicit requirement): a goal's color is used ONLY for
/// (a) the goal's progress bar and (b) the goal card/header's border.
/// Criteria remain neutral (gray/white) in ALL cases — never colored with
/// the parent goal's color — to keep a clear visual distinction between
/// goal-level and criterion-level UI.
const Map<String, Color> goalColorSwatches = {
  'navy': Color(0xFF1B3A6B),
  'mint': Color(0xFF33D6A6),
  'gold': Color(0xFFE8B84B),
  'purple': Color(0xFF6B3FA0),
  'teal': Color(0xFF00A3C4),
};

const Map<String, String> goalColorLabelsAr = {
  'navy': 'كحلي',
  'mint': 'نعناعي',
  'gold': 'ذهبي',
  'purple': 'بنفسجي',
  'teal': 'تركواز',
};

/// Ordered list (drives the picker's rendering order).
const List<String> goalColorNames = ['navy', 'mint', 'gold', 'purple', 'teal'];

/// Default color when a Goal predates this feature (no `colorName` stored
/// yet) — falls back to 'navy', the first/base RCJY brand color.
Color goalColorFromName(String? name) {
  return goalColorSwatches[name] ?? goalColorSwatches['navy']!;
}

/// Fixed set of goal icons the manager picks from at creation/edit time —
/// per the example given ("علم/هدف/نجمة") plus a few more of the same
/// bounded, ready-made-icon-set spirit. NOT a free icon search.
const Map<String, IconData> goalIconChoices = {
  'flag': Icons.flag,
  'target': Icons.track_changes,
  'star': Icons.star,
  'trophy': Icons.emoji_events,
  'rocket': Icons.rocket_launch,
  'bulb': Icons.lightbulb,
};

const Map<String, String> goalIconLabelsAr = {
  'flag': 'علم',
  'target': 'هدف',
  'star': 'نجمة',
  'trophy': 'كأس',
  'rocket': 'صاروخ',
  'bulb': 'فكرة',
};

const List<String> goalIconNames = [
  'flag',
  'target',
  'star',
  'trophy',
  'rocket',
  'bulb',
];

/// Default icon when a Goal predates this feature (no `iconName` stored
/// yet) — falls back to the previous hardcoded default, 'flag'.
IconData goalIconFromName(String? name) {
  return goalIconChoices[name] ?? goalIconChoices['flag']!;
}
