import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';

class FeaturedTipCard extends StatelessWidget {
  const FeaturedTipCard({
    super.key,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.gifAssetPath,
    required this.icon,
    this.badge = 'NỔI BẬT',
    this.onPressed,
  });

  final String title;
  final String description;
  final String ctaLabel;
  final String gifAssetPath;
  final IconData icon;
  final String badge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(AppColors.primaryLightHex), Color(AppColors.primarySurfaceHex)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Color(AppColors.primaryHex).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(AppColors.primaryDarkHex).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(AppColors.primaryDarkHex),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(AppColors.primaryDarkHex),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(ctaLabel),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Color(AppColors.primaryDarkHex).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: GifIcon(
              assetPath: gifAssetPath,
              fallbackIcon: icon,
              fallbackColor: Color(AppColors.primaryDarkHex),
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}
