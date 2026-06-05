import 'dart:math';

import 'package:flutter/material.dart';

class RpgPixelBackground extends CustomPainter {
  final int level;
  static const double _px = 4.0; // 1 "pixel" = 4dp

  const RpgPixelBackground({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final baseWidth = _cols * _px;
    final baseHeight = _rows * _px;
    final scaleX = size.width / baseWidth;
    final scaleY = size.height / baseHeight;
    final baseSize = Size(baseWidth, baseHeight);

    canvas.save();
    canvas.scale(scaleX, scaleY);
    if (level < 10) {
      _drawForest(canvas, baseSize);
    } else if (level < 20) {
      _drawNightForest(canvas, baseSize);
    } else if (level < 40) {
      _drawDungeon(canvas, baseSize);
    } else if (level < 60) {
      _drawIce(canvas, baseSize);
    } else {
      _drawVolcano(canvas, baseSize);
    }
    canvas.restore();
  }

  void _p(Canvas c, double x, double y, double w, double h, Color col) {
    c.drawRect(
      Rect.fromLTWH(x * _px, y * _px, w * _px, h * _px),
      Paint()..color = col,
    );
  }

  int get _cols => 50;
  int get _rows => 35;

  void _drawForest(Canvas canvas, Size size) {
    final paint = Paint();

    for (int y = 0; y < _rows; y++) {
      final t = y / _rows;
      final col = Color.lerp(
        const Color(0xFF2d6a2d),
        const Color(0xFF1a3d1a),
        t,
      )!;
      paint.color = col;
      canvas.drawRect(Rect.fromLTWH(0, y * _px, size.width, _px), paint);
    }

    final groundY = (_rows * 0.72).floor().toDouble();
    for (int x = 0; x < _cols; x++) {
      _p(
        canvas,
        x.toDouble(),
        groundY,
        1,
        _rows - groundY,
        const Color(0xFF2d5a1b),
      );
      if ((x + 3) % 5 == 0) {
        _p(canvas, x.toDouble(), groundY, 1, 1, const Color(0xFF4a8a30));
      }
    }

    _drawTree(
      canvas,
      3,
      groundY - 6,
      const Color(0xFF5c3a1e),
      const Color(0xFF2d8b3e),
    );
    _drawTree(
      canvas,
      11,
      groundY - 5,
      const Color(0xFF5c3a1e),
      const Color(0xFF22703a),
    );
    _drawTree(
      canvas,
      19,
      groundY - 7,
      const Color(0xFF5c3a1e),
      const Color(0xFF3a9a44),
    );
    _drawTree(
      canvas,
      28,
      groundY - 5,
      const Color(0xFF5c3a1e),
      const Color(0xFF2d8b3e),
    );
    _drawTree(
      canvas,
      38,
      groundY - 6,
      const Color(0xFF5c3a1e),
      const Color(0xFF22703a),
    );

    for (int i = 0; i < 8; i++) {
      final x = (i * _cols / 8).floor().toDouble() + 1;
      _p(canvas, x, groundY + 1, 1, 1, const Color(0xFF4a9a28));
      _p(canvas, x - 1, groundY + 2, 3, 1, const Color(0xFF3a8020));
    }
  }

  void _drawTree(Canvas canvas, double bx, double by, Color trunk, Color leaf) {
    for (int dy = 3; dy <= 5; dy++) {
      _p(canvas, bx, by + dy, 1, 1, trunk);
    }

    for (final offset in [
      [-1, 1],
      [0, 1],
      [1, 1],
      [-2, 2],
      [-1, 2],
      [0, 2],
      [1, 2],
      [2, 2],
      [-1, 0],
      [0, 0],
      [1, 0],
    ]) {
      _p(canvas, bx + offset[0], by + offset[1], 1, 1, leaf);
    }
  }

  void _drawNightForest(Canvas canvas, Size size) {
    final paint = Paint();

    for (int y = 0; y < _rows; y++) {
      final t = y / _rows;
      final col = Color.lerp(
        const Color(0xFF0d1b35),
        const Color(0xFF060d18),
        t,
      )!;
      paint.color = col;
      canvas.drawRect(Rect.fromLTWH(0, y * _px, size.width, _px), paint);
    }

    const stars = [
      [3, 2],
      [8, 1],
      [15, 3],
      [20, 1],
      [25, 2],
      [30, 4],
      [5, 5],
      [12, 3],
      [22, 4],
      [35, 2],
      [42, 3],
    ];
    for (final s in stars) {
      _p(
        canvas,
        s[0].toDouble(),
        s[1].toDouble(),
        1,
        1,
        const Color(0xFFffffcc),
      );
    }

    _p(canvas, 38, 2, 3, 3, const Color(0xFFffffd0));
    _p(canvas, 41, 2, 1, 1, const Color(0xFFd0d080));

    final groundY = (_rows * 0.72).floor().toDouble();
    for (int x = 0; x < _cols; x++) {
      _p(
        canvas,
        x.toDouble(),
        groundY,
        1,
        _rows - groundY,
        const Color(0xFF0d2010),
      );
    }

    _drawTree(
      canvas,
      2,
      groundY - 7,
      const Color(0xFF1a3a10),
      const Color(0xFF0d1f08),
    );
    _drawTree(
      canvas,
      10,
      groundY - 8,
      const Color(0xFF152e0c),
      const Color(0xFF0a1805),
    );
    _drawTree(
      canvas,
      20,
      groundY - 6,
      const Color(0xFF1a3a10),
      const Color(0xFF0d1f08),
    );
    _drawTree(
      canvas,
      30,
      groundY - 7,
      const Color(0xFF152e0c),
      const Color(0xFF0a1805),
    );
    _drawTree(
      canvas,
      40,
      groundY - 6,
      const Color(0xFF1a3a10),
      const Color(0xFF0d1f08),
    );

    const fireflies = [
      [5, 0],
      [14, 0],
      [23, 0],
      [32, 0],
    ];
    for (final f in fireflies) {
      final fx = f[0].toDouble();
      final fy = groundY - 2 + f[1];
      _p(canvas, fx, fy, 1, 1, const Color(0xFF9b59ff));
    }
  }

  void _drawDungeon(Canvas canvas, Size size) {
    for (int y = 0; y < _rows; y++) {
      for (int x = 0; x < _cols; x++) {
        final isDark = ((x ~/ 4) + (y ~/ 3)) % 2 == 0;
        _p(
          canvas,
          x.toDouble(),
          y.toDouble(),
          1,
          1,
          isDark ? const Color(0xFF2a2015) : const Color(0xFF1f1a0f),
        );
      }
    }

    for (int y = 0; y < _rows; y += 3) {
      canvas.drawLine(
        Offset(0, y * _px),
        Offset(size.width, y * _px),
        Paint()
          ..color = const Color(0xFF15100a)
          ..strokeWidth = 1,
      );
    }

    for (int y = 0; y < _rows; y++) {
      final offset = (y % 2 == 0) ? 0 : 4;
      for (int x = offset; x < _cols; x += 8) {
        canvas.drawLine(
          Offset(x * _px, y * _px),
          Offset(x * _px, (y + 1) * _px),
          Paint()
            ..color = const Color(0xFF15100a)
            ..strokeWidth = 1,
        );
      }
    }

    const torches = [4.0, 18.0, 34.0];
    final groundY = (_rows * 0.75).toDouble();
    for (final tx in torches) {
      _p(canvas, tx, groundY - 4, 1, 4, const Color(0xFF4a3010));
      _p(canvas, tx - 1, groundY - 6, 3, 3, const Color(0xFFc8860a));
      _p(canvas, tx, groundY - 7, 1, 1, const Color(0xFFffcc00));
      canvas.drawCircle(
        Offset((tx + 0.5) * _px, (groundY - 5) * _px),
        14,
        Paint()..color = const Color(0x33ff9900),
      );
    }

    final doorX = (_cols / 2 - 3).floor().toDouble();
    for (int x = doorX.toInt(); x < doorX + 6; x++) {
      _p(
        canvas,
        x.toDouble(),
        groundY - 5,
        1,
        _rows.toDouble() - (groundY - 5).floor().toDouble(),
        const Color(0xFF0a0705),
      );
    }
    _p(canvas, doorX, groundY - 5, 6, 1, const Color(0xFF4a3010));
    _p(canvas, doorX + 2, groundY - 5, 2, 5, const Color(0xFF4a3010));
  }

  void _drawIce(Canvas canvas, Size size) {
    final paint = Paint();

    for (int y = 0; y < _rows; y++) {
      final t = y / _rows;
      final col = Color.lerp(
        const Color(0xFF14283c),
        const Color(0xFF0a1828),
        t,
      )!;
      paint.color = col;
      canvas.drawRect(Rect.fromLTWH(0, y * _px, size.width, _px), paint);
    }

    const stars = [
      [3, 2],
      [8, 1],
      [15, 3],
      [20, 1],
      [25, 2],
      [30, 4],
      [40, 2],
    ];
    for (final s in stars) {
      _p(
        canvas,
        s[0].toDouble(),
        s[1].toDouble(),
        1,
        1,
        const Color(0xFFb0e8ff),
      );
    }

    final groundY = (_rows * 0.65).floor().toDouble();
    for (int x = 0; x < _cols; x++) {
      final h = (sin(x * 0.7) * 2 + 2).floor().toDouble();
      _p(
        canvas,
        x.toDouble(),
        groundY - h,
        1,
        _rows.toDouble() -
            groundY.floor().toDouble() +
            h.floor().toDouble() +
            1,
        const Color(0xFFa0d4e8),
      );
    }

    for (int x = 0; x < _cols; x++) {
      final col = x % 4 < 2 ? const Color(0xFFc8eaf5) : const Color(0xFF90c8e0);
      _p(canvas, x.toDouble(), groundY + 1, 1, 2, col);
    }

    const icicles = [2.0, 8.0, 16.0, 25.0, 34.0];
    for (final ix in icicles) {
      _p(canvas, ix + 1, groundY - 5, 1, 4, const Color(0xFFc8eaf5));
      _p(canvas, ix, groundY - 3, 1, 2, const Color(0xFFa0c8de));
      _p(canvas, ix + 2, groundY - 3, 1, 2, const Color(0xFFa0c8de));
      _p(canvas, ix + 1, groundY - 5, 1, 1, const Color(0xFFe8f8ff));
    }
  }

  void _drawVolcano(Canvas canvas, Size size) {
    final paint = Paint();

    for (int y = 0; y < _rows; y++) {
      final t = y / _rows;
      final col = Color.lerp(
        const Color(0xFF2a0800),
        const Color(0xFF0f0200),
        t,
      )!;
      paint.color = col;
      canvas.drawRect(Rect.fromLTWH(0, y * _px, size.width, _px), paint);
    }

    final groundY = (_rows * 0.72).floor().toDouble();
    for (int x = 0; x < _cols; x++) {
      _p(
        canvas,
        x.toDouble(),
        groundY,
        1,
        _rows.toDouble() - groundY.floor().toDouble(),
        const Color(0xFF1a0500),
      );
    }

    const lavaColors = [
      Color(0xFFff6600),
      Color(0xFFff4400),
      Color(0xFFff8800),
      Color(0xFFdd3300),
    ];
    for (int x = 0; x < _cols; x++) {
      if ((x + 1) % 3 == 0) {
        final lh = (sin(x * 1.2) * 1.5 + 1.5).floor().toDouble();
        _p(canvas, x.toDouble(), groundY - lh, 1, lh + 1, lavaColors[x % 4]);
      }
    }

    const volcanoes = [
      [5.0, 9.0],
      [22.0, 12.0],
      [36.0, 8.0],
    ];
    for (final v in volcanoes) {
      final vx = v[0], vh = v[1];
      final vy = groundY - vh;
      for (int dy = 0; dy < vh.toInt(); dy++) {
        final w = (dy * 0.5 + 1).floor().toDouble();
        _p(canvas, vx - w / 2, vy + dy, w, 1, const Color(0xFF2d1000));
      }
      _p(canvas, vx, vy - 2, 3, 3, const Color(0xFFff4400));
      _p(canvas, vx - 1, vy - 1, 5, 2, const Color(0xFFcc2200));
      canvas.drawCircle(
        Offset((vx + 1.5) * _px, vy * _px),
        16,
        Paint()..color = const Color(0x22ff5000),
      );
    }

    const embers = [
      [8, -4],
      [15, -3],
      [28, -5],
      [42, -4],
    ];
    for (final e in embers) {
      final ex = e[0].toDouble(), ey = groundY + e[1];
      _p(canvas, ex, ey, 1, 1, const Color(0xFFff6600));
      _p(canvas, ex - 1, ey + 1, 3, 1, const Color(0xFFdd3300));
    }
  }

  @override
  bool shouldRepaint(RpgPixelBackground oldDelegate) =>
      oldDelegate.level != level;
}
