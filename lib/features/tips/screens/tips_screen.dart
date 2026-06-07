import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../models/task_suggestion.dart';
import '../../home/providers/health_provider.dart';
import '../widgets/featured_tip_card.dart';
import '../widgets/tips_sections.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  String? _selectedCategory;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    context.select<SettingsProvider, (int, String)>((p) => (p.themeColorHex, p.languageCode));
    final healthData = context.watch<HealthProvider>();

    final categoryAll = context.tr('category_all');
    _selectedCategory ??= categoryAll;

    // Get all tip items based on user's dynamic metrics
    final tipItems = buildTipItems(
      context: context,
      steps: healthData.steps,
      goal: healthData.goal,
      waterPercentage: healthData.waterPercentage,
      bpm: healthData.bpm,
      energyLevel: healthData.energyLevel,
    );

    // Filter tip items based on category and search
    final filteredTipItems = tipItems.where((tip) {
      final matchesCategory = _selectedCategory == categoryAll || tip.category == _selectedCategory;
      final matchesSearch = tip.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tip.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    // Get featured tip from filtered list (or original list if empty)
    final featuredTip = filteredTipItems.isNotEmpty
        ? filteredTipItems.first
        : (tipItems.isNotEmpty ? tipItems.first : null);

    final waterSubtitle = healthData.remainingWaterGlasses == 0
        ? context.tr('tips_water_goal_met')
        : context.tr('tips_water_remaining').replaceAll('{count}', '${healthData.remainingWaterGlasses}');
    final sleepSubtitle = healthData.energyLevel < 0.55
        ? context.tr('tips_sleep_early')
        : context.tr('tips_sleep_maintain');

    // Get and filter AI tasks based on category and search
    final activeTasks = healthData.aiTasks;
    final filteredTasks = activeTasks.where((task) {
      final matchesCategory = _selectedCategory == categoryAll || task.category == _selectedCategory;
      final matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          task.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

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
              TipsSearchBar(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (featuredTip != null)
                FeaturedTipCard(
                  title: featuredTip.title,
                  description: featuredTip.description,
                  ctaLabel: context.tr('tips_do_now'),
                  gifAssetPath: featuredTip.gifAssetPath,
                  icon: featuredTip.icon,
                ),
              const SizedBox(height: 18),
              TipsCategoryChips(
                selectedCategory: _selectedCategory!,
                onCategorySelected: (cat) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
              ),

              // ─── AI TASKS SECTION ─────────────────────────────
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        context.tr('ai_tasks'),
                        style: const TextStyle(
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: healthData.allTasksCompleted
                          ? Color(AppColors.primaryHex).withValues(alpha: 0.15)
                          : AppColors.textHint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr('tasks_completed_count').replaceAll('{count}', '${healthData.completedTaskCount}/${activeTasks.length}'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: healthData.allTasksCompleted
                            ? Color(AppColors.primaryHex)
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

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

              if (healthData.isLoadingAiTasks && activeTasks.isEmpty)
                ..._buildLoadingSkeletons()
              else if (filteredTasks.isEmpty)
                _buildEmptyState()
              else
                ...filteredTasks.map(
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
              TipsSectionHeader(
                title: context.tr('target_tips'),
                actionLabel: context.tr('tips_updated'),
              ),
              const SizedBox(height: 10),
              if (filteredTipItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Text(
                    context.tr('tips_no_results'),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              else
                ...filteredTipItems.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TipActionCard(item: tip),
                  ),
                ),
              const SizedBox(height: 8),
              TipsSectionHeader(
                title: context.tr('mini_habits'),
                actionLabel: context.tr('tips_today'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TipsMiniHabitCard(
                      gifAssetPath: AppGifIcons.water,
                      icon: Icons.water_drop_rounded,
                      title: context.tr('water'),
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
                      title: context.tr('last_night_sleep'),
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
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(AppColors.primaryHex),
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
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 36,
            color: Color(AppColors.primaryHex),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('tips_no_tasks'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? context.tr('tips_try_other_keyword')
                : context.tr('tips_try_other_category'),
            style: const TextStyle(
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
    final bgColor = Color((_typeColors[task.type] ?? AppColors.fireTint).value);
    final iconColor = Color((_typeIconColors[task.type] ?? AppColors.fireIcon).value);

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
            // Icon by type
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
            // Content
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 12,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      context.tr('completed_label'),
                                      style: const TextStyle(
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 12,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    context.tr('well_done'),
                                    style: const TextStyle(
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
