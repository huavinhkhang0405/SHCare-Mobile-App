import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_localizations.dart';
import '../../../core/widgets/gif_icon.dart';

class TipItem {
  const TipItem({
    required this.title,
    required this.description,
    required this.duration,
    required this.category,
    required this.gifAssetPath,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final String title;
  final String description;
  final String duration;
  final String category;
  final String gifAssetPath;
  final IconData icon;
  final Color color;
  final Color iconColor;
}

List<TipItem> getAllHealthTips(BuildContext context) => [
  TipItem(
    title: context.tr('tip_water_title'),
    description: context.tr('tip_water_desc'),
    duration: '2 min',
    category: context.tr('category_nutrition'),
    gifAssetPath: AppGifIcons.water,
    icon: Icons.water_drop_rounded,
    color: AppColors.waterTint,
    iconColor: AppColors.waterIcon,
  ),
  TipItem(
    title: context.tr('tip_fiber_title'),
    description: context.tr('tip_fiber_desc'),
    duration: '5 min',
    category: context.tr('category_nutrition'),
    gifAssetPath: AppGifIcons.tips,
    icon: Icons.restaurant_rounded,
    color: AppColors.fireTint,
    iconColor: AppColors.fireIcon,
  ),
  TipItem(
    title: context.tr('tip_yogurt_title'),
    description: context.tr('tip_yogurt_desc'),
    duration: '5 min',
    category: context.tr('category_nutrition'),
    gifAssetPath: AppGifIcons.tips,
    icon: Icons.restaurant_rounded,
    color: AppColors.fireTint,
    iconColor: AppColors.fireIcon,
  ),
  TipItem(
    title: context.tr('tip_walk_title'),
    description: context.tr('tip_walk_desc'),
    duration: '15 min',
    category: context.tr('category_exercise'),
    gifAssetPath: AppGifIcons.walk,
    icon: Icons.directions_walk_rounded,
    color: AppColors.primarySurface,
    iconColor: AppColors.primary,
  ),
  TipItem(
    title: context.tr('tip_stretch_title'),
    description: context.tr('tip_stretch_desc'),
    duration: '5 min',
    category: context.tr('category_exercise'),
    gifAssetPath: AppGifIcons.walk,
    icon: Icons.accessibility_new_rounded,
    color: AppColors.boltTint,
    iconColor: AppColors.boltIcon,
  ),
  TipItem(
    title: context.tr('tip_squat_title'),
    description: context.tr('tip_squat_desc'),
    duration: '3 min',
    category: context.tr('category_exercise'),
    gifAssetPath: AppGifIcons.walk,
    icon: Icons.fitness_center_rounded,
    color: AppColors.primarySurface,
    iconColor: AppColors.primary,
  ),
  TipItem(
    title: context.tr('tip_breath_title'),
    description: context.tr('tip_breath_desc'),
    duration: '3 min',
    category: context.tr('category_mental'),
    gifAssetPath: AppGifIcons.meditate,
    icon: Icons.self_improvement_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: context.tr('tip_meditate_title'),
    description: context.tr('tip_meditate_desc'),
    duration: '5 min',
    category: context.tr('category_mental'),
    gifAssetPath: AppGifIcons.meditate,
    icon: Icons.self_improvement_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: context.tr('tip_screen_title'),
    description: context.tr('tip_screen_desc'),
    duration: '5 min',
    category: context.tr('category_mental'),
    gifAssetPath: AppGifIcons.search,
    icon: Icons.remove_red_eye_rounded,
    color: AppColors.boltTint,
    iconColor: AppColors.boltIcon,
  ),
  TipItem(
    title: context.tr('tip_device_title'),
    description: context.tr('tip_device_desc'),
    duration: '30 min',
    category: context.tr('category_sleep'),
    gifAssetPath: AppGifIcons.sleep,
    icon: Icons.nights_stay_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: context.tr('tip_brownnoise_title'),
    description: context.tr('tip_brownnoise_desc'),
    duration: '15 min',
    category: context.tr('category_sleep'),
    gifAssetPath: AppGifIcons.sleep,
    icon: Icons.music_note_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: context.tr('tip_muscle_title'),
    description: context.tr('tip_muscle_desc'),
    duration: '10 min',
    category: context.tr('category_sleep'),
    gifAssetPath: AppGifIcons.sleep,
    icon: Icons.nightlight_round,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
];

List<TipItem> buildTipItems({
  required BuildContext context,
  required int steps,
  required int goal,
  required int waterPercentage,
  required int bpm,
  required double energyLevel,
}) {
  final tips = <TipItem>[];

  final stepProgress = goal > 0 ? (steps / goal).clamp(0.0, 1.0).toDouble() : 0.0;
  final remainingSteps = (goal - steps).clamp(0, goal).toInt();
  final walkMinutes = (remainingSteps / 350).ceil().clamp(8, 20).toInt();

  // 1. Priority rule-based urgent tips
  if (waterPercentage < 80) {
    final remainingPercent = (100 - waterPercentage).clamp(0, 100);
    tips.add(
      TipItem(
        title: context.tr('tip_water_dynamic_title'),
        description: context.tr('tip_water_dynamic_desc').replaceAll('{percent}', '$remainingPercent'),
        duration: '2 min',
        category: context.tr('category_nutrition'),
        gifAssetPath: AppGifIcons.water,
        icon: Icons.water_drop_rounded,
        color: AppColors.waterTint,
        iconColor: AppColors.waterIcon,
      ),
    );
  }

  if (stepProgress < 0.9) {
    tips.add(
      TipItem(
        title: context.tr('tip_walk_dynamic_title').replaceAll('{steps}', '$remainingSteps'),
        description: context.tr('tip_walk_dynamic_desc')
            .replaceAll('{percent}', '${(stepProgress * 100).round()}'),
        duration: '$walkMinutes min',
        category: context.tr('category_exercise'),
        gifAssetPath: AppGifIcons.walk,
        icon: Icons.directions_walk_rounded,
        color: AppColors.primarySurface,
        iconColor: AppColors.primary,
      ),
    );
  }

  if (bpm > 80 || energyLevel < 0.55) {
    tips.add(
      TipItem(
        title: context.tr('tip_breath_dynamic_title'),
        description: context.tr('tip_breath_dynamic_desc').replaceAll('{bpm}', '$bpm'),
        duration: '3 min',
        category: context.tr('category_mental'),
        gifAssetPath: AppGifIcons.meditate,
        icon: Icons.self_improvement_rounded,
        color: AppColors.sleepTint,
        iconColor: AppColors.sleepIcon,
      ),
    );
  }

  // 2. Fill up to minimum 3 tips from the static list (no duplicate titles)
  final allTips = getAllHealthTips(context);
  for (final candidate in allTips) {
    if (tips.length >= 3) break;
    final alreadyAdded = tips.any((t) => t.title == candidate.title);
    if (!alreadyAdded) {
      tips.add(candidate);
    }
  }

  return tips;
}

class TipsHeader extends StatelessWidget {
  const TipsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('smart_tips_title'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('tips_header_subtitle'),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class TipsSearchBar extends StatelessWidget {
  const TipsSearchBar({
    super.key,
    required this.onChanged,
  });

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          const GifIcon(
            assetPath: AppGifIcons.search,
            fallbackIcon: Icons.search_rounded,
            fallbackColor: AppColors.textHint,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: context.tr('tips_search_placeholder'),
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TipsCategoryChips extends StatelessWidget {
  const TipsCategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final categories = [
      context.tr('category_all'),
      context.tr('category_nutrition'),
      context.tr('category_exercise'),
      context.tr('category_mental'),
      context.tr('category_sleep'),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          return GestureDetector(
            onTap: () => onCategorySelected(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Color(AppColors.primaryHex) : AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Color(AppColors.primaryHex) : AppColors.cardBorder,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Color(AppColors.primaryHex).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TipsSectionHeader extends StatelessWidget {
  const TipsSectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
  });

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          actionLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(AppColors.primaryHex),
          ),
        ),
      ],
    );
  }
}

class TipActionCard extends StatelessWidget {
  const TipActionCard({super.key, required this.item});

  final TipItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(item.color.value),
              borderRadius: BorderRadius.circular(14),
            ),
            child: GifIcon(
              assetPath: item.gifAssetPath,
              fallbackIcon: item.icon,
              fallbackColor: Color(item.iconColor.value),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Color(AppColors.primarySurfaceHex),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(AppColors.primaryHex),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.duration,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const GifIcon(
              assetPath: AppGifIcons.chevron,
              fallbackIcon: Icons.chevron_right_rounded,
              fallbackColor: AppColors.textHint,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class TipsMiniHabitCard extends StatelessWidget {
  const TipsMiniHabitCard({
    super.key,
    required this.gifAssetPath,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
  });

  final String gifAssetPath;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(color.value),
              borderRadius: BorderRadius.circular(12),
            ),
            child: GifIcon(
              assetPath: gifAssetPath,
              fallbackIcon: icon,
              fallbackColor: Color(iconColor.value),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
