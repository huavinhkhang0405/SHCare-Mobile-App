import 'package:flutter/material.dart';

import '../../../core/widgets/gif_icon.dart';

class HeartRateCard extends StatelessWidget {
  final int bpm;

  const HeartRateCard({super.key, required this.bpm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD9E4), // Màu secondary-container từ HTML gốc
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const GifIcon(
              assetPath: AppGifIcons.heart,
              fallbackIcon: Icons.favorite,
              fallbackColor: Color(0xFF8B5468),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'NHỊP TIM',
                style: TextStyle(
                  color: Color(0xFF764255),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              RichText(
                text: TextSpan(
                  text: '$bpm ',
                  style: const TextStyle(
                    color: Color(0xFF764255),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  children: const [
                    TextSpan(
                      text: 'bpm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
