import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';

class StatsHeader extends StatelessWidget {
  const StatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thống kê sức khỏe',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Theo dõi tiến độ và xu hướng của bạn',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppColors.softShadow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GifIcon(
                assetPath: AppGifIcons.calendar,
                fallbackIcon: Icons.calendar_today_rounded,
                size: 14,
                fallbackColor: AppColors.primary,
              ),
              SizedBox(width: 6),
              Text(
                'Tuần 16',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatsSectionHeader extends StatelessWidget {
  const StatsSectionHeader({
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

class StatsInsightGrid extends StatelessWidget {
  const StatsInsightGrid({
    super.key,
    required this.hrv,
    required this.hrvDelta,
    required this.restingBpm,
    required this.restingStatus,
    required this.caloriesBurned,
    required this.caloriesDelta,
    required this.deepSleepLabel,
    required this.deepSleepDeltaMinutes,
  });

  final int hrv;
  final int hrvDelta;
  final int restingBpm;
  final String restingStatus;
  final int caloriesBurned;
  final int caloriesDelta;
  final String deepSleepLabel;
  final int deepSleepDeltaMinutes;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.05,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatsInsightCard(
          title: 'HRV',
          value: '$hrv ms',
          delta: hrvDelta >= 0 ? '+$hrvDelta%' : '$hrvDelta%',
          gifAssetPath: AppGifIcons.bolt,
          icon: Icons.bolt_rounded,
          color: AppColors.boltTint,
          iconColor: AppColors.boltIcon,
        ),
        _StatsInsightCard(
          title: 'Nghỉ ngơi',
          value: '$restingBpm bpm',
          delta: restingStatus,
          gifAssetPath: AppGifIcons.heart,
          icon: Icons.favorite_rounded,
          color: AppColors.heartTint,
          iconColor: AppColors.heartIcon,
        ),
        _StatsInsightCard(
          title: 'Calo đốt',
          value: '$caloriesBurned',
          delta: caloriesDelta >= 0 ? '+$caloriesDelta%' : '$caloriesDelta%',
          gifAssetPath: AppGifIcons.fire,
          icon: Icons.local_fire_department_rounded,
          color: AppColors.fireTint,
          iconColor: AppColors.fireIcon,
        ),
        _StatsInsightCard(
          title: 'Ngủ sâu',
          value: deepSleepLabel,
          delta: deepSleepDeltaMinutes >= 0
              ? '+$deepSleepDeltaMinutes phút'
              : '$deepSleepDeltaMinutes phút',
          gifAssetPath: AppGifIcons.sleep,
          icon: Icons.nightlight_round,
          color: AppColors.sleepTint,
          iconColor: AppColors.sleepIcon,
        ),
      ],
    );
  }
}

class _StatsInsightCard extends StatelessWidget {
  const _StatsInsightCard({
    required this.title,
    required this.value,
    required this.delta,
    required this.gifAssetPath,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String delta;
  final String gifAssetPath;
  final IconData icon;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
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
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            delta,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class StatsWeeklyActivityCard extends StatelessWidget {
  const StatsWeeklyActivityCard({
    super.key,
    required this.metrics,
    required this.averageActivity,
  });

  final List<double> metrics;
  final double averageActivity;

  static const List<String> _dayLabels = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  @override
  Widget build(BuildContext context) {
    final normalizedMetrics = List<double>.generate(_dayLabels.length, (index) {
      if (index < metrics.length) {
        return metrics[index].clamp(0.0, 1.0).toDouble();
      }
      return 0.5;
    });

    final dayMetrics = List<_DayMetric>.generate(
      _dayLabels.length,
      (index) =>
          _DayMetric(label: _dayLabels[index], value: normalizedMetrics[index]),
    );

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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mức độ vận động',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TB ${(averageActivity * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dayMetrics
                  .map(
                    (metric) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _DayBar(metric: metric),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.metric});

  final _DayMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 22,
              height: 120 * metric.value,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppColors.primaryGradient,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          metric.label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

class _DayMetric {
  const _DayMetric({required this.label, required this.value});

  final String label;
  final double value;
}
