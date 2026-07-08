import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

final _rnd = Random();

/// 爆金幣：擊殺時一撮金幣往上＋外呈扇形噴、受重力落下、邊旋轉(水平壓縮模擬翻面)
/// 邊淡出。金幣以程式繪製（深金邊 + 亮金面），不依賴圖片。
ParticleSystemComponent coinBurst(Vector2 pos, double s, {int count = 8}) {
  final r = 3.2 * s; // 金幣半徑
  return ParticleSystemComponent(
    position: pos.clone(),
    priority: 3000000,
    particle: Particle.generate(
      count: count,
      lifespan: 0.75,
      generator: (i) {
        final ang = -pi / 2 + (_rnd.nextDouble() - 0.5) * 2.0; // 上方扇形
        final spd = (70 + _rnd.nextDouble() * 80) * s;
        final spin = (_rnd.nextDouble() - 0.5) * 10; // 旋轉速度(含正負)
        final phase = _rnd.nextDouble() * 2; // 發光變色相位
        return AcceleratedParticle(
          speed: Vector2(cos(ang), sin(ang)) * spd,
          acceleration: Vector2(0, 260 * s), // 重力
          child: ComputedParticle(
            renderer: (canvas, p) {
              final t = p.progress;
              final op = (1 - t * t).clamp(0.0, 1.0); // 後段才快速淡出
              final flip = cos(spin * t * pi).abs().clamp(0.15, 1.0); // 翻面
              // 變色發光暈：偏金色、會閃爍、每顆相位錯開、整體較弱。
              final shimmer = 0.5 + 0.5 * sin((t * 5 + phase) * pi);
              final flick = 0.4 + 0.6 * sin((t * 8 + phase * 3) * pi).abs();
              final glow = Color.lerp(
                  const Color(0xFFF7B21E), const Color(0xFFFFE79A), shimmer)!;
              canvas.drawCircle(
                Offset.zero,
                r * 1.7,
                Paint()
                  ..color = glow.withValues(alpha: 0.12 * op * flick)
                  ..blendMode = BlendMode.plus
                  ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
              );
              // 細金邊（外框，淺金）
              canvas.drawOval(
                Rect.fromCenter(
                    center: Offset.zero, width: r * 2 * flip, height: r * 2),
                Paint()..color = const Color(0xFFF9CE5A).withValues(alpha: op),
              );
              // 亮金面（外框細 → 面更大）
              canvas.drawOval(
                Rect.fromCenter(
                    center: Offset.zero,
                    width: r * 1.72 * flip,
                    height: r * 1.72),
                Paint()..color = const Color(0xFFFFE96B).withValues(alpha: op),
              );
            },
          ),
        );
      },
    ),
  );
}

/// 亮十字閃光：獨立於金幣、往上緩緩飄、淡入淡出的白色十字（比金幣略小）。
ParticleSystemComponent coinSparkle(Vector2 pos, double s, {int count = 2}) {
  final r = 4.0 * s;
  return ParticleSystemComponent(
    position: pos.clone(),
    priority: 3000001,
    particle: Particle.generate(
      count: count,
      lifespan: 0.6,
      generator: (i) {
        final ox = (_rnd.nextDouble() - 0.5) * r * 9; // 左右分散
        final oy = (_rnd.nextDouble() - 0.5) * r * 2;
        return AcceleratedParticle(
          position: Vector2(ox, oy),
          speed: Vector2((_rnd.nextDouble() - 0.5) * 16 * s, -40 * s), // 緩慢上升
          child: ComputedParticle(
            renderer: (canvas, p) {
              final op = sin(pi * p.progress).clamp(0.0, 1.0); // 淡入淡出
              if (op <= 0.01) return;
              final gp = Paint()..color = const Color(0xFFFFE8A6).withValues(alpha: op);
              final half = r * 0.8; // 比金幣(半徑 r=直徑2r) 略小
              final thick = r * 0.26;
              canvas
                ..drawOval(
                    Rect.fromCenter(
                        center: Offset.zero, width: thick, height: half * 2),
                    gp)
                ..drawOval(
                    Rect.fromCenter(
                        center: Offset.zero, width: half * 2, height: thick),
                    gp)
                ..drawCircle(Offset.zero, r * 0.3, gp);
            },
          ),
        );
      },
    ),
  );
}

/// 硝煙一小團：擴散、微微上飄、淡出的柔邊灰煙（砲彈飛行尾跡用，每幀沿路生成）。
ParticleSystemComponent smokePuff(Vector2 pos, double s) {
  return ParticleSystemComponent(
    position: pos.clone(),
    priority: 1990000, // 在砲彈之下、敵人之上
    particle: Particle.generate(
      count: 1,
      lifespan: 0.5,
      generator: (i) {
        final r0 = 3.0 * s;
        final col = Color.lerp(const Color(0xFFBDBDBD), const Color(0xFF757575),
            _rnd.nextDouble())!;
        return AcceleratedParticle(
          speed: Vector2((_rnd.nextDouble() - 0.5) * 12 * s, -14 * s), // 微微上飄
          child: ComputedParticle(
            renderer: (canvas, p) {
              final t = p.progress;
              final op = (0.62 * (1 - t)).clamp(0.0, 1.0);
              final rad = r0 * (1 + 1.7 * t); // 擴散
              canvas.drawCircle(
                Offset.zero,
                rad,
                Paint()
                  ..color = col.withValues(alpha: op)
                  ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * s),
              );
            },
          ),
        );
      },
    ),
  );
}

/// 一團往外噴、邊飛邊淡出的圓點粒子，自動在結束時移除。
ParticleSystemComponent _burst(
  Vector2 pos, {
  required int count,
  required double life,
  required double speed,
  required double radius,
  required List<Color> colors,
  Vector2? accel,
  bool additive = false,
  double opacity = 1.0, // 整體透明度倍率（1=原樣，越小越淡）
}) {
  return ParticleSystemComponent(
    position: pos.clone(),
    priority: 2000000,
    particle: Particle.generate(
      count: count,
      lifespan: life,
      generator: (i) {
        final ang = _rnd.nextDouble() * 2 * pi;
        final spd = speed * (0.4 + _rnd.nextDouble());
        final col = colors[_rnd.nextInt(colors.length)];
        final rad = radius * (0.6 + _rnd.nextDouble() * 0.6);
        return AcceleratedParticle(
          speed: Vector2(cos(ang), sin(ang)) * spd,
          acceleration: accel ?? Vector2.zero(),
          child: ComputedParticle(
            renderer: (canvas, p) {
              final op = (1 - p.progress).clamp(0.0, 1.0) * opacity;
              final paint = Paint()..color = col.withValues(alpha: op);
              if (additive) paint.blendMode = BlendMode.plus;
              canvas.drawCircle(Offset.zero, rad * (1 - 0.4 * p.progress), paint);
            },
          ),
        );
      },
    ),
  );
}

ParticleSystemComponent fireBurst(Vector2 pos, double s,
        {int count = 3, double opacity = 1.0}) =>
    _burst(pos,
        count: count,
        life: 0.45,
        speed: 55 * s,
        radius: 3.2 * s,
        colors: const [
          Colors.yellow,
          Colors.orange,
          Colors.deepOrange,
          Colors.red
        ],
        accel: Vector2(0, -50 * s),
        additive: true,
        opacity: opacity);

ParticleSystemComponent frostBurst(Vector2 pos, double s, {int count = 16}) =>
    _burst(pos,
        count: count,
        life: 0.7,
        speed: 45 * s,
        radius: 2.6 * s,
        colors: const [
          Colors.white,
          Colors.lightBlueAccent,
          Colors.cyanAccent
        ]);

ParticleSystemComponent sparkBurst(Vector2 pos, double s, {int count = 8}) =>
    _burst(pos,
        count: count,
        life: 0.3,
        speed: 95 * s,
        radius: 2.2 * s,
        colors: const [Colors.yellow, Colors.white, Colors.amberAccent],
        additive: true);

ParticleSystemComponent windBurst(Vector2 pos, double s, {int count = 4}) =>
    _burst(pos,
        count: count,
        life: 0.35,
        speed: 70 * s,
        radius: 2.0 * s,
        colors: const [
          Colors.greenAccent,
          Colors.white,
          Colors.lightGreenAccent
        ],
        additive: true);

ParticleSystemComponent explosionBurst(Vector2 pos, double s,
        {int count = 18}) =>
    _burst(pos,
        count: count,
        life: 0.5,
        speed: 130 * s,
        radius: 4.0 * s,
        colors: const [
          Colors.white,
          Colors.yellow,
          Colors.orange,
          Colors.deepOrange,
          Colors.brown,
        ],
        additive: true);

ParticleSystemComponent poisonBurst(Vector2 pos, double s, {int count = 6}) =>
    _burst(pos,
        count: count,
        life: 0.6,
        speed: 40 * s,
        radius: 2.6 * s,
        colors: const [
          Colors.lightGreen,
          Colors.green,
          Color(0xFF9CCC65),
        ],
        accel: Vector2(0, -30 * s));

ParticleSystemComponent deathBurst(Vector2 pos, double s, {int count = 8}) =>
    _burst(pos,
        count: count,
        life: 0.4,
        speed: 55 * s,
        radius: 2.6 * s,
        colors: const [
          Colors.indigoAccent,
          Colors.white,
          Colors.purpleAccent
        ]);
