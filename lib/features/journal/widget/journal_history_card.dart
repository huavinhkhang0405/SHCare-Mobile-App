import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
  Map<String, dynamic> _getMoodConfig(int index) {
    switch (index) {
      case 0:
        return {
          'emoji': '😄',
          'label': 'Rất tốt',
          'bgColor': const Color(0xFFE7F7EE),
          'textColor': const Color(0xFF1B5E20),
        };
      case 1:
        return {
          'emoji': '🙂',
          'label': 'Ổn định',
          'bgColor': const Color(0xFFEAF5FF),
          'textColor': const Color(0xFF0D47A1),
        };
      case 2:
        return {
          'emoji': '😐',
          'label': 'Bình thường',
          'bgColor': const Color(0xFFFFF4E4),
          'textColor': const Color(0xFFE65100),
        };
      case 3:
      default:
        return {
          'emoji': '😣',
          'label': 'Căng thẳng',
          'bgColor': const Color(0xFFFFEBEC),
          'textColor': const Color(0xFFB71C1C),
        };
    }
  }

  String _formatDate(DateTime date) {
    final weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật'
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
        backgroundColor: const Color(0xFF111827), // Nền tối ăn khớp login screen
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Xác nhận xóa',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa nhật ký sức khỏe của ngày này không? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
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
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moodCfg = _getMoodConfig(entry.moodIndex);
    final formattedDate = _formatDate(entry.date);

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
                            'Năng lượng: ${(entry.energyLevel * 100).round()}%',
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
                            label: 'bước',
                          ),
                          _buildVitalItem(
                            width: itemWidth,
                            icon: Icons.local_drink_rounded,
                            iconColor: AppColors.waterIcon,
                            value: '${(entry.waterIntakeLiters).toStringAsFixed(1)}L',
                            label: 'nước',
                          ),
                          _buildVitalItem(
                            width: itemWidth,
                            icon: Icons.nights_stay_rounded,
                            iconColor: Colors.deepPurpleAccent,
                            value: '${entry.sleepMinutes ~/ 60}h${entry.sleepMinutes % 60}m',
                            label: 'ngủ',
                          ),
                          _buildVitalItem(
                            width: itemWidth,
                            icon: Icons.restaurant_menu_rounded,
                            iconColor: Colors.orangeAccent,
                            value: '${entry.consumedCalories}',
                            label: 'kcal nạp',
                          ),
                        ],
                      );
                    },
                  ),

                  // Triệu chứng nhẹ (Nếu có)
                  if (entry.symptoms.isNotEmpty &&
                      !entry.symptoms.contains('Không có')) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Triệu chứng ghi nhận:',
                      style: TextStyle(
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
                        const Text(
                          'Món ăn đã nạp:',
                          style: TextStyle(
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
                            color: AppColors.primarySurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            food,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
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
                                color: AppColors.primary.withValues(alpha: 0.5),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Ghi chú',
                                style: TextStyle(
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
