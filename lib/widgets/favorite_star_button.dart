import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import '../providers/favorite_provider.dart';
import '../theme/app_theme.dart';

/// Reusable "add to favorites" star toggle, shared across every task
/// card/detail screen (employee task list, manager dashboard task list,
/// manager submitted-review queue, employee task detail, manager task
/// review detail) so the tap-to-toggle logic and visual style stay
/// perfectly consistent app-wide.
///
/// - Empty outline star (☆) = not favorited.
/// - Filled star (★) in RCJY brand gold (#E8B84B, [AppColors.favoriteGold])
///   = favorited.
/// - Tapping toggles via [FavoriteProvider.toggleFavorite]; the provider
///   already calls `notifyListeners()` on every Firestore change, so this
///   widget (via `context.watch`) and the Favorites screen elsewhere both
///   rebuild automatically without any extra plumbing.
class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    super.key,
    required this.userUid,
    required this.taskId,
    this.size = AppIconSize.lg,
  });

  final String userUid;
  final String taskId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.watch<FavoriteProvider>().isFavorite(
      userUid,
      taskId,
    );
    return IconButton(
      tooltip: context.tr(
        isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
      ),
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        color: isFavorite ? AppColors.favoriteGold : AppColors.textSecondary,
        size: size,
      ),
      onPressed: () =>
          context.read<FavoriteProvider>().toggleFavorite(userUid, taskId),
    );
  }
}
