import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../utils/date_formatter.dart';

class HomeTopGreeting extends StatefulWidget {
  const HomeTopGreeting({super.key, required this.name});

  final String name;

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
                'Bây giờ là $currentTime, bạn có 3 mục tiêu sức khỏe cần hoàn thành hôm nay.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
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
          child: const GifIcon(
            assetPath: AppGifIcons.profile,
            fallbackIcon: Icons.person_rounded,
            fallbackColor: Colors.white,
            size: 24,
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giấc ngủ đêm qua',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '7h 45m · Chất lượng tốt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: const Column(
        children: [
          _HomePlanItem(
            time: '08:00',
            title: 'Uống nước đầu ngày',
            subtitle: 'Hoàn thành',
            gifAssetPath: AppGifIcons.check,
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.primary,
            isCompleted: true,
          ),
          Divider(height: 20),
          _HomePlanItem(
            time: '12:30',
            title: 'Đi bộ 15 phút',
            subtitle: 'Sắp đến giờ',
            gifAssetPath: AppGifIcons.walk,
            icon: Icons.directions_walk_rounded,
            iconColor: AppColors.accent,
          ),
          Divider(height: 20),
          _HomePlanItem(
            time: '22:00',
            title: 'Tập thở sâu 5 phút',
            subtitle: 'Nhắc nhở',
            gifAssetPath: AppGifIcons.meditate,
            icon: Icons.self_improvement_rounded,
            iconColor: AppColors.sleepIcon,
          ),
        ],
      ),
    );
  }
}

class _HomePlanItem extends StatelessWidget {
  const _HomePlanItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.gifAssetPath,
    required this.icon,
    required this.iconColor,
    this.isCompleted = false,
  });

  final String time;
  final String title;
  final String subtitle;
  final String gifAssetPath;
  final IconData icon;
  final Color iconColor;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: GifIcon(
            assetPath: gifAssetPath,
            fallbackIcon: icon,
            fallbackColor: iconColor,
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
    );
  }
}

class HomeRecentActivityCard extends StatelessWidget {
  const HomeRecentActivityCard({super.key});

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
      child: const Column(
        children: [
          _HomeActivityTile(
            gifAssetPath: AppGifIcons.route,
            icon: Icons.route_rounded,
            title: 'Bạn vừa đi bộ',
            subtitle: '2.1 km trong 28 phút',
            trailing: '+132 kcal',
          ),
          SizedBox(height: 12),
          _HomeActivityTile(
            gifAssetPath: AppGifIcons.water,
            icon: Icons.water_drop_rounded,
            title: 'Đã cập nhật nước uống',
            subtitle: 'Thêm 250 ml vào mục tiêu ngày',
            trailing: '14:10',
          ),
        ],
      ),
    );
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
