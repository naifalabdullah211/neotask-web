import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Account-specific avatar with a safe initial-letter fallback.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    this.radius = 22,
    this.borderColor = AppColors.gold,
    this.borderWidth = 2,
    this.backgroundColor,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final Color? backgroundColor;

  Widget _fallback() {
    return ColoredBox(
      color: backgroundColor ?? AppColors.goldLight,
      child: Center(
        child: Text(
          name.trim().isNotEmpty ? name.trim()[0] : '؟',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: radius * 0.78,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Semantics(
      image: true,
      label: 'الصورة الشخصية لـ $name',
      child: Container(
        width: radius * 2,
        height: radius * 2,
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: ClipOval(
          child: url == null || url.isEmpty
              ? _fallback()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => _fallback(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _fallback(),
                ),
        ),
      ),
    );
  }
}
