import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/audio_provider.dart';

class MusicPlayButton extends StatefulWidget {
  const MusicPlayButton({super.key});

  @override
  State<MusicPlayButton> createState() => _MusicPlayButtonState();
}

class _MusicPlayButtonState extends State<MusicPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _syncAnimation(bool isPlaying) {
    if (isPlaying) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
      return;
    }

    if (_animationController.isAnimating) {
      _animationController.stop();
    }
    if (_animationController.value != 0) {
      _animationController.value = 0;
    }
  }

  List<double> _waveHeights(double phase) {
    return List<double>.generate(3, (index) {
      final value = (1 + math.sin((phase * math.pi * 2) + (index * 0.55))) / 2;
      return 4 + (value * 8);
    });
  }

  Future<void> _handlePlayPause(
    BuildContext context,
    AudioProvider audioData,
  ) async {
    if (audioData.isPlaying) {
      await audioData.pauseMusic();
      return;
    }

    await audioData.playMusic();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.volume_up, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Dang phat nhac. Hay kiem tra am luong thiet bi neu ban khong nghe thay tieng nhe!',
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF18715A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioData = context.watch<AudioProvider>();
    _syncAnimation(audioData.isPlaying);

    return GestureDetector(
      onTap: () => _handlePlayPause(context, audioData),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          final phase = _animationController.value;
          final floatY = audioData.isPlaying
              ? -2 * math.sin(phase * math.pi * 2)
              : 0.0;
          final orbitAngle = phase * math.pi * 2;
          final orbitX = 24 + (math.cos(orbitAngle) * 15);
          final orbitY = 24 + (math.sin(orbitAngle) * 15);
          final waveHeights = _waveHeights(phase);

          return Transform.translate(
            offset: Offset(0, floatY),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: audioData.isPlaying
                          ? const Color(0xFF18715A).withValues(alpha: 0.14)
                          : const Color(0xFF18715A),
                      border: Border.all(
                        color: const Color(0xFF18715A),
                        width: audioData.isPlaying ? 1.4 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF18715A).withValues(
                            alpha: audioData.isPlaying ? 0.28 : 0.18,
                          ),
                          blurRadius: audioData.isPlaying ? 12 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          audioData.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: audioData.isPlaying
                              ? const Color(0xFF18715A)
                              : Colors.white,
                          size: 22,
                        ),
                        if (audioData.isPlaying)
                          Positioned(
                            bottom: 8,
                            child: Row(
                              children: List<Widget>.generate(3, (index) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.2,
                                  ),
                                  width: 2.6,
                                  height: waveHeights[index],
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF18715A),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (audioData.isPlaying)
                    Positioned(
                      left: orbitX - 3.5,
                      top: orbitY - 3.5,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF18715A),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
