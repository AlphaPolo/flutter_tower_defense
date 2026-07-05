import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

/// cubic-bezier(0.34, 1.56, 0.64, 1)：easeOutBack 風格，衝過頭再回彈（y2>1 會過衝）。
const Curve kPopEase = Cubic(0.34, 1.56, 0.64, 1.0);

/// 出場「壓扁與拉伸」(squash & stretch) 彈出：用標準 [ScaleEffect] 串成數個關鍵影格，
/// 每格明確指定寬×高（非等比、體積大致守恆），最後一段用過衝曲線 [kPopEase] 收尾。
/// 塔與敵人共用。
///
/// 用法：先 `component.scale.setValues(0, 0);` 再 `component.add(popInEffect());`
/// （每次呼叫回傳新的 effect 實例，effect 不可跨元件共用）。
Effect popInEffect() => SequenceEffect([
      // 冒出：向上拉伸（瘦高）
      ScaleEffect.to(Vector2(0.9, 1.15),
          EffectController(duration: 0.15, curve: Curves.easeOut)),
      // 落地：壓扁（矮胖）
      ScaleEffect.to(Vector2(1.12, 0.9),
          EffectController(duration: 0.10, curve: Curves.easeInOut)),
      // 回正（過衝曲線收尾，帶一點回彈）
      ScaleEffect.to(Vector2.all(1),
          EffectController(duration: 0.16, curve: kPopEase)),
    ]);
