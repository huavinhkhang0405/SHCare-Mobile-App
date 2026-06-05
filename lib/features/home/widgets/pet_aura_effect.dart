import 'dart:math';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  CÁCH DÙNG trong ai_pet_widget.dart:
//
//  1. Thêm AnimationController _auraCtrl vào _AIPetWidgetState
//  2. Wrap nhân vật trong AuraEffect widget:
//
//  AuraEffect(
//    classRow: widget.classType,  // 1–8
//    level: widget.level,
//    controller: _auraCtrl,
//    child: Image.asset(_spriteAsset, ...),
//  )
// ══════════════════════════════════════════════════════════════

// ── Thông tin aura theo từng tộc ────────────────────────────
class _ClassAura {
  final Color primary;
  final Color secondary;
  final String name;
  final _AuraType type;

  const _ClassAura({
    required this.primary,
    required this.secondary,
    required this.name,
    required this.type,
  });
}

enum _AuraType {
  fire, // r1 Warrior   – lửa bốc lên
  wind, // r2 Archer    – lá xoáy
  shadow, // r3 Rogue     – khói bóng tối
  arcane, // r4 Mage      – quỹ đạo arcane
  holy, // r5 Paladin   – tia thánh quang
  poison, // r6 Necro     – bong bóng độc
  thunder, // r7 Berserker – sấm sét
  divine, // r8 Priest    – vòng hào quang
}

const Map<int, _ClassAura> _classAuras = {
  1: _ClassAura(
    primary: Color(0xFFFF6B35),
    secondary: Color(0xFFFF3300),
    name: 'Warrior',
    type: _AuraType.fire,
  ),
  2: _ClassAura(
    primary: Color(0xFF56CC6E),
    secondary: Color(0xFF8FFF6E),
    name: 'Archer',
    type: _AuraType.wind,
  ),
  3: _ClassAura(
    primary: Color(0xFFA855F7),
    secondary: Color(0xFF7C3AED),
    name: 'Rogue',
    type: _AuraType.shadow,
  ),
  4: _ClassAura(
    primary: Color(0xFF38BDF8),
    secondary: Color(0xFF818CF8),
    name: 'Mage',
    type: _AuraType.arcane,
  ),
  5: _ClassAura(
    primary: Color(0xFFFFD700),
    secondary: Color(0xFFFFF7A1),
    name: 'Paladin',
    type: _AuraType.holy,
  ),
  6: _ClassAura(
    primary: Color(0xFF4ADE80),
    secondary: Color(0xFF064E3B),
    name: 'Necro',
    type: _AuraType.poison,
  ),
  7: _ClassAura(
    primary: Color(0xFFEF4444),
    secondary: Color(0xFFFACC15),
    name: 'Berserker',
    type: _AuraType.thunder,
  ),
  8: _ClassAura(
    primary: Color(0xFFF0ABFC),
    secondary: Color(0xFFFFFFFF),
    name: 'Priest',
    type: _AuraType.divine,
  ),
};

// ══════════════════════════════════════════════════════════════
//  WIDGET bọc ngoài nhân vật
// ══════════════════════════════════════════════════════════════
class AuraEffect extends StatefulWidget {
  final int classRow; // 1–8
  final int level;
  final Widget child; // sprite nhân vật

  const AuraEffect({
    super.key,
    required this.classRow,
    required this.level,
    required this.child,
  });

  @override
  State<AuraEffect> createState() => _AuraEffectState();
}

class _AuraEffectState extends State<AuraEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  final Random _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _particles = [];
    WidgetsBinding.instance.addPostFrameCallback((_) => _initParticles());
  }

  @override
  void didUpdateWidget(covariant AuraEffect old) {
    super.didUpdateWidget(old);
    if (old.classRow != widget.classRow || old.level != widget.level) {
      _initParticles();
    }
  }

  void _initParticles() {
    final count = _particleCount(widget.level);
    final aura = _classAuras[widget.classRow.clamp(1, 8)]!;
    _particles = List.generate(
      count,
      (i) => _Particle.spawn(i, count, aura, _rng, stagger: true),
    );
  }

  int _particleCount(int level) {
    if (level < 10) return 14;
    if (level < 20) return 24;
    if (level < 40) return 36;
    if (level < 60) return 48;
    return 64;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aura = _classAuras[widget.classRow.clamp(1, 8)]!;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        // Update particles mỗi frame
        for (int i = 0; i < _particles.length; i++) {
          _particles[i].update();
          if (_particles[i].isDead) {
            final total = _particles.length;
            _particles[i] = _Particle.spawn(i, total, aura, _rng);
          }
        }
        return CustomPaint(
          painter: _AuraPainter(
            particles: _particles,
            aura: aura,
            level: widget.level,
            tick: _ctrl.value,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PARTICLE
// ══════════════════════════════════════════════════════════════
class _Particle {
  double x, y, vx, vy;
  double life, maxLife;
  double size;
  Color color;
  _AuraType type;

  // Extra props
  double angle;
  double radius;
  double ringRadius;
  bool isRing;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
    required this.type,
    this.angle = 0,
    this.radius = 20,
    this.ringRadius = 0,
    this.isRing = false,
  });

  static const double _cx = 70.0; // center X của 140px sprite
  static const double _cy = 90.0; // center Y (hơi thấp hơn giữa)

  factory _Particle.spawn(
    int index,
    int total,
    _ClassAura aura,
    Random rng, {
    bool stagger = false,
  }) {
    final maxLife = 0.6 + rng.nextDouble() * 1.2;
    final life = stagger ? rng.nextDouble() * maxLife : 0.0;
    final color = rng.nextBool() ? aura.primary : aura.secondary;

    switch (aura.type) {
      // 🔥 FIRE – bốc lên từ chân
      case _AuraType.fire:
        return _Particle(
          x: _cx + (rng.nextDouble() - 0.5) * 40,
          y: _cy + 15 + rng.nextDouble() * 10,
          vx: (rng.nextDouble() - 0.5) * 0.8,
          vy: -(0.6 + rng.nextDouble() * 1.0),
          life: life,
          maxLife: maxLife,
          size: 3.0 + rng.nextDouble() * 4.0,
          color: color,
          type: aura.type,
        );

      // 🍃 WIND – xoáy quanh
      case _AuraType.wind:
        final a = rng.nextDouble() * pi * 2;
        final r = 20 + rng.nextDouble() * 30;
        return _Particle(
          x: _cx + cos(a) * r,
          y: _cy + sin(a) * r * 0.5,
          vx: -sin(a) * (0.5 + rng.nextDouble() * 0.8),
          vy: cos(a) * 0.3 - 0.4,
          life: life,
          maxLife: maxLife,
          size: 2.0 + rng.nextDouble() * 3.0,
          color: color,
          type: aura.type,
          angle: a,
          radius: r,
        );

      // 💜 SHADOW – khói bay lên
      case _AuraType.shadow:
        return _Particle(
          x: _cx + (rng.nextDouble() - 0.5) * 28,
          y: _cy + 10,
          vx: (rng.nextDouble() - 0.5) * 0.5,
          vy: -(0.3 + rng.nextDouble() * 0.6),
          life: life,
          maxLife: maxLife * 1.4,
          size: 4.0 + rng.nextDouble() * 5.0,
          color: color.withOpacity(0.7),
          type: aura.type,
        );

      // ✨ ARCANE – quỹ đạo
      case _AuraType.arcane:
        final a = (index / total) * pi * 2 + rng.nextDouble() * 0.5;
        final r = 25 + rng.nextDouble() * 20;
        return _Particle(
          x: _cx + cos(a) * r,
          y: _cy + sin(a) * r * 0.55,
          vx: -sin(a) * (0.7 + rng.nextDouble() * 0.5),
          vy: cos(a) * 0.4,
          life: life,
          maxLife: 1.5 + rng.nextDouble() * 0.5,
          size: 3.0 + rng.nextDouble() * 3.0,
          color: color,
          type: aura.type,
          angle: a,
          radius: r,
        );

      // ☀️ HOLY – tia tỏa ra
      case _AuraType.holy:
        final a = (index / total) * pi * 2;
        return _Particle(
          x: _cx,
          y: _cy,
          vx: cos(a) * (0.5 + rng.nextDouble() * 0.8),
          vy: sin(a) * (0.4 + rng.nextDouble() * 0.5),
          life: life,
          maxLife: maxLife,
          size: 3.0 + rng.nextDouble() * 2.5,
          color: color,
          type: aura.type,
        );

      // ☠️ POISON – bong bóng nổi
      case _AuraType.poison:
        return _Particle(
          x: _cx + (rng.nextDouble() - 0.5) * 44,
          y: _cy + 10 + rng.nextDouble() * 15,
          vx: (rng.nextDouble() - 0.5) * 0.35,
          vy: -(0.2 + rng.nextDouble() * 0.45),
          life: life,
          maxLife: maxLife * 1.2,
          size: 3.5 + rng.nextDouble() * 4.0,
          color: color,
          type: aura.type,
        );

      // ⚡ THUNDER – tia sét
      case _AuraType.thunder:
        return _Particle(
          x: _cx + (rng.nextDouble() - 0.5) * 50,
          y: _cy + (rng.nextDouble() - 0.5) * 50,
          vx: (rng.nextDouble() - 0.5) * 1.8,
          vy: (rng.nextDouble() - 0.5) * 1.8,
          life: life,
          maxLife: 0.15 + rng.nextDouble() * 0.25, // chớp nhanh
          size: 14 + rng.nextDouble() * 22,
          color: rng.nextBool() ? aura.primary : aura.secondary,
          type: aura.type,
        );

      // 💫 DIVINE – vòng hào quang
      case _AuraType.divine:
        final isRing = index % 5 == 0;
        return _Particle(
          x: _cx + (rng.nextDouble() - 0.5) * 24,
          y: _cy + (rng.nextDouble() - 0.5) * 24,
          vx: (rng.nextDouble() - 0.5) * 0.25,
          vy: -(0.15 + rng.nextDouble() * 0.4),
          life: life,
          maxLife: isRing ? 1.4 : maxLife,
          size: 2.5 + rng.nextDouble() * 3.0,
          color: color,
          type: aura.type,
          ringRadius: 0,
          isRing: isRing,
        );
    }
  }

  bool get isDead => life >= maxLife;
  double get lifeRatio => (life / maxLife).clamp(0.0, 1.0);
  double get fade {
    final lt = lifeRatio;
    if (lt < 0.15) return lt / 0.15;
    if (lt > 0.75) return (1.0 - lt) / 0.25;
    return 1.0;
  }

  void update() {
    const dt = 0.016; // ~60fps
    life += dt;

    if (type == _AuraType.arcane) {
      // Quỹ đạo ellipse
      angle += 0.03;
      x = _cx + cos(angle) * radius;
      y = _cy + sin(angle) * radius * 0.55;
    } else if (type == _AuraType.divine && isRing) {
      ringRadius += 0.7;
    } else {
      x += vx;
      y += vy;
      // Fire có lực nổi
      if (type == _AuraType.fire) vy *= 0.995;
      // Shadow mờ dần và nở ra
      if (type == _AuraType.shadow) size += 0.03;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  PAINTER
// ══════════════════════════════════════════════════════════════
class _AuraPainter extends CustomPainter {
  final List<_Particle> particles;
  final _ClassAura aura;
  final int level;
  final double tick;

  const _AuraPainter({
    required this.particles,
    required this.aura,
    required this.level,
    required this.tick,
  });

  double get _intensity {
    if (level < 10) return 0.4;
    if (level < 20) return 0.6;
    if (level < 40) return 0.8;
    if (level < 60) return 1.0;
    return 1.2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final intensity = _intensity.clamp(0.0, 1.3);
    final sx = size.width / 140.0;
    final sy = size.height / 140.0;
    final baseScale = (sx + sy) * 0.5;
    final sizeScale = (1.1 + 0.35 * intensity) * baseScale;
    final spread = 1.35 + 0.15 * intensity;
    final cx = size.width / 2;
    final cy = size.height * 0.62;

    Offset toScreen(double x, double y) {
      return Offset(
        cx + (x - _Particle._cx) * spread * sx,
        cy + (y - _Particle._cy) * spread * sy,
      );
    }

    for (final p in particles) {
      if (p.isDead) continue;
      final opacity = (p.fade * intensity).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      switch (p.type) {
        case _AuraType.fire:
          final lt = p.lifeRatio;
          final col = lt < 0.3
              ? Color.lerp(p.color, const Color(0xFFFFFF00), 0.5)!
              : p.color;
          paint.color = col.withOpacity(opacity);
          final s = p.size * sizeScale * (1 - lt * 0.5);
          final pos = toScreen(p.x, p.y);
          canvas.drawRect(
            Rect.fromCenter(center: pos, width: s, height: s),
            paint,
          );
          break;
        case _AuraType.wind:
          paint.color = p.color.withOpacity(opacity);
          final s = p.size * sizeScale;
          final pos = toScreen(p.x, p.y);
          final path = Path()
            ..moveTo(pos.dx, pos.dy - s)
            ..lineTo(pos.dx + s * 0.5, pos.dy)
            ..lineTo(pos.dx, pos.dy + s)
            ..lineTo(pos.dx - s * 0.5, pos.dy)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case _AuraType.shadow:
          paint.color = p.color.withOpacity(opacity * 0.55);
          canvas.drawCircle(toScreen(p.x, p.y), p.size * sizeScale, paint);
          break;
        case _AuraType.arcane:
          paint.color = p.color.withOpacity(opacity);
          final s = p.size * sizeScale;
          final pos = toScreen(p.x, p.y);
          canvas.drawRect(
            Rect.fromCenter(center: pos, width: s, height: s * 0.35),
            paint,
          );
          canvas.drawRect(
            Rect.fromCenter(center: pos, width: s * 0.35, height: s),
            paint,
          );
          break;
        case _AuraType.holy:
          paint.color = p.color.withOpacity(opacity * 0.9);
          final s = p.size * sizeScale * (1 - p.lifeRatio * 0.6);
          final pos = toScreen(p.x, p.y);
          canvas.drawRect(
            Rect.fromCenter(center: pos, width: s * 0.6, height: s * 0.6),
            paint,
          );
          break;
        case _AuraType.poison:
          final borderPaint = Paint()
            ..color = p.color.withOpacity(opacity * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          final pos = toScreen(p.x, p.y);
          canvas.drawCircle(
            pos,
            p.size * sizeScale * (1 - p.lifeRatio * 0.2),
            borderPaint,
          );
          break;
        case _AuraType.thunder:
          final boltPaint = Paint()
            ..color = p.color.withOpacity(opacity)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;
          final path = Path();
          final start = toScreen(p.x, p.y);
          path.moveTo(start.dx, start.dy);
          final len = p.size * sizeScale;
          final rng = Random((p.x * 100 + p.y * 10 + level).toInt());
          double bx = p.x, by = p.y;
          for (int j = 0; j < 3; j++) {
            final nx = bx + (rng.nextDouble() - 0.5) * len;
            final ny = by + (rng.nextDouble() - 0.5) * len;
            final pos = toScreen(nx, ny);
            path.lineTo(pos.dx, pos.dy);
            bx = nx;
            by = ny;
          }
          canvas.drawPath(path, boltPaint);
          break;
        case _AuraType.divine:
          if (p.isRing) {
            final ringPaint = Paint()
              ..color = p.color.withOpacity(opacity * 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0;
            if (p.ringRadius > 0) {
              final ringRadius = p.ringRadius * spread * baseScale;
              canvas.drawCircle(Offset(cx, cy), ringRadius, ringPaint);
            }
          } else {
            paint.color = p.color.withOpacity(opacity);
            canvas.drawCircle(
              toScreen(p.x, p.y),
              p.size * sizeScale * 0.8,
              paint,
            );
          }
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => true; // repaint mỗi frame
}
