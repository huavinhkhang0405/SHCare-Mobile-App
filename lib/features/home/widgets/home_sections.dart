import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../providers/health_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../utils/date_formatter.dart';
import '../../../models/home_plan_item.dart';
import '../../../models/recent_activity.dart';

class HomeTopGreeting extends StatefulWidget {
  const HomeTopGreeting({
    super.key,
    required this.name,
    this.onProfileTap,
  });

  final String name;
  final VoidCallback? onProfileTap;

  @override
  State<HomeTopGreeting> createState() => _HomeTopGreetingState();
}

class _HomeTopGreetingState extends State<HomeTopGreeting> {
  DateTime _now = DateFormatter.nowLocal();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateFormatter.nowLocal();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final greeting = DateFormatter.greetingVi(_now);
    final currentTime = DateFormatter.formatHourMinute(_now);
    
    final auth = context.watch<AuthProvider>();
    final healthData = context.watch<HealthProvider>();
    final pendingPlans = healthData.planItems.where((p) => !p.isCompleted).length;
    final pendingAiTasks = healthData.aiTasks.where((t) => !t.isCompleted).length;
    final totalPending = pendingPlans + pendingAiTasks;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${widget.name}',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bây giờ là $currentTime, bạn có $totalPending mục tiêu sức khỏe cần hoàn thành hôm nay.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onProfileTap ?? () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (BuildContext context) {
                return const ProfileActionsBottomSheet();
              },
            );
          },
          child: (auth.currentUser?.avatarUrl != null && auth.currentUser!.avatarUrl!.trim().isNotEmpty)
              ? UserAvatar(
                  avatarUrl: auth.currentUser!.avatarUrl,
                  size: 44,
                  borderRadius: 14,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: GifIcon(
                      assetPath: AppGifIcons.profile,
                      fallbackIcon: Icons.person_rounded,
                      fallbackColor: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class HomeDailySummaryCard extends StatefulWidget {
  const HomeDailySummaryCard({
    super.key,
    required this.steps,
    required this.goal,
    required this.progress,
    required this.remainingSteps,
  });

  final int steps;
  final int goal;
  final double progress;
  final int remainingSteps;

  @override
  State<HomeDailySummaryCard> createState() => _HomeDailySummaryCardState();
}

class _HomeDailySummaryCardState extends State<HomeDailySummaryCard> {
  DateTime _now = DateFormatter.nowLocal();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateFormatter.nowLocal();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        gradient: AppColors.heroGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng quan hôm nay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  DateFormatter.formatDayMonthWithWeekday(_now),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${widget.steps} bước',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Còn ${widget.remainingSteps} bước để đạt mục tiêu ${widget.goal} bước.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: widget.progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.23),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(widget.progress * 100).round()}% hoàn thành',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeQuickMetricCard extends StatelessWidget {
  const HomeQuickMetricCard({
    super.key,
    required this.icon,
    required this.gifAssetPath,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String gifAssetPath;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 36,
            height: 36,
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
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
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

class HomeSleepHighlightCard extends StatelessWidget {
  const HomeSleepHighlightCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.sleepTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const GifIcon(
                  assetPath: AppGifIcons.sleep,
                  fallbackIcon: Icons.nightlight_round,
                  fallbackColor: AppColors.sleepIcon,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giấc ngủ đêm qua',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${healthData.sleepDurationLabel} · Chất lượng ${healthData.sleepQuality}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
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
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class HomePlanListCard extends StatelessWidget {
  const HomePlanListCard({super.key});

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final List<HomePlanItem> planItems = healthData.planItems;

    if (planItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.softShadow,
        ),
        child: const Center(
          child: Text(
            'Không có lịch trình chăm sóc hôm nay.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

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
        children: List.generate(planItems.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const Divider(height: 20);
          }
          final planIndex = index ~/ 2;
          final item = planItems[planIndex];
          return _HomePlanItem(
            id: item.id,
            time: item.time,
            title: item.title,
            subtitle: item.subtitle,
            gifAssetPath: item.isCompleted ? AppGifIcons.check : item.gifAssetPath,
            icon: _mapIconNameToIconData(item.iconName),
            iconColor: Color(int.parse(item.iconColorHex, radix: 16)),
            isCompleted: item.isCompleted,
            onToggle: () {
              healthData.togglePlanItem(item.id);
            },
          );
        }),
      ),
    );
  }

  IconData _mapIconNameToIconData(String name) {
    switch (name) {
      case 'check_circle_rounded':
        return Icons.check_circle_rounded;
      case 'directions_walk_rounded':
        return Icons.directions_walk_rounded;
      case 'self_improvement_rounded':
        return Icons.self_improvement_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }
}

class _HomePlanItem extends StatelessWidget {
  const _HomePlanItem({
    required this.id,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.gifAssetPath,
    required this.icon,
    required this.iconColor,
    this.isCompleted = false,
    required this.onToggle,
  });

  final String id;
  final String time;
  final String title;
  final String subtitle;
  final String gifAssetPath;
  final IconData icon;
  final Color iconColor;
  final bool isCompleted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCompleted ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: isCompleted ? AppColors.primary : iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? AppColors.primary : AppColors.textHint,
                      fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeRecentActivityCard extends StatelessWidget {
  const HomeRecentActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final healthData = context.watch<HealthProvider>();
    final List<RecentActivity> activities = healthData.recentActivities;

    if (activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.softShadow,
        ),
        child: const Column(
          children: [
            Icon(Icons.history_rounded, color: AppColors.textHint, size: 24),
            SizedBox(height: 8),
            Text(
              'Chưa có hoạt động gần đây.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

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
        children: List.generate(activities.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const SizedBox(height: 12);
          }
          final actIndex = index ~/ 2;
          final act = activities[actIndex];
          return _HomeActivityTile(
            gifAssetPath: act.gifAssetPath,
            icon: _mapIconNameToIconData(act.iconName),
            title: act.title,
            subtitle: act.subtitle,
            trailing: act.trailing,
          );
        }),
      ),
    );
  }

  IconData _mapIconNameToIconData(String name) {
    switch (name) {
      case 'check_circle_rounded':
        return Icons.check_circle_rounded;
      case 'directions_walk_rounded':
        return Icons.directions_walk_rounded;
      case 'self_improvement_rounded':
        return Icons.self_improvement_rounded;
      case 'water_drop_rounded':
        return Icons.water_drop_rounded;
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      case 'nightlight_round':
        return Icons.nightlight_round;
      case 'star_rounded':
        return Icons.star_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }
}

class _HomeActivityTile extends StatelessWidget {
  const _HomeActivityTile({
    required this.gifAssetPath,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String gifAssetPath;
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: GifIcon(
            assetPath: gifAssetPath,
            fallbackIcon: icon,
            fallbackColor: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileActionsBottomSheet extends StatelessWidget {
  const ProfileActionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          // User avatar & info
          Row(
            children: [
              UserAvatar(
                avatarUrl: auth.currentUser?.avatarUrl,
                size: 60,
                borderRadius: 30,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auth.userEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 16),
          // Options
          _buildOptionTile(
            context,
            icon: Icons.person_outline_rounded,
            label: 'Thông tin cá nhân',
            color: AppColors.primary,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            context,
            icon: Icons.swap_horiz_rounded,
            label: 'Chuyển tài khoản',
            color: AppColors.accent,
            onTap: () {
              Navigator.of(context).pop();
              _showConfirmDialog(
                context,
                title: 'Chuyển tài khoản',
                content: 'Bạn có chắc chắn muốn đăng xuất để chuyển sang tài khoản khác?',
                confirmLabel: 'Chuyển tài khoản',
                confirmColor: AppColors.accent,
                onConfirm: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            context,
            icon: Icons.logout_rounded,
            label: 'Đăng xuất',
            color: AppColors.error,
            onTap: () {
              Navigator.of(context).pop();
              _showConfirmDialog(
                context,
                title: 'Đăng xuất',
                content: 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
                confirmLabel: 'Đăng xuất',
                confirmColor: AppColors.error,
                onConfirm: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: confirmColor),
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
