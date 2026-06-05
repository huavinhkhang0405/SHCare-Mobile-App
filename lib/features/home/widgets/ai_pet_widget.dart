import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pet_aura_effect.dart';

enum PetAnimState { idle, attack, levelUp, sleeping, walking }

class AIPetWidget extends StatefulWidget {
  final String petState;
  final int classType;
  final int level;
  final bool isLevelUp;
  final String userName; // Đã thêm biến userName

  const AIPetWidget({
    super.key,
    required this.petState,
    this.classType = 4,
    this.level = 1,
    this.isLevelUp = false,
    this.userName = 'Khang', // Mặc định nếu không truyền
  });

  @override
  State<AIPetWidget> createState() => _AIPetWidgetState();
}

class _AIPetWidgetState extends State<AIPetWidget>
    with TickerProviderStateMixin {
  static const double _groundOffset = 6.0;
  late AnimationController _idleCtrl;
  late AnimationController _breathCtrl;
  late AnimationController _attackCtrl;
  late AnimationController _levelUpCtrl;
  late AnimationController _sleepCtrl;
  late AnimationController _walkCtrl;

  late Animation<double> _floatY;
  late Animation<double> _breathScale;
  late Animation<double> _attackX;
  late Animation<double> _attackRotate;
  late Animation<double> _jumpY;
  late Animation<double> _jumpScale;
  late Animation<double> _sleepTilt;
  late Animation<double> _walkX;

  PetAnimState _currentState = PetAnimState.idle;
  final List<_StarParticle> _stars = [];

  // --- CÁC BIẾN QUẢN LÝ CÂU THOẠI & TỘC HỆ ---
  List<String> _cachedThoughts = [];
  String _currentThought = 'Đang cảm nhận năng lượng...';

  static const Map<int, String> _classVietnameseNames = {
    1: 'Chiến binh',
    2: 'Cung thủ',
    3: 'Sát thủ',
    4: 'Pháp sư',
    5: 'Hiệp sĩ',
    6: 'Pháp sư gọi hồn',
    7: 'Cuồng chiến',
    8: 'Tu sĩ',
  };

  static const Map<int, String> _sprites = {
    1: 'assets/images/sprites/sprite_r01_c01.png',
    2: 'assets/images/sprites/sprite_r02_c01.png',
    3: 'assets/images/sprites/sprite_r03_c01.png',
    4: 'assets/images/sprites/sprite_r04_c01.png',
    5: 'assets/images/sprites/sprite_r05_c01.png',
    6: 'assets/images/sprites/sprite_r06_c01.png',
    7: 'assets/images/sprites/sprite_r07_c01.png',
    8: 'assets/images/sprites/sprite_r08_c01.png',
  };

  String get _spriteAsset =>
      _sprites[widget.classType.clamp(1, 8)] ?? _sprites[4]!;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupAnimations();
    _startIdleAnimations();
    _checkPetState();
    _loadThoughtsFromJson(); // Load câu nói từ JSON
  }

  // Đọc file JSON để lấy câu nói nhàn rỗi (idle/encouragement)
  Future<void> _loadThoughtsFromJson() async {
    try {
      final String response =
          await rootBundle.loadString('assets/data/quotes.json');
      final data = json.decode(response);
      final List<dynamic> quotesList = data['quotes'];

      if (mounted) {
        setState(() {
          _cachedThoughts = quotesList
              .where((q) =>
                  q['event_type'] == 'encouragement' ||
                  q['event_type'] == 'greeting')
              .map((q) => q['text'] as String)
              .toList();
          _generateNewThought();
        });
      }
    } catch (e) {
      debugPrint("🚨 Lỗi load quotes.json trong AIPetWidget: $e");
    }
  }

  // Sinh câu nói dựa trên trạng thái và class
  void _generateNewThought() {
    final random = Random();
    final className = _classVietnameseNames[widget.classType] ?? 'Chiến binh';
    final prefix = '$className ${widget.userName}';

    if (_currentState == PetAnimState.sleeping ||
        widget.petState.toLowerCase() == 'tired') {
      _currentThought = 'Zzz... $prefix đang sạc năng lượng...';
      return;
    }

    if (_currentState == PetAnimState.levelUp) {
      _currentThought = 'Woa! Năng lượng của $prefix đang bùng nổ!';
      return;
    }

    if (_currentState == PetAnimState.attack) {
      final attacks = [
        '$prefix xuất chiêu đây! Hyahhh!',
        'Đừng chọc mình nha!',
        'Trạng thái chiến đấu: Sẵn sàng!'
      ];
      _currentThought = attacks[random.nextInt(attacks.length)];
      return;
    }

    if (_cachedThoughts.isEmpty) {
      _currentThought =
          '$prefix ơi, mình cảm nhận được năng lượng quanh đây...';
    } else {
      String randomQuote =
          _cachedThoughts[random.nextInt(_cachedThoughts.length)];
      _currentThought = '$prefix! $randomQuote';
    }
  }

  void _setupControllers() {
    _idleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _breathCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400));
    _attackCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _levelUpCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _sleepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000));
    _walkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
  }

  void _setupAnimations() {
    _floatY = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut));

    _breathScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));

    _attackX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 28.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 28.0, end: -8.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _attackCtrl, curve: Curves.easeOut));

    _attackRotate = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.3, end: 0.1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _attackCtrl, curve: Curves.easeOut));

    _jumpY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -60.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: -60.0, end: -50.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -50.0, end: -60.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -60.0, end: 8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _levelUpCtrl, curve: Curves.easeInOut));

    _jumpScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _levelUpCtrl, curve: Curves.easeOut));

    _sleepTilt = Tween<double>(begin: -0.12, end: 0.12)
        .animate(CurvedAnimation(parent: _sleepCtrl, curve: Curves.easeInOut));

    _walkX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 30.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 30.0, end: 30.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 30.0, end: 0.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _walkCtrl, curve: Curves.easeInOut));
  }

  void _startIdleAnimations() {
    _idleCtrl.repeat(reverse: true);
    _breathCtrl.repeat(reverse: true);
  }

  void _checkPetState() {
    switch (widget.petState.toLowerCase()) {
      case 'tired':
      case 'sleeping':
        _playSleeping();
        break;
      case 'walking':
        _playWalking();
        break;
      default:
        setState(() {
          _currentState = PetAnimState.idle;
          _generateNewThought();
        });
    }
  }

  void _playAttack() {
    if (_currentState == PetAnimState.levelUp) return;
    setState(() {
      _currentState = PetAnimState.attack;
      _generateNewThought();
    });
    _attackCtrl.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _currentState = PetAnimState.idle;
          _generateNewThought();
        });
      }
    });
  }

  void _playLevelUp() {
    final rng = Random();
    setState(() {
      _currentState = PetAnimState.levelUp;
      _generateNewThought();
      _stars.clear();
      for (int i = 0; i < 12; i++) {
        _stars.add(
          _StarParticle(
            x: rng.nextDouble() * 200 - 100,
            y: rng.nextDouble() * -120 - 20,
            size: rng.nextDouble() * 8 + 4,
            color: [
              Colors.amberAccent,
              Colors.cyanAccent,
              Colors.pinkAccent,
              Colors.greenAccent,
            ][rng.nextInt(4)],
          ),
        );
      }
    });
    _levelUpCtrl.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _currentState = PetAnimState.idle;
          _generateNewThought();
          _stars.clear();
        });
      }
    });
  }

  void _playSleeping() {
    setState(() {
      _currentState = PetAnimState.sleeping;
      _generateNewThought();
    });
    _sleepCtrl.repeat(reverse: true);
  }

  void _playWalking() {
    setState(() => _currentState = PetAnimState.walking);
    _walkCtrl.repeat();
  }

  void _stopSpecialAnimations() {
    _sleepCtrl.stop();
    _walkCtrl.stop();
  }

  @override
  void didUpdateWidget(covariant AIPetWidget old) {
    super.didUpdateWidget(old);
    if (widget.isLevelUp && !old.isLevelUp) _playLevelUp();
    if (widget.petState != old.petState ||
        widget.userName != old.userName ||
        widget.classType != old.classType) {
      _stopSpecialAnimations();
      _checkPetState();
    }
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _breathCtrl.dispose();
    _attackCtrl.dispose();
    _levelUpCtrl.dispose();
    _sleepCtrl.dispose();
    _walkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _playAttack,
      child: SizedBox(
        height: 250,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (_stars.isNotEmpty)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _levelUpCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _StarPainter(
                      stars: _stars,
                      progress: _levelUpCtrl.value,
                    ),
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: Listenable.merge([
                _idleCtrl,
                _breathCtrl,
                _attackCtrl,
                _levelUpCtrl,
                _sleepCtrl,
                _walkCtrl,
              ]),
              builder: (context, child) {
                double ty = _groundOffset + _floatY.value * 0.4;
                double tx = 0;
                double rot = 0;
                double scale = _breathScale.value;

                switch (_currentState) {
                  case PetAnimState.attack:
                    tx = _attackX.value;
                    rot = _attackRotate.value;
                    break;
                  case PetAnimState.levelUp:
                    ty = _groundOffset + _jumpY.value + _floatY.value * 0.2;
                    scale = _jumpScale.value;
                    break;
                  case PetAnimState.sleeping:
                    rot = _sleepTilt.value;
                    ty = _groundOffset + _floatY.value * 0.2;
                    break;
                  case PetAnimState.walking:
                    tx = _walkX.value;
                    ty = _groundOffset + sin(_walkCtrl.value * pi * 6) * 1.5;
                    break;
                  case PetAnimState.idle:
                    break;
                }

                return Transform.translate(
                  offset: Offset(tx, ty),
                  child: Transform.rotate(
                    angle: rot,
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: -64,
                      child: _PetThoughtBubble(
                        text: _currentThought, // Đã liên kết với biến sinh câu nói
                        level: widget.level,
                      ),
                    ),
                    AuraEffect(
                      classRow: widget.classType,
                      level: widget.level,
                      child: Image.asset(
                        _spriteAsset,
                        height: 140,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 100,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    if (_currentState == PetAnimState.sleeping)
                      AnimatedBuilder(
                        animation: _sleepCtrl,
                        builder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Opacity(
                            opacity: sin(_sleepCtrl.value * pi).clamp(0.3, 1.0),
                            child: Transform.translate(
                              offset: Offset(8, -16 * _sleepCtrl.value),
                              child: Text(
                                'z' *
                                    ((_sleepCtrl.value * 3).floor().clamp(
                                      1,
                                      3,
                                    )),
                                style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _LevelBadge(level: widget.level),
            ),
            if (_currentState != PetAnimState.idle)
              Positioned(
                top: 12,
                right: 12,
                child: _StateBadge(
                  petState: widget.petState,
                  animState: _currentState,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StarParticle {
  final double x;
  final double y;
  final double size;
  final Color color;

  const _StarParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
  });
}

class _StarPainter extends CustomPainter {
  final List<_StarParticle> stars;
  final double progress;

  const _StarPainter({required this.stars, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final dx = s.x * progress * 0.5;
      final dy = s.y * progress;
      paint.color = s.color.withOpacity(opacity);
      final px = cx + dx + s.x * 0.3;
      final py = cy + dy;
      final sz = s.size * (1 - progress * 0.4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(px, py), width: sz, height: sz * 0.4),
        paint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(px, py), width: sz * 0.4, height: sz),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.progress != progress;
}

class _StateBadge extends StatelessWidget {
  final String petState;
  final PetAnimState animState;

  const _StateBadge({required this.petState, required this.animState});

  (IconData, Color, String) get _info {
    if (animState == PetAnimState.attack) {
      return (Icons.flash_on, Colors.orangeAccent, 'Attack!');
    }
    if (animState == PetAnimState.levelUp) {
      return (Icons.star, Colors.amberAccent, 'Level Up!');
    }
    if (animState == PetAnimState.sleeping) {
      return (Icons.bedtime, Colors.lightBlueAccent, 'Ngủ...');
    }
    switch (petState.toLowerCase()) {
      case 'happy':
        return (Icons.sentiment_very_satisfied, Colors.greenAccent, 'Vui');
      case 'tired':
        return (Icons.battery_alert, Colors.orangeAccent, 'Mệt');
      case 'thirsty':
        return (Icons.water_drop_outlined, Colors.lightBlueAccent, 'Khát');
      case 'walking':
        return (Icons.directions_walk, Colors.tealAccent, 'Đi bộ');
      default:
        return (Icons.auto_awesome, Colors.white70, 'Idle');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;

  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D1C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF9FD98C), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Lv $level',
        style: const TextStyle(
          color: Color(0xFFDCF4C2),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PetThoughtBubble extends StatelessWidget {
  final String text;
  final int level;

  const _PetThoughtBubble({required this.text, required this.level});

  (Color, Color, Color) _tone() {
    if (level < 10) {
      return (
        const Color(0xFFF2E7D2),
        const Color(0xFF6B5A3A),
        const Color(0xFF3E3523),
      );
    }
    if (level < 20) {
      return (
        const Color(0xFFE7F6E0),
        const Color(0xFF2F6B4B),
        const Color(0xFF1D3E2C),
      );
    }
    if (level < 40) {
      return (
        const Color(0xFFE6F2FF),
        const Color(0xFF2D5F8F),
        const Color(0xFF1B3854),
      );
    }
    if (level < 60) {
      return (
        const Color(0xFFF7E8FF),
        const Color(0xFF6B3A8F),
        const Color(0xFF3A1C52),
      );
    }
    return (
      const Color(0xFFFFF1CC),
      const Color(0xFF8A5A12),
      const Color(0xFF4A2C0A),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, _) = _tone();
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 220), // Giới hạn độ dài bong bóng
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center, // Căn giữa nội dung JSON
            style: const TextStyle(
              color: Color(0xFF3E3523),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
        Positioned(
          bottom: -6,
          child: CustomPaint(
            size: const Size(14, 8),
            painter: _ThoughtTailPainter(),
          ),
        ),
      ],
    );
  }
}

class _ThoughtTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF4EEDB)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFF6B5A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_ThoughtTailPainter oldDelegate) => false;
}