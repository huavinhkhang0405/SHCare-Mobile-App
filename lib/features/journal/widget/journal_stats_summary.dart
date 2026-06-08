import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/diary_entry.dart';

class JournalStatsSummary extends StatelessWidget {
  const JournalStatsSummary({
    super.key,
    required this.history,
  });

  final List<DiaryEntry> history;

  // Cấu hình hiển thị theo chỉ số tâm trạng
  Map<String, String> _getMoodEmojiAndLabel(int index) {
    switch (index) {
      case 0:
        return {'emoji': '😄', 'label': 'Rất tốt'};
      case 1:
        return {'emoji': '🙂', 'label': 'Ổn định'};
      case 2:
        return {'emoji': '😐', 'label': 'Bình thường'};
      case 3:
      default:
        return {'emoji': '😣', 'label': 'Căng thẳng'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysCount = history.length;
    
    // Tính toán tâm trạng phổ biến nhất
    var dominantMoodEmoji = '➖';
    var dominantMoodLabel = 'Chưa rõ';
    if (daysCount > 0) {
      final Map<int, int> moodCounts = {};
      for (var entry in history) {
        moodCounts[entry.moodIndex] = (moodCounts[entry.moodIndex] ?? 0) + 1;
      }
      
      var maxCount = -1;
      var dominantIndex = 1;
      moodCounts.forEach((index, count) {
        if (count > maxCount) {
          maxCount = count;
          dominantIndex = index;
        }
      });
      final cfg = _getMoodEmojiAndLabel(dominantIndex);
      dominantMoodEmoji = cfg['emoji']!;
      dominantMoodLabel = cfg['label']!;
    }

    // Tính toán lượng nước trung bình
    var avgWater = 0.0;
    if (daysCount > 0) {
      final totalWater = history.fold<double>(0.0, (sum, entry) => sum + entry.waterIntakeLiters);
      avgWater = totalWater / daysCount;
    }

    // Tính toán mức năng lượng trung bình
    var avgEnergy = 0.0;
    if (daysCount > 0) {
      final totalEnergy = history.fold<double>(0.0, (sum, entry) => sum + entry.energyLevel);
      avgEnergy = totalEnergy / daysCount;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(AppColors.primaryHex).withValues(alpha: 0.15),
            Color(AppColors.primaryHex).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: Color(AppColors.primaryHex).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: Color(AppColors.primaryHex),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tổng quan sức khỏe (30 ngày qua)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(AppColors.primaryDarkHex),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  icon: Icons.calendar_month_rounded,
                  iconColor: Colors.teal,
                  value: '$daysCount',
                  label: 'Ngày ghi nhận',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  icon: Icons.mood_rounded,
                  iconColor: Colors.orange,
                  value: '$dominantMoodEmoji $dominantMoodLabel',
                  label: 'Tâm trạng chủ đạo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  icon: Icons.local_drink_rounded,
                  iconColor: AppColors.waterIcon,
                  value: '${avgWater.toStringAsFixed(1)}L / ngày',
                  label: 'Nước uống TB',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  icon: Icons.bolt_rounded,
                  iconColor: Colors.amber,
                  value: '${(avgEnergy * 100).round()}%',
                  label: 'Năng lượng TB',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
