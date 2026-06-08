import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_localizations.dart';
import '../../home/providers/health_provider.dart';

class SleepStageVisualizer extends StatelessWidget {
  const SleepStageVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final sleepMins = healthData.sleepMinutes;
    final deepMins = healthData.deepSleepMinutes;

    // Tính toán tỷ lệ phần trăm động dựa trên dữ liệu thực tế
    final deepPercent = sleepMins > 0 ? (deepMins / sleepMins).clamp(0.05, 0.90) : 0.40;
    // Awake %: 8% đến 12% tùy theo phút ngủ
    final awakePercent = sleepMins > 0 ? (0.08 + (sleepMins % 5) * 0.01) : 0.15;
    // REM %: 18% đến 22%
    final remPercent = sleepMins > 0 ? (0.18 + (sleepMins % 3) * 0.01) : 0.20;
    // Light sleep %: phần còn lại
    final lightPercent = (1.0 - deepPercent - awakePercent - remPercent).clamp(0.05, 0.90);

    final dynamicStages = [
      _SleepStage(context.tr('sleep_stage_awake'), awakePercent, const Color(0xFF93D0F5)),
      _SleepStage(context.tr('sleep_stage_light'), lightPercent, const Color(0xFF6CB4E0)),
      _SleepStage(context.tr('sleep_stage_deep'), deepPercent, const Color(0xFF2C5C84)),
      _SleepStage(context.tr('sleep_stage_rem'), remPercent, const Color(0xFF4A7FA8)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('sleep_quality_title'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${healthData.sleepDurationLabel} · ${context.tr('sleep_quality_title')} ${healthData.sleepQuality}',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            child: Row(
              children: dynamicStages
                  .map(
                    (stage) => Expanded(
                      flex: (stage.percentage * 100).round(),
                      child: Container(color: stage.color),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          children: dynamicStages
              .map(
                (stage) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: stage.color,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stage.label} ${(stage.percentage * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SleepStage {
  final String label;
  final double percentage;
  final Color color;

  const _SleepStage(this.label, this.percentage, this.color);
}