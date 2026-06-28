import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

final _rnd = Random();

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
              final op = (1 - p.progress).clamp(0.0, 1.0);
              final paint = Paint()..color = col.withOpacity(op);
              if (additive) paint.blendMode = BlendMode.plus;
              canvas.drawCircle(Offset.zero, rad * (1 - 0.4 * p.progress), paint);
            },
          ),
        );
      },
    ),
  );
}

ParticleSystemComponent fireBurst(Vector2 pos, double s, {int count = 3}) =>
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
        additive: true);

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
