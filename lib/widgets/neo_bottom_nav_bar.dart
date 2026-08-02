import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import '../theme/app_theme.dart';

/// Declarative description of one bottom-nav destination. Mirrors the
/// subset of `NavigationDestination`'s API actually used across the app's
/// three home shells (manager/employee/designer): an outlined icon for the
/// unselected state, a filled icon for the selected state, a label, and an
/// optional unread/pending badge count (0 = no badge shown).
class NeoNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;

  const NeoNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// Custom bottom navigation bar — replaces the stock Material `NavigationBar`
/// app-wide with a bolder, more "alive" design per explicit request:
///
///   1. STRONG active-tab contrast: a solid [AppColors.mintAccent] pill
///      fills the space behind BOTH the icon AND the label (stock M3 only
///      highlights the icon with a pale indicator) — icon+text turn white
///      on top of it.
///   2. Inactive icons use [AppColors.deepBlue] (a dark, saturated brand
///      tone) instead of the previous washed-out grey
///      ([AppColors.textSecondary]) so they read clearly without visually
///      competing with the mint-filled active tab.
///   3. Tap "bounce": each tap triggers a scale animation
///      1.0 → 1.10 → 1.0 over ~230ms using an overshoot curve
///      (`Curves.easeOutBack` on the return leg — the closest Flutter
///      built-in equivalent to a CSS cubic-bezier-with-overshoot), giving
///      immediate tactile feedback without slowing navigation down.
///   4. Slightly larger icon↔label gap (8px vs the ~4px default) for a
///      calmer, less cramped look.
///
/// Kept deliberately restrained (no extra decorative elements, no colors
/// outside the existing RCJY palette) per the "professional medical
/// workplace" constraint — the boldness is expressed ONLY through contrast
/// and motion, not new visual clutter.
class NeoBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NeoNavItem> items;

  const NeoBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: AppElevation.high,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _NeoNavItemTile(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onDestinationSelected(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NeoNavItemTile extends StatefulWidget {
  final NeoNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NeoNavItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NeoNavItemTile> createState() => _NeoNavItemTileState();
}

class _NeoNavItemTileState extends State<_NeoNavItemTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Total duration 230ms, inside the requested 200-250ms window.
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
    );
    // 1.0 -> 1.10 (quick ease-out) -> 1.0 (ease-out-BACK, i.e. a
    // cubic-bezier curve with a small overshoot on the settle) — this is
    // the "قفزة خفيفة" (light bounce/jump) requested, self-contained in a
    // single forward-only animation triggered per tap.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.10,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.10,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Restart the bounce every tap, even on the already-selected tab, so
    // the tactile feedback is always felt immediately.
    _bounceController.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final iconColor = selected ? Colors.white : AppColors.deepBlue;
    final labelColor = selected ? Colors.white : AppColors.deepBlue;

    Widget icon = Icon(
      selected ? widget.item.selectedIcon : widget.item.icon,
      color: iconColor,
      size: 23,
      // A touch heavier stroke presence for the unselected outline icons
      // (Material "_outlined" glyphs render thinner than filled ones by
      // design) — a subtle white halo-free fill weight boost via
      // fontWeight has no effect on IconData glyphs, so the deliberate
      // size bump (23 vs the previous 20-24 mixed values) plus the darker
      // [AppColors.deepBlue] tone is what carries the "bolder" requirement
      // here, without swapping icon families app-wide.
    );

    if (widget.item.badgeCount > 0) {
      icon = Badge(
        label: Text('${widget.item.badgeCount}'),
        backgroundColor: AppColors.statusRejected,
        textColor: Colors.white,
        child: icon,
      );
    }

    return InkWell(
      onTap: _handleTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.mintAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                // Increased icon<->label vertical gap (8px, up from the
                // stock NavigationBar's ~4px) for a less-cramped feel.
                const SizedBox(height: 8),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
