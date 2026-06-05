import 'package:flutter/material.dart';

import '../../../core/widgets/gif_icon.dart';

class TipsSection extends StatelessWidget {
  const TipsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Gợi ý cho bạn',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Xem tất cả',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _buildTipCard(
                gifAssetPath: AppGifIcons.tips,
                icon: Icons.restaurant,
                title: 'Dinh dưỡng buổi sáng',
                desc: 'Một quả bơ sẽ giúp bạn no lâu và minh mẫn hơn.',
                iconBg: const Color(0xFFA1F3D5),
                iconColor: const Color(0xFF005D48),
              ),
              const SizedBox(width: 16),
              _buildTipCard(
                gifAssetPath: AppGifIcons.meditate,
                icon: Icons.self_improvement,
                title: '5 Phút Thiền định',
                desc: 'Giảm căng thẳng ngay lập tức với bài thở 4-7-8.',
                iconBg: const Color(0xFFFFD9E4),
                iconColor: const Color(0xFF764255),
              ),
              const SizedBox(width: 16),
              _buildTipCard(
                gifAssetPath: AppGifIcons.bolt,
                icon: Icons.lightbulb,
                title: 'Ánh sáng mặt trời',
                desc: 'Tiếp xúc 10 phút nắng sáng giúp cải thiện vitamin D.',
                iconBg: const Color(0xFFA0CDFC),
                iconColor: const Color(0xFF0D456D),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard({
    required String gifAssetPath,
    required IconData icon,
    required String title,
    required String desc,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF4D4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: GifIcon(
              assetPath: gifAssetPath,
              fallbackIcon: icon,
              fallbackColor: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
