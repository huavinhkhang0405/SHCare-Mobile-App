import 'package:flutter/material.dart';

import '../../../core/widgets/gif_icon.dart';

class WaterIntakeBubble extends StatelessWidget {
  const WaterIntakeBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFA0CDFC).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            '1.8 L',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0D456D),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBtn(gifAssetPath: AppGifIcons.minus, icon: Icons.remove),
              const SizedBox(width: 24),
              _buildBtn(
                gifAssetPath: AppGifIcons.plus,
                icon: Icons.add,
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBtn({
    required String gifAssetPath,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF396891) : Colors.white,
        shape: BoxShape.circle,
      ),
      child: GifIcon(
        assetPath: gifAssetPath,
        fallbackIcon: icon,
        fallbackColor: isPrimary ? Colors.white : const Color(0xFF396891),
      ),
    );
  }
}
