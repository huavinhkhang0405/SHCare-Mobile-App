import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../providers/auth_provider.dart';

class StatsHeader extends StatelessWidget {
  const StatsHeader({super.key});

  int _getWeekOfYear(DateTime? createdAt) {
    if (createdAt == null) return 1;
    final now = DateTime.now();
    final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final nowDate = DateTime(now.year, now.month, now.day);
    final daysPast = nowDate.difference(createdDate).inDays;
    final week = (daysPast / 7).floor() + 1;
    return week < 1 ? 1 : week;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final createdAt = authProvider.currentUser?.createdAt;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('stats_health_title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('stats_health_desc'),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GifIcon(
                assetPath: AppGifIcons.calendar,
                fallbackIcon: Icons.calendar_today_rounded,
                size: 14,
                fallbackColor: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('week_number', arguments: {'number': _getWeekOfYear(createdAt).toString()}),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFamily: 'Inter',
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
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
          title: context.tr('resting_heart_rate'),
          value: '$restingBpm bpm',
          delta: restingStatus == 'Ổn định' ? context.tr('stable') : (restingStatus == 'Cần nghỉ' ? context.tr('needs_rest') : restingStatus),
          gifAssetPath: AppGifIcons.heart,
          icon: Icons.favorite_rounded,
          color: AppColors.heartTint,
          iconColor: AppColors.heartIcon,
        ),
        _StatsInsightCard(
          title: context.tr('calories_burned'),
          value: '$caloriesBurned',
          delta: caloriesDelta >= 0 ? '+$caloriesDelta%' : '$caloriesDelta%',
          gifAssetPath: AppGifIcons.fire,
          icon: Icons.local_fire_department_rounded,
          color: AppColors.fireTint,
          iconColor: AppColors.fireIcon,
        ),
        _StatsInsightCard(
          title: context.tr('deep_sleep'),
          value: deepSleepLabel,
          delta: deepSleepDeltaMinutes >= 0
              ? '+$deepSleepDeltaMinutes ${context.tr('minutes_unit')}'
              : '$deepSleepDeltaMinutes ${context.tr('minutes_unit')}',
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



  @override
  Widget build(BuildContext context) {
    final dayLabels = [
      context.tr('weekday_short_1'),
      context.tr('weekday_short_2'),
      context.tr('weekday_short_3'),
      context.tr('weekday_short_4'),
      context.tr('weekday_short_5'),
      context.tr('weekday_short_6'),
      context.tr('weekday_short_7'),
    ];

    final normalizedMetrics = List<double>.generate(dayLabels.length, (index) {
      if (index < metrics.length) {
        return metrics[index].clamp(0.0, 1.0).toDouble();
      }
      return 0.5;
    });

    final dayMetrics = List<_DayMetric>.generate(
      dayLabels.length,
      (index) =>
          _DayMetric(label: dayLabels[index], value: normalizedMetrics[index]),
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
              Text(
                context.tr('activity_level'),
                style: const TextStyle(
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
                  context.tr('average_activity', arguments: {'percent': (averageActivity * 100).round().toString()}),
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

class StatsBodyMetricsCard extends StatelessWidget {
  final double heightCm;
  final double weightKg;
  final double bmi;
  final String bmiCategory;
  final Color bmiColor;
  final int bmr;
  final int tdee;
  final int targetCalories;

  const StatsBodyMetricsCard({
    super.key,
    required this.heightCm,
    required this.weightKg,
    required this.bmi,
    required this.bmiCategory,
    required this.bmiColor,
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
  });

  String _translateBmiCategory(BuildContext context, String category) {
    if (category.contains('Thiếu cân') || category.toLowerCase().contains('underweight')) {
      return context.tr('bmi_underweight');
    } else if (category.contains('Bình thường') || category.toLowerCase().contains('normal')) {
      return context.tr('bmi_normal');
    } else if (category.contains('Tiền béo phì') || category.contains('Thừa cân') || category.toLowerCase().contains('overweight')) {
      return context.tr('bmi_overweight');
    } else if (category.contains('Béo phì') || category.toLowerCase().contains('obese')) {
      return context.tr('bmi_obese');
    }
    return category;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('body_metrics_and_metabolism'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetricRow(context.tr('height'), '${heightCm.toStringAsFixed(1)} cm', context.tr('weight'), '${weightKg.toStringAsFixed(1)} kg'),
          const Divider(height: 24, color: AppColors.cardBorder),
          _buildBmiRow(context),
          const Divider(height: 24, color: AppColors.cardBorder),
          _buildMetricRow(context.tr('bmr_rate'), '${bmr.round()} kcal', context.tr('tdee_energy'), '${tdee.round()} kcal'),
          const Divider(height: 24, color: AppColors.cardBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('target_calories_intake'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$targetCalories ${context.tr('kcal_per_day')}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label1, String val1, String label2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                val1,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label2,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                val2,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBmiRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('bmi_index'),
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                bmi.toStringAsFixed(1),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('body_status'),
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bmiColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bmiColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _translateBmiCategory(context, bmiCategory),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: bmiColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
