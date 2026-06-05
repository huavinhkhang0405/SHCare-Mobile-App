import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'rpg_pixel_background.dart';

enum FantasyEnvironmentEffect { none, levelUp, taskCompleted }

class FantasyEnvironment extends StatelessWidget {
  final int classType; // Mã tộc hệ (1: Warrior, 4: Mage,...)
  final int level; // Level hiện tại của pet
  final FantasyEnvironmentEffect effect;
  final Widget petWidget; // Truyền AIPetWidget vào đây

  const FantasyEnvironment({
    super.key,
    required this.classType,
    required this.level,
    this.effect = FantasyEnvironmentEffect.none,
    required this.petWidget,
  });

  String _resolveVfxAsset() {
    switch (effect) {
      case FantasyEnvironmentEffect.levelUp:
        return 'assets/lottie/Magic_Dust.json';
      case FantasyEnvironmentEffect.taskCompleted:
        return 'assets/lottie/Floating_Hearts.json';
      case FantasyEnvironmentEffect.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vfxLottie = _resolveVfxAsset();

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // LỚP 1: Nền phong cảnh tĩnh
            Positioned.fill(
              child: CustomPaint(painter: RpgPixelBackground(level: level)),
            ),

            // LỚP 2: Hiệu ứng Lottie (bay lơ lửng)
            if (vfxLottie.isNotEmpty)
              Positioned.fill(
                child: Lottie.asset(
                  vfxLottie,
                  fit: BoxFit.cover,
                  repeat: true, // Lặp lại liên tục tạo sự sống động
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),

            // LỚP 3: Con Pet Rive (Nằm ở trên cùng)
            Positioned(
              bottom: -15, // Căn chỉnh lại vị trí chân Pet cho khớp với nền đất
              left: 0,
              right: 0,
              child: petWidget,
            ),
          ],
        ),
      ),
    );
  }
}
