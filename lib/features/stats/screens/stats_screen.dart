import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/providers/health_provider.dart';
import '../widgets/health_score_card.dart';
import '../widgets/sleep_stage_visualizer.dart';
import '../widgets/stats_sections.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatsHeader(),
              const SizedBox(height: 18),
              HealthScoreCard(
                score: healthData.healthScore,
                message: healthData.healthScoreMessage,
              ),
              const SizedBox(height: 20),
              const StatsSectionHeader(
                title: 'Chỉ số nổi bật',
                actionLabel: 'Tuần này',
              ),
              const SizedBox(height: 10),
              StatsInsightGrid(
                hrv: healthData.hrv,
                hrvDelta: healthData.hrvDelta,
                restingBpm: healthData.restingBpm,
                restingStatus: healthData.restingTrendLabel,
                caloriesBurned: healthData.caloriesBurned,
                caloriesDelta: healthData.calorieDelta,
                deepSleepLabel: healthData.deepSleepLabel,
                deepSleepDeltaMinutes: healthData.deepSleepDeltaMinutes,
              ),
              const SizedBox(height: 20),
              const StatsSectionHeader(
                title: 'Chỉ số cơ thể & Chuyển hóa',
                actionLabel: 'Định lượng y khoa',
              ),
              const SizedBox(height: 10),
              StatsBodyMetricsCard(
                heightCm: healthData.currentUser?.heightCm ?? 170.0,
                weightKg: healthData.currentUser?.weightKg ?? 70.0,
                bmi: healthData.bmi,
                bmiCategory: healthData.bmiCategory,
                bmiColor: healthData.bmiColor,
                bmr: healthData.bmr.round(),
                tdee: healthData.tdee.round(),
                targetCalories: healthData.targetCalories,
              ),
              const SizedBox(height: 20),
              const StatsSectionHeader(
                title: 'Xu hướng 7 ngày',
                actionLabel: 'So với tuần trước',
              ),
              const SizedBox(height: 10),
              StatsWeeklyActivityCard(
                metrics: healthData.weeklyActivity,
                averageActivity: healthData.weeklyAverageActivity,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.softShadow,
                ),
                child: const SleepStageVisualizer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
