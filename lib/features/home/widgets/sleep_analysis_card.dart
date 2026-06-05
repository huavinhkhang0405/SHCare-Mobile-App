import 'package:flutter/material.dart';

import '../../../core/widgets/gif_icon.dart';

class SleepAnalysisCard extends StatelessWidget {
  const SleepAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFCC), // surface-container-high
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTag(),
                const SizedBox(height: 16),
                Text(
                  '7h 45m',
                  style: textTheme.displayLarge?.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Giấc ngủ sâu của bạn ổn định hơn 15% so với tuần trước.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bar(0.5),
                  _bar(0.65),
                  _bar(0.75),
                  _bar(1.0, isHigh: true),
                  _bar(0.8),
                  _bar(0.6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GifIcon(
            assetPath: AppGifIcons.sleep,
            fallbackIcon: Icons.dark_mode,
            fallbackColor: Color(0xFF396891),
            size: 14,
          ),
          SizedBox(width: 4),
          Text(
            'GIẤC NGỦ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF396891),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double height, {bool isHigh = false}) {
    return FractionallySizedBox(
      heightFactor: height,
      child: Container(
        width: 10,
        decoration: BoxDecoration(
          color: isHigh ? const Color(0xFF2C5C84) : const Color(0xFFA0CDFC),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
