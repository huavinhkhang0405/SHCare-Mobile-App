import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gif_icon.dart';
import '../../../core/config/app_localizations.dart';

class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({
    super.key,
    required this.score,
    required this.message,
  });

  final int score;
  final String message;

  String _getLocalizedScoreMessage(BuildContext context, String msg) {
    if (msg == 'Thể trạng hôm nay rất ấn tượng. Hãy giữ nhịp này!') {
      return context.tr('score_message_very_good');
    }
    if (msg == 'Sự hồi phục của bạn hôm nay đang đi đúng hướng.') {
      return context.tr('score_message_good');
    }
    if (msg == 'Cơ thể đang cần thêm nghỉ ngơi và bù nước.') {
      return context.tr('score_message_needs_rest');
    }
    if (msg == 'Hãy chú ý điều chỉnh nhịp sinh hoạt hôm nay nhé.') {
      return context.tr('score_message_poor');
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('health_index'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    text: '$score',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    children: const [
                      TextSpan(
                        text: '/100',
                        style:
                            TextStyle(fontSize: 20, color: Color(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getLocalizedScoreMessage(context, message),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const GifIcon(
              assetPath: AppGifIcons.tips,
              fallbackIcon: Icons.auto_awesome,
              fallbackColor: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}
