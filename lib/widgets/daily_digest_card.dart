import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import '../models/manager_digest_model.dart';
import '../theme/app_theme.dart';

/// "ملخص المدير اليومي/الأسبوعي" dashboard card — sits ABOVE the 6
/// existing stat cards on ManagerDashboardTab (per explicit requirement).
/// RCJY-consistent styling: reuses AppColors.navy/gold, AppRadius.lg,
/// AppElevation.lowShadow — no new decorative colors introduced, per the
/// explicit "بقاء نظيف/مهني، دون عناصر أو ألوان زخرفية خارج هوية RCJY"
/// constraint.
class DailyDigestCard extends StatefulWidget {
  const DailyDigestCard({
    super.key,
    required this.digest,
    this.isGenerating = false,
  });

  final ManagerDigest? digest;
  final bool isGenerating;

  @override
  State<DailyDigestCard> createState() => _DailyDigestCardState();
}

class _DailyDigestCardState extends State<DailyDigestCard> {
  // Collapsed AFTER first read, per explicit requirement ("زر طي/فتح
  // (Collapse/Expand) — بعد أول قراءة يتحول لوضع مطوي"). Starts expanded
  // so the manager sees it fresh the first time it appears.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.isGenerating && widget.digest == null) {
      return _buildShell(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      );
    }

    final digest = widget.digest;
    if (digest == null) return const SizedBox.shrink();

    return _buildShell(
      digest: digest,
      child: AnimatedSize(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
        child: _expanded
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  digest.messageText,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildShell({required Widget child, ManagerDigest? digest}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
        boxShadow: AppElevation.lowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.summarize_outlined,
                  size: 18,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ملخص المدير',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (digest != null) _TypeBadge(isWeekly: digest.isWeekly),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: digest == null
                    ? null
                    : () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppMotion.medium,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

/// "ملخص اليوم" / "ملخص الأسبوع" label badge — gold-accented per the
/// existing two-hue palette (navy + gold), no third color introduced.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isWeekly});

  final bool isWeekly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isWeekly ? 'ملخص الأسبوع' : 'ملخص اليوم',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
