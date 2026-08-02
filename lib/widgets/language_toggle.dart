import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.compact = false, this.dark = false});

  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final foreground = dark ? Colors.white : const Color(0xFF1B3A6B);
    final muted = dark ? Colors.white70 : const Color(0xFF64748B);
    final border = dark ? Colors.white24 : const Color(0xFFDCE3ED);

    return Semantics(
      label: locale.isArabic ? 'Switch to English' : 'التبديل إلى العربية',
      button: true,
      child: Material(
        color: dark ? Colors.white.withValues(alpha: .08) : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: locale.toggle,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 13,
              vertical: compact ? 7 : 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_rounded, size: compact ? 16 : 18, color: foreground),
                const SizedBox(width: 7),
                Text(
                  locale.isArabic ? 'English' : 'العربية',
                  style: TextStyle(
                    color: locale.isArabic ? foreground : muted,
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
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
