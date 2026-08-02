import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';

import '../theme/app_theme.dart';

/// A high-contrast tab strip intended specifically for navy app bars.
///
/// Material's default [TabBar] inherits the app's gold secondary colour,
/// which does not provide enough contrast on NeoTask's dark app bar. This
/// wrapper keeps secondary navigation readable and prevents its tabs from
/// stretching awkwardly across wide desktop screens.
class NeoAppBarTabs extends StatelessWidget implements PreferredSizeWidget {
  const NeoAppBarTabs({
    super.key,
    required this.controller,
    required this.tabs,
    this.maxWidth = 680,
  });

  final TabController controller;
  final List<Widget> tabs;
  final double maxWidth;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: controller,
              tabs: tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
              labelStyle: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              indicator: BoxDecoration(
                color: AppColors.mintAccent.withValues(alpha: 0.17),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.mintAccent.withValues(alpha: 0.62),
                  width: 1.2,
                ),
              ),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return AppColors.mintAccent.withValues(alpha: 0.10);
                }
                return Colors.transparent;
              }),
              splashBorderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact single-line label for [NeoAppBarTabs]. Keeping the icon beside
/// the text (instead of Flutter's default stacked Tab layout) preserves a
/// comfortable app-bar height on both desktop and mobile.
class NeoAppBarTab extends StatelessWidget {
  const NeoAppBarTab({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
