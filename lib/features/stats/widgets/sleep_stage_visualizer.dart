import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SleepStageVisualizer extends StatelessWidget {
  const SleepStageVisualizer({super.key});

  static const _stages = [
    _SleepStage('Thức', 0.15, Color(0xFF93D0F5)),
    _SleepStage('Ngủ nông', 0.25, Color(0xFF6CB4E0)),
    _SleepStage('Ngủ sâu', 0.40, Color(0xFF2C5C84)),
    _SleepStage('REM', 0.20, Color(0xFF4A7FA8)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chất lượng Giấc ngủ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '7h 45m · Chất lượng tốt',
          style: TextStyle(
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
              children: _stages
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _stages
              .map(
                (stage) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: stage.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
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