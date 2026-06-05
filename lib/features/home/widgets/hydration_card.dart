import 'package:flutter/material.dart';

import '../../../core/widgets/gif_icon.dart';

class HydrationCard extends StatelessWidget {
  final double liters;
  final int percentage;

  const HydrationCard({
    super.key,
    required this.liters,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFA0CDFC).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const GifIcon(
                assetPath: AppGifIcons.water,
                fallbackIcon: Icons.water_drop,
                fallbackColor: Color(0xFF396891),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Color(0xFF0D456D),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nước uống',
                style: TextStyle(
                  color: Color(0xFF0D456D),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              RichText(
                text: TextSpan(
                  text: '$liters ',
                  style: const TextStyle(
                    color: Color(0xFF0D456D),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  children: const [
                    TextSpan(
                      text: 'L',
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
