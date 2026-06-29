import 'dart:math';

import 'package:flutter/widgets.dart';

/// 上半部不剪、下半部剪成半圓的自訂裁切器。
///
/// 以正方形容器（例如 60×60）為例，產生的形狀為「上方矩形 + 下方半圓」：
///
/// ```
///   ┌───────────┐   ← 上半部維持矩形（不剪）
///   │           │
///   ├───────────┤   ← 中線 y = height/2
///   \           /   ← 下半部為半圓（半徑 = width/2）
///    \_________/
/// ```
///
/// 半圓圓心在 (width/2, height/2)、半徑為 width/2，往下凸出。
/// 對正方形而言半圓底部剛好觸及容器底邊；非正方形時：
/// - 較寬（width > height）：半圓會超出底邊，超出處被容器邊界裁掉。
/// - 較高（width < height）：半圓底部之下的區域（被裁掉）會留白。
class BottomSemicircleClipper extends CustomClipper<Path> {
  const BottomSemicircleClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;
    final r = w / 2;
    final circle = Rect.fromCircle(center: Offset(w / 2, midY), radius: r);

    return Path()
      // 上半部矩形：左上 → 左中
      ..moveTo(0, 0)
      ..lineTo(0, midY)
      // 下半部半圓：左中 → （經底部中央）→ 右中
      ..arcTo(circle, pi, -pi, false)
      // 回到上半部：右中 → 右上，最後 close 接回左上（補上頂邊）
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
