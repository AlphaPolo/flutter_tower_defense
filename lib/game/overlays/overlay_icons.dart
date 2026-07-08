part of 'game_overlays.dart';

// ═══ 圖示：towerIcon 與程式繪製圖示（多重箭/地刺/渦流）＋敵人頭像畫家 ═══

/// 每種塔在選單 / 資訊面板上顯示的圖示。
/// 統一使用較正面取景渲染的外觀圖（與蓋在地圖上的 isometric 角度不同），
/// BoxFit.contain 讓裁切後的塔身維持比例並置中。
Widget towerIcon(TowerType type) {
  // 渦流陷阱沒有 3D 模型素材，用程式繪製。
  if (type == TowerType.vortex) return const VortexIcon();

  // 檔名一律小寫（airBlade → icon_airblade.png），避免 case-sensitive 部署找不到。
  return Image.asset(
    'assets/iso/icon_${type.name.toLowerCase()}.png',
    fit: BoxFit.contain,
  );
}

/// 多重箭圖示（程式繪製）：三支向外發散的箭。
class MultishotIcon extends StatelessWidget {
  const MultishotIcon({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.infinite, painter: _MultishotIconPainter());
}

class _MultishotIconPainter extends CustomPainter {
  const _MultishotIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = Offset(w * 0.5, h * 0.78);
    canvas.drawCircle(base, w * 0.12, Paint()..color = const Color(0xFF5D4037));
    final arrow = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    for (final off in const [-0.6, 0.0, 0.6]) {
      final a = -pi / 2 + off;
      final tip = base + Offset(cos(a), sin(a)) * (h * 0.5);
      canvas
        ..drawLine(base, tip, arrow)
        ..drawLine(
            tip, tip + Offset(cos(a + 2.6), sin(a + 2.6)) * (h * 0.14), arrow)
        ..drawLine(
            tip, tip + Offset(cos(a - 2.6), sin(a - 2.6)) * (h * 0.14), arrow);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 地刺圖示（程式繪製，與場上地刺風格一致）。
class SpikeIcon extends StatelessWidget {
  const SpikeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(size: Size.infinite, painter: _SpikeIconPainter());
  }
}

class _SpikeIconPainter extends CustomPainter {
  const _SpikeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const body = Color(0xFF7E8B97);
    const highlight = Color(0xFFE9EEF3);

    // 地面基座
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.74),
        width: w * 0.82,
        height: h * 0.22,
      ),
      Paint()..color = const Color(0xFF5E6B76),
    );

    // (中心x比例, 底y比例, 高度比例, 半寬比例)；中間最高者最後畫（在前）。
    const spikes = [
      [0.27, 0.74, 0.40, 0.10],
      [0.73, 0.74, 0.40, 0.10],
      [0.50, 0.80, 0.56, 0.12],
    ];
    for (final sp in spikes) {
      final cx = sp[0] * w;
      final by = sp[1] * h;
      final sh = sp[2] * h;
      final sw = sp[3] * w;
      canvas.drawPath(
        Path()
          ..moveTo(cx - sw, by)
          ..lineTo(cx, by - sh)
          ..lineTo(cx + sw, by)
          ..close(),
        Paint()..color = body,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx - sw, by)
          ..lineTo(cx, by - sh)
          ..lineTo(cx, by)
          ..close(),
        Paint()..color = highlight.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpikeIconPainter oldDelegate) => false;
}

/// 渦流陷阱圖示（程式繪製：紫色螺旋）。
class VortexIcon extends StatelessWidget {
  const VortexIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(size: Size.infinite, painter: _VortexIconPainter());
  }
}

class _VortexIconPainter extends CustomPainter {
  const _VortexIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = min(size.width, size.height) * 0.42;
    const color = Color(0xFF7C4DFF);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..color = color;

    for (var k = 0; k < 3; k++) {
      final base = k * 2 * pi / 3;
      final path = Path();
      for (var i = 0; i <= 28; i++) {
        final t = i / 28;
        final rad = maxR * t;
        final ang = base + t * 2.6;
        final p = c + Offset(cos(ang) * rad, sin(ang) * rad);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, stroke);
    }
    canvas.drawCircle(c, size.width * 0.07, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _VortexIconPainter oldDelegate) => false;
}

/// 用敵人 spritesheet 的第 0 幀（裁到內容、方形）當頭像，畫進圓形頭像框。
class _EnemyAvatarPainter extends CustomPainter {
  _EnemyAvatarPainter(this.img, this.kind);
  final ui.Image? img;
  final EnemyKind kind;

  @override
  void paint(Canvas canvas, Size s) {
    final image = img;
    if (image == null || kind.frameSize <= 0) {
      canvas.drawCircle(
        Offset(s.width / 2, s.height / 2),
        s.width * 0.34,
        Paint()..color = kind.color,
      );
      return;
    }
    final fs = kind.frameSize;
    // 以「內容高度」為基準方形邊長，再依 avatarZoom 縮小裁切框(放大)、以內容中心
    // (可用 avatarDx/Dy 微調)為中心裁切。zoom=1 時與舊行為一致。
    final side = (kind.footFrac - kind.topFrac) * fs / kind.avatarZoom;
    final cx = fs / 2 + kind.avatarDx * fs;
    final cy = (kind.topFrac + kind.footFrac) / 2 * fs + kind.avatarDy * fs;
    final src = Rect.fromLTWH(cx - side / 2, cy - side / 2, side, side);
    canvas.drawImageRect(
      image,
      src,
      Offset.zero & s,
      Paint()
        ..filterQuality =
            kind.pixel ? FilterQuality.none : FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _EnemyAvatarPainter old) =>
      old.img != img || old.kind != kind;
}
