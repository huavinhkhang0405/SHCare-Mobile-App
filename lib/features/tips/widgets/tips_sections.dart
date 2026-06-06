import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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

const List<TipItem> allHealthTips = [
  TipItem(
    title: 'Bổ sung nước ngay',
    description: 'Uống 1 ly nước 250ml giúp tăng cường trao đổi chất, cấp ẩm và duy trì sự tỉnh táo.',
    duration: '2 phút',
    category: 'Dinh dưỡng',
    gifAssetPath: AppGifIcons.water,
    icon: Icons.water_drop_rounded,
    color: AppColors.waterTint,
    iconColor: AppColors.waterIcon,
  ),
  TipItem(
    title: 'Ăn thêm chất xơ',
    description: 'Bổ sung rau xanh hoặc các loại hạt vào bữa chính giúp tiêu hóa tốt hơn và no lâu.',
    duration: '5 phút',
    category: 'Dinh dưỡng',
    gifAssetPath: AppGifIcons.tips,
    icon: Icons.restaurant_rounded,
    color: AppColors.fireTint,
    iconColor: AppColors.fireIcon,
  ),
  TipItem(
    title: 'Bữa phụ chống mệt mỏi',
    description: 'Sữa chua Hy Lạp và trái cây ít đường là lựa chọn nhẹ, dễ tiêu và ổn định năng lượng.',
    duration: '5 phút',
    category: 'Dinh dưỡng',
    gifAssetPath: AppGifIcons.tips,
    icon: Icons.restaurant_rounded,
    color: AppColors.fireTint,
    iconColor: AppColors.fireIcon,
  ),
  TipItem(
    title: 'Đi bộ sau bữa ăn',
    description: 'Đi bộ nhẹ nhàng từ 10-15 phút giúp làm giảm lượng đường trong máu và hỗ trợ tiêu hóa.',
    duration: '15 phút',
    category: 'Vận động',
    gifAssetPath: AppGifIcons.walk,
    icon: Icons.directions_walk_rounded,
    color: AppColors.primarySurface,
    iconColor: AppColors.primary,
  ),
  TipItem(
    title: 'Giãn cơ cổ vai gáy',
    description: 'Chu kỳ giãn cơ 5 phút giúp giảm mỏi cổ, vai gáy do ngồi làm việc sai tư thế trong thời gian dài.',
    duration: '5 phút',
    category: 'Vận động',
    gifAssetPath: AppGifIcons.walk,
    icon: Icons.accessibility_new_rounded,
    color: AppColors.boltTint,
    iconColor: AppColors.boltIcon,
  ),
  TipItem(
    title: 'Tập Squat nhẹ nhàng',
    description: 'Thực hiện 10-15 lượt Squat tại chỗ giúp kích hoạt các nhóm cơ lớn ở phần thân dưới.',
    duration: '3 phút',
    category: 'Vận động',
    gifAssetPath: AppGifIcons.walk,
    icon: Icons.fitness_center_rounded,
    color: AppColors.primarySurface,
    iconColor: AppColors.primary,
  ),
  TipItem(
    title: 'Thở 4-7-8 thư giãn',
    description: 'Hít vào 4 giây, giữ hơi 7 giây, thở ra 8 giây giúp hạ căng thẳng và điều hòa nhịp tim.',
    duration: '3 phút',
    category: 'Tinh thần',
    gifAssetPath: AppGifIcons.meditate,
    icon: Icons.self_improvement_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: 'Thiền chánh niệm ngắn',
    description: 'Nhắm mắt và tập trung hoàn toàn vào luồng thở giúp cải thiện sự tập trung và giảm lo âu.',
    duration: '5 phút',
    category: 'Tinh thần',
    gifAssetPath: AppGifIcons.meditate,
    icon: Icons.self_improvement_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: 'Rời xa màn hình 5 phút',
    description: 'Áp dụng quy tắc 20-20-20: nhìn xa 20 feet (6m) trong 20 giây để giảm mỏi mắt điều tiết.',
    duration: '5 phút',
    category: 'Tinh thần',
    gifAssetPath: AppGifIcons.search,
    icon: Icons.remove_red_eye_rounded,
    color: AppColors.boltTint,
    iconColor: AppColors.boltIcon,
  ),
  TipItem(
    title: 'Tắt thiết bị trước khi ngủ',
    description: 'Tắt điện thoại, máy tính 30 phút trước khi ngủ giúp não tiết melatonin dễ ngủ hơn.',
    duration: '30 phút',
    category: 'Ngủ',
    gifAssetPath: AppGifIcons.sleep,
    icon: Icons.nights_stay_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: 'Nghe tiếng ồn nâu (Brown Noise)',
    description: 'Nghe âm thanh tần số thấp như tiếng mưa, tiếng sóng giúp não bộ tĩnh tâm và chìm sâu vào giấc ngủ.',
    duration: '15 phút',
    category: 'Ngủ',
    gifAssetPath: AppGifIcons.sleep,
    icon: Icons.music_note_rounded,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
  TipItem(
    title: 'Thư giãn cơ trước ngủ',
    description: 'Căng rồi thả lỏng từng nhóm cơ từ ngón chân lên đầu giúp giải phóng căng thẳng vật lý tích tụ.',
    duration: '10 phút',
    category: 'Ngủ',
    gifAssetPath: AppGifIcons.sleep,
    icon: Icons.nightlight_round,
    color: AppColors.sleepTint,
    iconColor: AppColors.sleepIcon,
  ),
];

List<TipItem> buildTipItems({
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

  // 1. Ưu tiên các gợi ý rule-based khẩn cấp
  if (waterPercentage < 80) {
    final remainingPercent = (100 - waterPercentage).clamp(0, 100);
    tips.add(
      TipItem(
        title: 'Bổ dung nước ngay',
        description: 'Bạn còn thiếu $remainingPercent% mục tiêu nước. Thêm 1 ly 250ml sẽ giúp tỉnh táo hơn.',
        duration: '2 phút',
        category: 'Dinh dưỡng',
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
        title: 'Đi bộ thêm $remainingSteps bước',
        description: 'Bạn đã đạt ${(stepProgress * 100).round()}% mục tiêu. Đi bộ nhẹ sẽ giúp cải thiện chuyển hóa.',
        duration: '$walkMinutes phút',
        category: 'Vận động',
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
        title: 'Thở 4-7-8 trong 3 phút',
        description: 'Nhịp tim hiện tại $bpm bpm. Bài thở chậm giúp cơ thể hạ căng thẳng nhanh.',
        duration: '3 phút',
        category: 'Tinh thần',
        gifAssetPath: AppGifIcons.meditate,
        icon: Icons.self_improvement_rounded,
        color: AppColors.sleepTint,
        iconColor: AppColors.sleepIcon,
      ),
    );
  }

  // 2. Điền thêm từ kho dữ liệu tips cho đủ tối thiểu 3 tips (không trùng lặp tiêu đề)
  for (final candidate in allHealthTips) {
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gợi ý thông minh',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Lựa chọn những hành động nhỏ để chăm sóc sức khỏe tốt hơn.',
          style: TextStyle(
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
              decoration: const InputDecoration(
                hintText: 'Tìm mẹo về ăn uống, vận động, giấc ngủ...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
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
    const categories = ['Tất cả', 'Dinh dưỡng', 'Vận động', 'Tinh thần', 'Ngủ'];

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
                color: isSelected ? AppColors.primary : AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
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
              color: item.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: GifIcon(
              assetPath: item.gifAssetPath,
              fallbackIcon: item.icon,
              fallbackColor: item.iconColor,
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
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GifIcon(
              assetPath: gifAssetPath,
              fallbackIcon: icon,
              fallbackColor: iconColor,
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
