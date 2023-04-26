

import 'dart:ui';

import 'package:tower_defense/model/projectile/projectile.dart';

class FreezeProjectile extends Projectile {
  FreezeProjectile(
    double damage,
    Offset position,
    double speed,
  ) : super(damage, position, Offset.zero, speed);

}