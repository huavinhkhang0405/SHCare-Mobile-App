import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_localizations.dart';
import '../../../models/diary_entry.dart';

class JournalHistoryCard extends StatelessWidget {
  const JournalHistoryCard({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  final DiaryEntry entry;
  final VoidCallback onDelete;

  // Cấu hình hiển thị theo chỉ số tâm trạng
  Map<String, dynamic> _getMoodConfig(BuildContext context, int index) {
    switch (index) {
      case 0:
        return {
          'emoji': '😄',
          'label': context.tr('mood_very_good'),
          'bgColor': const Color(0xFFE7F7EE),
          'textColor': const Color(0xFF1B5E20),
        };
      case 1:
        return {
          'emoji': '🙂',
          'label': context.tr('mood_stable'),
          'bgColor': const Color(0xFFEAF5FF),
          'textColor': const Color(0xFF0D47A1),
        };
      case 2:
        return {
          'emoji': '😐',
          'label': context.tr('mood_normal'),
          'bgColor': const Color(0xFFFFF4E4),
          'textColor': const Color(0xFFE65100),
        };
      case 3:
      default:
        return {
          'emoji': '😣',
          'label': context.tr('mood_stressed'),
          'bgColor': const Color(0xFFFFEBEC),
          'textColor': const Color(0xFFB71C1C),
        };
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final weekdays = [
      context.tr('weekday_full_1'),
      context.tr('weekday_full_2'),
      context.tr('weekday_full_3'),
      context.tr('weekday_full_4'),
      context.tr('weekday_full_5'),
      context.tr('weekday_full_6'),
      context.tr('weekday_full_7'),
    ];
    final wDay = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$wDay, $day/$month/$year';
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF111827),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              context.tr('confirm_delete'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          context.tr('delete_diary_confirm_desc'),
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              context.tr('delete'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moodCfg = _getMoodConfig(context, entry.moodIndex);
    final formattedDate = _formatDate(context, entry.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Ngày và Nút xóa
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.scaffoldBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: () => _showDeleteConfirmation(context),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tâm trạng và Năng lượng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Pill tâm trạng
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: moodCfg['bgColor'],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (moodCfg['bgColor'] as Color)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              moodCfg['emoji'],
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              moodCfg['label'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: moodCfg['textColor'],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chỉ số năng lượng
                      Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${context.tr('energy_label')}: ${(entry.energyLevel * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chỉ số đo lường cơ bản (Vận động, Nước, Giấc ngủ, Calories nạp)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 24) / 4;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildVitalItem(
                            width: itemWidth,
                            icon: Icons.directions_walk_rounded,
                            iconColor: Colors.blueAccent,
                            value: '${entry.stepCount}',
                            label: context.tr('steps_unit'),
                          ),
                          _buildVitalItem(
                            width: itemWidth,
                            icon: Icons.local_drink_rounded,
                            iconColor: AppColors.waterIcon,
                            value: '${(entry.waterIntakeLiters).toStringAsFixed(1)}L',
                            label: context.tr('water_unit'),
                          ),
                          _buildVitalItem(
                            width: itemWidth,
                            icon: Icons.nights_stay_rounded,
                            iconColor: Colors.deepPurpleAccent,
                            value: '${entry.sleepMinutes ~/ 60}h${entry.sleepMinutes % 60}m',
                            label: context.tr('sleep_unit'),
                          ),
                          _buildVitalItem(
                            width: itemWidth,
                            icon: Icons.restaurant_menu_rounded,
                            iconColor: Colors.orangeAccent,
                            value: '${entry.consumedCalories}',
                            label: context.tr('calories_intake'),
                          ),
                        ],
                      );
                    },
                  ),

                  // Triệu chứng nhẹ (Nếu có)
                  if (entry.symptoms.isNotEmpty &&
                      !entry.symptoms.contains('Không có')) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.tr('recorded_symptoms'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.symptoms.map((symptom) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            symptom,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Dinh dưỡng và Món ăn đã nạp (Nếu có)
                  if (entry.todayFoods.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('consumed_foods'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHint,
                          ),
                        ),
                        // Micro Macros
                        Text(
                          'P: ${entry.consumedProtein}g  ·  C: ${entry.consumedCarbs}g  ·  F: ${entry.consumedFat}g',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.todayFoods.map((food) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(AppColors.primarySurfaceHex).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Color(AppColors.primaryHex).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            food,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(AppColors.primaryDarkHex),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Ghi chú nhanh (Nếu có)
                  if (entry.note != null && entry.note!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.cardBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                color: Color(AppColors.primaryHex).withValues(alpha: 0.5),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('note'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.note!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalItem({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textHint,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
