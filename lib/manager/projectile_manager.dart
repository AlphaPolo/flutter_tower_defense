import 'dart:async';

import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/enemy/enemy.dart';
import 'package:tower_defense/model/projectile/projectile.dart';

class ProjectileManager {
  late final GameManager gameManager;

  final projectilePrototype = {};

  List<Projectile> projectiles = [];

  final StreamController<List<Projectile>> _projectilesStreamController = StreamController();
  late final Stream<List<Projectile>> _projectilesEvent = _projectilesStreamController.stream.asBroadcastStream();


  void init(GameManager manager) {
    gameManager = manager;
  }

  void dispose() {
    _projectilesStreamController.close();
  }

  void tick(GameManager manager, int clock) {
    for (final projectile in projectiles) {
      projectile.tick(manager, clock);
    }
  }

  void addProjectile(Projectile projectile) {
    final targetOffset = projectile.target?.renderOffset;
    if(targetOffset == null) return;
    projectile.goal = targetOffset;
    projectile.lifeTime = (projectile.position - targetOffset).distance ~/ (projectile.speed / 3);
    // print('shooted: ${projectile.lifeTime}');
    projectiles.add(projectile);
  }

  void trimProjectile() {
    projectiles.removeWhere((projectile) => projectile.isDead);
  }

  Stream<List<Projectile>> onProjectileStream() => _projectilesEvent;

  void notifyListeners() {
    _projectilesStreamController.add(projectiles);
  }

}