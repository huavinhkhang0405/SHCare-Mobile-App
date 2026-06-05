import 'package:flutter/material.dart';

import '../../../core/widgets/gif_icon.dart';

class StepsCard extends StatelessWidget {
  final int steps;
  final int goal;

  const StepsCard({super.key, required this.steps, required this.goal});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (steps / goal).clamp(0.0, 1.0);

    return Container(
      height: 236,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GifIcon(
            assetPath: AppGifIcons.walk,
            fallbackIcon: Icons.directions_walk,
            fallbackColor: colorScheme.primary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Bước chân',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$steps',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 32,
            ),
          ),
          Text(
            'Mục tiêu: $goal',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
