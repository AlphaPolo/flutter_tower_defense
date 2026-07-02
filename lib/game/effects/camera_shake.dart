import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_noise/flame_noise.dart';

import '../tower_defense_game.dart';

/// 相機震動控制器：對 `camera.viewfinder` 疊加 Flame 內建的雜訊位移效果。
///
/// 參考 Flame 官方 shake 範例（`MoveEffect` + `NoiseEffectController`），改良兩點：
///  1. 官方 `MoveEffect.by(Vector2(5,5), …)` 只沿「單一固定對角線」來回晃 →
///     這裡用 **X/Y 兩個 `MoveByEffect`**，各給獨立隨機幅度(含正負)＋不同 seed 的
///     雜訊，因此每次爆炸方向都不同，且單次抖動是有機的 2D 曲線（非一條直線）。
///  2. `NoiseEffectController` 會把振幅 taper 回 0 才結束 → 效果跑完必回原位、
///     相機不漂移；再加一個 guard：已有震動進行中就忽略新的觸發，避免中途插入
///     造成效果堆疊/殘留。
class CameraShakeController extends Component
    with HasGameReference<TowerDefenseGame> {
  final _rnd = Random();

  Effect? _fxX;
  Effect? _fxY;

  /// 目前是否有震動進行中（兩軸任一還掛著就算）。
  bool get isShaking => (_fxX?.isMounted ?? false) || (_fxY?.isMounted ?? false);

  /// 每軸雜訊在整段效果內取樣的 perlin 跨度：越大抖越急促、越小越大幅晃。
  static const double _frequency = 12;

  /// 觸發一次震動。[magnitudePx] 為螢幕像素峰值（每軸各自隨機到 ±此值）。
  /// 已有震動進行中則忽略（不打斷、不堆疊）。
  void shake(double magnitudePx, {double duration = 0.35}) {
    if (magnitudePx <= 0 || isShaking) return;
    final vf = game.camera.viewfinder;
    final h = magnitudePx / vf.zoom; // 螢幕像素 → 世界單位（viewfinder 座標）

    double amp() => (_rnd.nextDouble() * 2 - 1) * h;
    NoiseEffectController ctrl() => NoiseEffectController(
          duration: duration,
          // 不同 seed → X/Y 兩軸雜訊曲線不同 → 有機 2D 抖動，而非單一直線。
          noise: PerlinNoise(seed: _rnd.nextInt(1 << 30), frequency: _frequency),
        );

    _fxX = MoveByEffect(Vector2(amp(), 0), ctrl());
    _fxY = MoveByEffect(Vector2(0, amp()), ctrl());
    vf.addAll([_fxX!, _fxY!]);
  }
}
