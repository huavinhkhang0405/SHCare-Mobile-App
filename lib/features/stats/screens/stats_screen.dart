import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../../home/providers/health_provider.dart';
import '../widgets/health_score_card.dart';
import '../widgets/sleep_stage_visualizer.dart';
import '../widgets/stats_sections.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<SettingsProvider, (int, String)>((p) => (p.themeColorHex, p.languageCode));
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
              StatsSectionHeader(
                title: context.tr('highlight_metrics'),
                actionLabel: context.tr('this_week'),
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
              StatsSectionHeader(
                title: context.tr('body_metrics'),
                actionLabel: context.tr('medical_metrics'),
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
              StatsSectionHeader(
                title: context.tr('weekly_trends'),
                actionLabel: context.tr('vs_last_week'),
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
