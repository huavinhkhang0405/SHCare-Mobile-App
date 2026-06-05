import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';

class MoodOption {
  const MoodOption({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;
}

const List<MoodOption> kMoodOptions = [
  MoodOption(emoji: '😄', label: 'Rất tốt', color: Color(0xFFE7F7EE)),
  MoodOption(emoji: '🙂', label: 'Ổn định', color: Color(0xFFEAF5FF)),
  MoodOption(emoji: '😐', label: 'Bình thường', color: Color(0xFFFFF4E4)),
  MoodOption(emoji: '😣', label: 'Căng thẳng', color: Color(0xFFFFEBEC)),
];

const List<String> kSymptomOptions = [
  'Mỏi cổ vai',
  'Đau đầu nhẹ',
  'Mất tập trung',
  'Mất ngủ',
  'Không có',
];

class JournalHeader extends StatelessWidget {
  const JournalHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nhật ký sức khỏe',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Ghi nhanh trạng thái cơ thể và tinh thần để theo dõi tiến triển.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class JournalSectionHeader extends StatelessWidget {
  const JournalSectionHeader({
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
        Flexible(
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class JournalHydrationCard extends StatelessWidget {
  const JournalHydrationCard({
    super.key,
    required this.glasses,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int glasses;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final liters = (glasses * 0.25).toStringAsFixed(2);

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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.waterTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const GifIcon(
              assetPath: AppGifIcons.water,
              fallbackIcon: Icons.local_drink_rounded,
              fallbackColor: AppColors.waterIcon,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nước đã uống hôm nay',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$liters L · $glasses ly',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              JournalRoundIconButton(
                gifAssetPath: AppGifIcons.minus,
                icon: Icons.remove,
                onTap: onDecrease,
              ),
              const SizedBox(width: 8),
              JournalRoundIconButton(
                gifAssetPath: AppGifIcons.plus,
                icon: Icons.add,
                onTap: onIncrease,
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class JournalEnergyCard extends StatelessWidget {
  const JournalEnergyCard({
    super.key,
    required this.energyLevel,
    required this.onChanged,
    this.onChangeEnd,
  });

  final double energyLevel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mức năng lượng hiện tại',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(energyLevel * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.12),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: energyLevel,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
              divisions: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class JournalRoundIconButton extends StatelessWidget {
  const JournalRoundIconButton({
    super.key,
    required this.gifAssetPath,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String gifAssetPath;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.primarySurface,
          shape: BoxShape.circle,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: GifIcon(
          assetPath: gifAssetPath,
          fallbackIcon: icon,
          size: 20,
          fallbackColor: isPrimary ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}
