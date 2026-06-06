import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../models/task_suggestion.dart';
import '../../home/providers/health_provider.dart';
import '../widgets/featured_tip_card.dart';
import '../widgets/tips_sections.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final tipItems = buildTipItems(
      steps: healthData.steps,
      goal: healthData.goal,
      waterPercentage: healthData.waterPercentage,
      bpm: healthData.bpm,
      energyLevel: healthData.energyLevel,
    );
    final featuredTip = tipItems.first;
    final waterSubtitle = healthData.remainingWaterGlasses == 0
        ? 'Đủ mục tiêu'
        : 'Còn ${healthData.remainingWaterGlasses} ly';
    final sleepSubtitle = healthData.energyLevel < 0.55
        ? 'Ngủ sớm 22:00'
        : 'Giữ 22:30';

    // Hiển thị tất cả nhiệm vụ AI (không lọc dismiss vì đã bỏ chức năng dismiss)
    final activeTasks = healthData.aiTasks;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TipsHeader(),
              const SizedBox(height: 16),
              const TipsSearchBar(),
              const SizedBox(height: 16),
              FeaturedTipCard(
                title: featuredTip.title,
                description: featuredTip.description,
                ctaLabel: 'Làm ngay',
                gifAssetPath: featuredTip.gifAssetPath,
                icon: featuredTip.icon,
              ),
              const SizedBox(height: 18),
              const TipsCategoryChips(),

              // ─── AI TASKS SECTION ─────────────────────────────
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Nhiệm vụ từ AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2DF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 12,
                              color: Color(0xFF9D6C1F),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              healthData.isGeminiConfigured
                                  ? 'Gemini'
                                  : 'Fallback',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9D6C1F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Hiển thị số nhiệm vụ đã hoàn thành / tổng
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: healthData.allTasksCompleted
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.textHint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${healthData.completedTaskCount}/${activeTasks.length} hoàn thành',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: healthData.allTasksCompleted
                            ? AppColors.primary
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Error message
              if (healthData.aiTasksError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          healthData.aiTasksError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading skeleton
              if (healthData.isLoadingAiTasks && activeTasks.isEmpty)
                ..._buildLoadingSkeletons()
              // AI Task Cards
              else if (activeTasks.isEmpty)
                _buildEmptyState()
              else
                ...activeTasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AiTaskCard(
                      task: task,
                      onComplete: task.isCompleted
                          ? null
                          : () => context
                              .read<HealthProvider>()
                              .completeAiTask(task.id),
                    ),
                  ),
                ),

              // ─── RULE-BASED TIPS ──────────────────────────────
              const SizedBox(height: 20),
              const TipsSectionHeader(
                title: 'Gợi ý theo mục tiêu',
                actionLabel: 'Cập nhật mới',
              ),
              const SizedBox(height: 10),
              ...tipItems.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TipActionCard(item: tip),
                ),
              ),
              const SizedBox(height: 8),
              const TipsSectionHeader(
                title: 'Thói quen nhỏ',
                actionLabel: 'Hôm nay',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TipsMiniHabitCard(
                      gifAssetPath: AppGifIcons.water,
                      icon: Icons.water_drop_rounded,
                      title: 'Uống nước',
                      subtitle: waterSubtitle,
                      color: AppColors.waterTint,
                      iconColor: AppColors.waterIcon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TipsMiniHabitCard(
                      gifAssetPath: AppGifIcons.sleep,
                      icon: Icons.bedtime_rounded,
                      title: 'Giờ ngủ',
                      subtitle: sleepSubtitle,
                      color: AppColors.sleepTint,
                      iconColor: AppColors.sleepIcon,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoadingSkeletons() {
    return List.generate(
      2,
      (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 96,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: const Column(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 36,
            color: AppColors.primary,
          ),
          SizedBox(height: 10),
          Text(
            'Đang chờ AI tạo nhiệm vụ...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '3 nhiệm vụ sẽ được tạo tự động mỗi ngày lúc 00:00.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI Task Card Widget ──────────────────────────────────────
class _AiTaskCard extends StatelessWidget {
  final TaskSuggestion task;
  final VoidCallback? onComplete;

  const _AiTaskCard({
    required this.task,
    required this.onComplete,
  });

  static const Map<String, IconData> _typeIcons = {
    'water': Icons.water_drop_rounded,
    'exercise': Icons.directions_walk_rounded,
    'rest': Icons.self_improvement_rounded,
    'sleep': Icons.bedtime_rounded,
    'general': Icons.auto_awesome_rounded,
  };

  static const Map<String, Color> _typeColors = {
    'water': AppColors.waterTint,
    'exercise': AppColors.primarySurface,
    'rest': AppColors.sleepTint,
    'sleep': AppColors.sleepTint,
    'general': AppColors.fireTint,
  };

  static const Map<String, Color> _typeIconColors = {
    'water': AppColors.waterIcon,
    'exercise': AppColors.primary,
    'rest': AppColors.sleepIcon,
    'sleep': AppColors.sleepIcon,
    'general': AppColors.fireIcon,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[task.type] ?? Icons.auto_awesome_rounded;
    final bgColor = _typeColors[task.type] ?? AppColors.fireTint;
    final iconColor = _typeIconColors[task.type] ?? AppColors.fireIcon;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: task.isCompleted ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C121E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7B56D), width: 1.5),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121B2B), Color(0xFF090E18)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon theo type
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            // Nội dung
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF4E2B6),
                          ),
                        ),
                      ),
                      // EXP Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '+${task.expReward} EXP',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFFB6A27A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.0),
                        ),
                        child: Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                        ),
                      ),
                      // Action buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!task.isCompleted)
                            GestureDetector(
                              onTap: onComplete,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD7B56D),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD7B56D)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_rounded,
                                      size: 12,
                                      color: Colors.black87,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Hoàn thành',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24, width: 1.0),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 12,
                                    color: Colors.white38,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Đã xong',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
