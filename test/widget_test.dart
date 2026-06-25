import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/tower_defense_game.dart';

void main() {
  test('遊戲建立時有正確的初始資源', () {
    final game = TowerDefenseGame();
    expect(game.coin.value, 150);
    expect(game.heart.value, 20);
    expect(game.freeObstacle.value, 3);
    expect(game.gameOver.value, isFalse);
  });
}
