import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tower_defense/utils/bottom_semicircle_clipper.dart';

import '../../utils/fullscreen.dart';
import '../audio/game_audio.dart';
import '../board/hex.dart';
import '../components/enemy_kind.dart';
import '../tower_defense_game.dart';
import '../tower_type.dart';

// ── HUD 主題：奇幻木質風（暖木底 + 金銅邊 + 柔和陰影）───────────────────
const Color _kGold = Color(0xFFE8C877); // 金銅亮色（文字/高亮）
const Color _kGoldDeep = Color(0xFFB6832B); // 金銅暗色（描邊）

const LinearGradient _kWoodGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF4A3627), Color(0xFF241811)],
);

/// 選中分頁的漸層：底部收在「bar 頂端的顏色」(#4A3627) → 分頁底＝bar 頂、同色
/// 相接，連接處不會有顏色斷層；頂部再稍亮做立體感。
const LinearGradient _kSelTabGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF574029), Color(0xFF4A3627)],
);

/// 木質膠囊/列的通用外框：木紋漸層 + 金銅細邊 + 柔和陰影。
/// [strong] 決定陰影深淺（大面板用深、小晶片用淺）。
BoxDecoration _woodBox({double radius = 20, bool strong = true}) =>
    BoxDecoration(
      gradient: _kWoodGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _kGoldDeep.withOpacity(0.85), width: 1.3),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(strong ? 0.45 : 0.3),
          blurRadius: strong ? 8 : 5,
          offset: const Offset(0, 3),
        ),
      ],
    );

/// Tiny Swords 像素風 UI 圖示：關閉抗鋸齒 → 放大後像素邊緣仍銳利。
Widget _uiIcon(String name, double size) => Image.asset(
      'assets/ui/$name.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.none, // 像素風：最近鄰、邊緣銳利
    );

/// 內容卡片外框：羊皮紙漸層底 + 金銅細邊 + 柔和陰影（深色文字仍清楚）。
BoxDecoration _panelBox({double radius = 12}) => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8EED6), Color(0xFFEAD8AE)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _kGoldDeep.withOpacity(0.7), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );

/// 統一彈窗外框：深木漸層 + 金邊 + 圓角 + 強陰影。
BoxDecoration _dialogBox() => BoxDecoration(
      gradient: _kWoodGradient,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kGoldDeep, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

/// 統一彈窗按鈕：[filled] 為主要動作（實心 [color] 底）；否則為次要動作（文字鈕）。
Widget _dialogButton(String label, VoidCallback onTap,
    {bool filled = true, Color color = _kGold}) {
  if (!filled) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFD8C9A6)),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
  final fg = color == _kGold ? const Color(0xFF241811) : Colors.white;
  return ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: fg,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
    child: Text(label),
  );
}

/// 統一風格彈窗面板（勝利／失敗／確認共用）：圖示 + 標題 + 說明 + 動作列。
Widget _themedDialog({
  required IconData icon,
  required Color accent,
  required String title,
  String? message,
  required List<Widget> actions,
}) {
  return Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: _dialogBox(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 46),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: accent, fontSize: 24, fontWeight: FontWeight.w900)),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFE8DCC0), fontSize: 14, height: 1.4)),
          ],
          const SizedBox(height: 22),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    )
        // flutter_animate 入場：淡入 + 由小彈出（easeOutBack 過衝），有彈跳感。
        .animate()
        .fadeIn(duration: 180.ms)
        .scale(
          begin: const Offset(0.25, 1.5),
          // end: const Offset(1, 1),
          duration: 300.ms,
          // curve: Curves.easeOutBack,
          curve: const Cubic(0.34, 1.56, 0.64, 1),
        ),
  );
}

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
        Paint()..color = highlight.withOpacity(0.9),
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

/// HUD overlay：左下放作弊開關/狀態表/開始鈕，右下放塔資訊/建築資訊面板。
class LeftColOverlay extends StatelessWidget {
  const LeftColOverlay({super.key, required this.game, required this.onRestart});
  final TowerDefenseGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    // SafeArea：避開瀏海/瀏覽器列；LayoutBuilder：把面板高度限制在可視範圍內，
    // 配合 SingleChildScrollView 確保橫向矮螢幕不會爆版。面板都靠角落擺放，
    // 中央棋盤維持可點擊。
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                // 左上：狀態列 + 設定鈕（開啟設定抽屜）
                Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusPill(),
                      const SizedBox(height: 8),
                      _hudButtons(),
                      const SizedBox(height: 8),
                      _cheatButton(), // 作弊模式（在設定/重新開始列下方）
                    ],
                  ),
                ),
                // 左下：敵人資訊卡 +（開始鈕 + 敵人圖鑑）
                Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: c.maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _enemyInfoCard(),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _startButton(),
                            const SizedBox(width: 10),
                            Flexible(child: _enemyBestiary()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 右側：選取塔資訊 / 已蓋建築資訊（限高、可捲動）
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: c.maxHeight),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _infoPanel(),
                          _inspectPanel(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 半透明深色膠囊：波數 / 生命 / 金幣，橫向排列省空間且在棋盤上清楚可讀。
  Widget _statusPill() {
    return Stack(
      clipBehavior: Clip.none, // 讓密林收入浮動字能飄出膠囊範圍
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: _woodBox(radius: 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stat(
                  // 波次：game-icons.net「crossed-sabres」(lorc, CC BY 3.0)，
                  // 白色 alpha 形狀以 srcIn 染成藍色。
                  Image.asset('assets/ui/crossed_sabres.png',
                      width: 18,
                      height: 18,
                      color: Colors.lightBlueAccent,
                      colorBlendMode: BlendMode.srcIn),
                  game.wave,
                  (w) => w == 0 ? '—' : '$w/${TowerDefenseGame.totalWaves}'),
              const SizedBox(width: 14),
              _stat(
                  const Icon(Icons.favorite,
                      color: Colors.redAccent, size: 18),
                  game.heart,
                  (v) => '$v'),
              const SizedBox(width: 14),
              _coinStat(),
            ],
          ),
        ),
        // 密林收入：金幣旁「+xx 從密林」淡入 → 上飄 → 淡出（取代頂部 banner）。
        Positioned(
          right: 2,
          top: 34,
          child: IgnorePointer(child: _woodsIncomeFloat()),
        ),
      ],
    );
  }

  /// 密林收入浮動提示：每次事件（序號改變 → key 改變）重播一次動畫。
  Widget _woodsIncomeFloat() {
    return ValueListenableBuilder<(int, int)?>(
      valueListenable: game.woodsIncome,
      builder: (context, e, _) {
        if (e == null) return const SizedBox.shrink();
        return Text(
          '+${e.$2} 從密林',
          style: const TextStyle(
            color: _kGold,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        )
            .animate(key: ValueKey(e.$1))
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .moveY(begin: 8, end: -16, duration: 4000.ms, curve: Curves.easeOut)
            .fadeOut(delay: 3000.ms, duration: 1000.ms);
      },
    );
  }

  /// 金幣狀態：數字用 Tween 平滑增減(count-up)，金幣圖示每次變動彈一下(juice)。
  Widget _coinStat() {
    return ValueListenableBuilder<int>(
      valueListenable: game.coin,
      builder: (context, v, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 每次金幣變動，圖示彈一下（key 改變 → 重新播放）。
          _uiIcon('coin', 20).animate(key: ValueKey(v)).scaleXY(
                begin: 1.35,
                end: 1.0,
                duration: 260.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(width: 4),
          // 數字從舊值平滑跑到新值（TweenAnimationBuilder 不加 key → 保留狀態）。
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: v.toDouble()),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (context, val, child) => Text(
              '${val.round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(Widget icon, ValueListenable<int> listenable,
      String Function(int) fmt) {
    return ValueListenableBuilder<int>(
      valueListenable: listenable,
      builder: (context, v, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Text(
            fmt(v),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 重置按鈕：詢問確認後重新開始整場遊戲。
  /// 左上 HUD 按鈕列：「設定」（開啟設定抽屜）＋「重新開始」（確認後重置）。
  Widget _hudButtons() {
    return Builder(
      builder: (context) {
        return Row(
          spacing: 6,
          children: [
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: _woodBox(radius: 18, strong: false),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings, color: _kGold, size: 18),
                    SizedBox(width: 6),
                    Text('設定', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGold)),
                  ],
                ),
              ),
            ),

            GestureDetector(
              onTap: () => _confirmReset(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: _woodBox(radius: 18, strong: false),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: _kGold, size: 18),
                    SizedBox(width: 6),
                    Text('重新開始', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGold)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 作弊模式切換鈕（HUD，設定/重新開始列下方）：開啟時整顆變綠。
  Widget _cheatButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: game.cheat,
      builder: (context, on, _) {
        final color = on ? Colors.greenAccent : _kGold;
        return GestureDetector(
          onTap: () => game.toggleCheat(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: _woodBox(radius: 18, strong: false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: color, size: 18),
                const SizedBox(width: 6),
                Text('作弊模式${on ? '：開' : ''}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 重新開始確認：清除進度前先跳確認對話框（統一木質彈窗樣式）。
  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _themedDialog(
        icon: Icons.refresh,
        accent: _kGold,
        title: '重新開始？',
        message: '目前的進度（金幣、生命、已蓋的塔）會全部清除，確定要重置嗎？',
        actions: [
          _dialogButton('取消', () => Navigator.pop(ctx), filled: false),
          const SizedBox(width: 12),
          _dialogButton('確定重置', () {
            Navigator.pop(ctx);
            onRestart();
          }, filled: true, color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _infoPanel() {
    return ValueListenableBuilder<TowerType?>(
      valueListenable: game.selecting,
      builder: (context, type, _) {
        if (type == null) return const SizedBox.shrink();
        final stats = statsOf(type);
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 150),
          decoration: _panelBox(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox.square(
                  dimension: 48,
                  child: ClipPath(
                    clipper: const BottomSemicircleClipper(),
                    child: towerIcon(type),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(stats.title, textAlign: TextAlign.center),
              const SizedBox(height: 16.0),
              Text(stats.description),
              const SizedBox(height: 16.0),
              Text('花費: ${stats.cost}'),
              Text('範圍: ${stats.range}'),
              if (stats.damage > 0) Text('傷害: ${stats.damage}'),
            ],
          ),
        );
      },
    );
  }

  /// 點到格子時顯示資訊：塔(可拆除) / 主堡 / 敵人出生點。
  Widget _inspectPanel() {
    return AnimatedBuilder(
      animation:
          Listenable.merge([game.inspecting, game.towerChanged, game.coin]),
      builder: (context, _) {
        final bp = game.inspecting.value;
        if (bp == null) return const SizedBox.shrink();

        late final Widget icon;
        late final String title;
        late final List<String> lines;
        var tower = false;
        var env = false;

        if (bp == game.targetLocation) {
          icon = const Icon(Icons.castle, color: Colors.green, size: 44);
          title = '主堡（終點）';
          lines = ['守住這裡！', '敵人抵達會扣 1 生命', '生命歸零即遊戲結束'];
        } else if (bp == game.spawnLocation) {
          icon = const Icon(Icons.flag, color: Colors.redAccent, size: 44);
          title = '敵人出生點';
          lines = ['敵人從這裡出現', '沿著路線前往主堡'];
        } else if (game.environment.containsKey(bp)) {
          env = true;
          final e = game.environment[bp]!;
          icon = const Icon(Icons.terrain, color: Color(0xFF6D4C41), size: 44);
          title = e.label;
          lines = [e.desc, e.blocks ? '（阻擋路線）' : '（可經過）'];
        } else {
          final type = game.typeAt(bp);
          if (type == null) return const SizedBox.shrink();
          tower = true;
          final stats = statsOf(type);
          // 已蓋的塔用「有效數值」getter（含升級加成，與實際判定/射程圈一致）；
          // 陷阱不在 towers 裡 → 退回基礎值。
          final t = game.towers[bp];
          final range = t?.range ?? stats.range;
          final damage = t?.damage ?? stats.damage;
          icon = SizedBox.square(dimension: 48, child: ClipOval(child: towerIcon(type)));
          title = stats.title;
          lines = type == TowerType.obstacle
              ? const ['阻擋敵人前進']
              : [
                  '範圍: $range',
                  if (damage > 0) '傷害: $damage',
                ];
        }

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 150),
          decoration: _panelBox(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: icon),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              for (final l in lines)
                Text(l, style: const TextStyle(fontSize: 13)),
              if (game.isLogTower(bp)) ...[
                const SizedBox(height: 8),
                const Text(
                  '滾木方向',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => game.rotateLog(bp, -1),
                      icon: const Icon(Icons.rotate_left),
                      iconSize: 26,
                      color: Colors.brown,
                      tooltip: '逆時針',
                    ),
                    IconButton(
                      onPressed: () => game.rotateLog(bp, 1),
                      icon: const Icon(Icons.rotate_right),
                      iconSize: 26,
                      color: Colors.brown,
                      tooltip: '順時針',
                    ),
                  ],
                ),
              ],
              if (tower) _upgradeControl(bp),
              if (tower) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => game.demolishAt(bp),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('拆除'),
                ),
              ],
              if (env) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => game.clearEnvironmentAt(bp),
                  icon: const Icon(Icons.cleaning_services, size: 18),
                  label: Text('清除 (${TowerDefenseGame.envClearCost})'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 塔升級區：分支樹。顯示等級、已選路徑，並在可升級時並排兩張選項卡（二擇一）。
  Widget _upgradeControl(BoardPoint bp) {
    final type = game.typeAt(bp);
    if (type == null || maxLevelOf(type) <= 1) return const SizedBox.shrink();
    final lv = game.towerLevel(bp);
    final tower = game.towers[bp];
    final options = game.upgradeOptions(bp);
    final chosenPath = (tower == null || tower.chosen.isEmpty)
        ? null
        : tower.chosen.map((n) => n.name).join(' ▸ ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          '等級 $lv / ${maxLevelOf(type)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        if (chosenPath != null) ...[
          const SizedBox(height: 2),
          Text('已選：$chosenPath',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.brown)),
        ],
        if (options.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            lv == 1 ? '選擇升級方向（二擇一，選了就鎖）' : '選擇強化（二擇一）',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          // 面板窄（maxWidth 150），兩張選項卡改上下堆疊（各佔滿寬），避免爆版。
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _upgradeOptionCard(bp, options[i]),
          ],
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('已滿級',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
      ],
    );
  }

  /// 單張升級選項卡（名稱 / 說明 / 升級鈕；金幣不足時禁用）。
  Widget _upgradeOptionCard(BoardPoint bp, TowerUpgradeNode node) {
    final affordable = game.cheat.value || game.coin.value >= node.cost;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(node.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown)),
          const SizedBox(height: 2),
          Text(node.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 4),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: const Size(0, 30),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: affordable ? () => game.upgradeTower(bp, node) : null,
            child: Text('升級 (${node.cost})'),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [game.gameOver, game.gameWon, game.waveRunning, game.wave],
      ),
      builder: (context, _) {
        final ended = game.gameOver.value || game.gameWon.value;
        final running = game.waveRunning.value;
        final allDone = game.waveNumber >= TowerDefenseGame.totalWaves;
        final canStart = !ended && !running && !allDone;

        final String label;
        if (running) {
          label = '第 ${game.waveNumber} 波進行中…';
        } else if (allDone) {
          label = '全部完成';
        } else if (game.waveNumber == 0) {
          label = '開始遊戲';
        } else {
          label = '下一波 (${game.waveNumber + 1}/${TowerDefenseGame.totalWaves})';
        }

        final button = ElevatedButton.icon(
          onPressed: canStart ? game.startGame : null,
          icon: const Icon(Icons.play_circle),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade600,
            disabledForegroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );

        return Padding(
          padding: const EdgeInsets.all(8),
          // 可按時用輕微脈動提示玩家「現在可以開下一波了」。
          child: canStart
              ? button
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 1.0,
                    end: 1.06,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                  )
              : button,
        );
      },
    );
  }

  /// 敵人圖鑑：已解鎖敵人的頭像列（水平可捲動），點擊浮出資訊卡。
  Widget _enemyBestiary() {
    return ValueListenableBuilder<int>(
      valueListenable: game.wave,
      builder: (context, _, __) {
        final kinds = game.unlockedKinds();
        return ValueListenableBuilder<EnemyKind?>(
          valueListenable: game.inspectingEnemy,
          builder: (context, sel, ___) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final k in kinds) ...[
                  _enemyAvatarButton(k, sel == k),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _enemyAvatarButton(EnemyKind kind, bool selected) {
    return GestureDetector(
      onTap: () =>
          game.inspectingEnemy.value = selected ? null : kind,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.orangeAccent : Colors.white24,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _EnemyAvatarPainter(game.enemySheets[kind.id], kind),
        ),
      ),
    );
  }

  /// 敵人資訊卡：顯示被點選敵人的特性。
  Widget _enemyInfoCard() {
    return ValueListenableBuilder<EnemyKind?>(
      valueListenable: game.inspectingEnemy,
      builder: (context, kind, _) {
        if (kind == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxWidth: 230),
          decoration: _panelBox(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: CustomPaint(
                      painter:
                          _EnemyAvatarPainter(game.enemySheets[kind.id], kind),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    kind.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(kind.desc, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text('血量：${_hpLabel(kind)}　速度：${_spdLabel(kind)}',
                  style: const TextStyle(fontSize: 12)),
              Text('賞金：${kind.reward}　漏過扣血：${kind.leakDamage}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  String _hpLabel(EnemyKind k) => k.hpMul < 0.5
      ? '低'
      : k.hpMul < 1.5
          ? '普通'
          : k.hpMul < 4
              ? '高'
              : '極高';

  String _spdLabel(EnemyKind k) =>
      k.speedMul < 0.8 ? '慢' : (k.speedMul <= 1.3 ? '普通' : '快');
}

/// 設定抽屜：特效開關（由左上「設定」鈕開啟）。
/// 作弊模式與重新開始鈕都在左上 HUD、不在此。
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key, required this.game});
  final TowerDefenseGame game;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      backgroundColor: const Color(0xFF241811), // 深木底
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.settings, color: _kGold, size: 24),
                  SizedBox(width: 10),
                  Text('設定',
                      style: TextStyle(
                          color: _kGold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(color: _kGoldDeep, height: 1),
            _sectionHeader('特效'),
            _switchTile(game.dimFlame,
                () => game.dimFlame.value = !game.dimFlame.value,
                Icons.local_fire_department, '火焰特效變淡', Colors.orangeAccent),
            _switchTile(
                game.waterReflection,
                () => game.waterReflection.value = !game.waterReflection.value,
                Icons.water,
                '水面倒影',
                Colors.lightBlueAccent),
            _sectionHeader('音訊'),
            _switchTile(
                GameAudio.sfxOn,
                () => GameAudio.sfxOn.value = !GameAudio.sfxOn.value,
                Icons.volume_up,
                '音效',
                _kGold),
            _volumeTile(
              GameAudio.sfxOn,
              GameAudio.sfxVol,
              // 放開滑條時播一聲金幣試聽，立刻感受音量。
              onChangeEnd: () =>
                  GameAudio.ui('coin', volume: 0.45, throttleMs: 0),
            ),
            _switchTile(
                GameAudio.bgmOn,
                () => GameAudio.bgmOn.value = !GameAudio.bgmOn.value,
                Icons.music_note,
                '音樂',
                _kGold),
            _volumeTile(GameAudio.bgmOn, GameAudio.bgmVol),
            const Spacer(),
            // 音樂授權標註（xDeviruchi 授權條款要求）。
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Music: Alexandr Zhelanov (CC-BY 3.0)\n'
                'Victory theme by Marllon Silva (xDeviruchi)\n'
                'SFX: artisticdude (CC-BY 3.0), Kenney (CC0)',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 分區標題（特效 / 音訊…）：小字灰金、與上方拉開間距。
  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
      child: Text(
        label,
        style: TextStyle(
          color: _kGoldDeep.withOpacity(0.9),
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  /// 單一開關列：圖示 + 標籤 + CupertinoSwitch；開啟時以 [onColor] 上色。
  Widget _switchTile(ValueListenable<bool> vn, VoidCallback onToggle,
      IconData icon, String label, Color onColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: vn,
      builder: (context, on, _) => ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        leading: Icon(icon, color: on ? onColor : Colors.grey[500]),
        title: Text(label,
            style: TextStyle(
                color: on ? onColor : Colors.grey[300],
                fontWeight: FontWeight.bold)),
        trailing: CupertinoSwitch(
            value: on,
            onChanged: (_) {
              GameAudio.ui('switch', volume: 0.6);
              onToggle();
            }),
        onTap: () {
          GameAudio.ui('switch', volume: 0.6);
          onToggle();
        },
      ),
    );
  }

  /// 音量滑條列（縮排在開關列之下）：對應開關關閉時變暗、不可拖。
  /// [onChangeEnd] 放開滑條時呼叫（試聽用）。
  Widget _volumeTile(ValueListenable<bool> onVn, ValueNotifier<double> vol,
      {VoidCallback? onChangeEnd}) {
    return ValueListenableBuilder<bool>(
      valueListenable: onVn,
      builder: (context, on, _) => ValueListenableBuilder<double>(
        valueListenable: vol,
        builder: (context, v, _) => Padding(
          padding: const EdgeInsets.only(left: 40, right: 16),
          // SizedBox + noOverlay：去掉 Slider 預設的 48px 保留高度與外圈光暈，
          // 讓滑條貼近上方的開關列。
          child: SizedBox(
            height: 26,
            child: SliderTheme(
              data: SliderThemeData(
                // 開啟：金色已填段 + 淡白底軌。
                activeTrackColor: _kGold,
                inactiveTrackColor: Colors.white24,
                thumbColor: _kGold,
                // 關閉（onChanged=null → disabled 狀態吃這組）：整體轉灰但
                // 「已填段(灰) vs 底軌(淡白)」仍有層次，深木底上看得到。
                disabledActiveTrackColor: Colors.grey[600],
                disabledInactiveTrackColor: Colors.white12,
                disabledThumbColor: Colors.grey[600],
                overlayShape: SliderComponentShape.noOverlay,
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: v,
                onChanged: on ? (nv) => vol.value = nv : null,
                onChangeEnd: on ? (_) => onChangeEnd?.call() : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
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

/// 底部：防禦塔選單。點擊選取要蓋的塔。
class BuildBar extends StatefulWidget {
  const BuildBar({super.key, required this.game});
  final TowerDefenseGame game;

  @override
  State<BuildBar> createState() => _BuildBarState();
}

class _BuildBarState extends State<BuildBar> {
  TowerDefenseGame get game => widget.game;
  int _tab = 0;

  /// 建造分類頁籤（涵蓋全部塔種）。
  static const List<(String, List<TowerType>)> _cats = [
    ('元素', [
      TowerType.flame,
      TowerType.freezing,
      TowerType.thunder,
      TowerType.poison,
    ]),
    ('物理', [TowerType.log, TowerType.cannon, TowerType.airBlade]),
    ('陷阱', [TowerType.spike, TowerType.vortex]),
    ('支援', [TowerType.multishot, TowerType.obstacle]),
  ];

  static const double _tabH = 34; // 分頁列高度

  @override
  Widget build(BuildContext context) {
    // Chrome 分頁感：頁籤嵌在底部 bar 上方；用 Stack 讓分頁畫在 bar 之上，選中頁籤
    // 往下凸並蓋住 bar 頂邊 → 與內容連成一體。
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _tabH),
          child: _barBody(),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SizedBox(height: _tabH, child: _tabStrip()),
        ),
      ],
    );
  }

  /// 分頁列（水平；超出可左右捲）。
  Widget _tabStrip() {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none, // 讓選中頁籤往下凸出不被裁掉
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end, // 底部對齊到 bar 頂
          children: [for (var i = 0; i < _cats.length; i++) _chromeTab(i)],
        ),
      ),
    );
  }

  /// 單一分頁（頂部圓角）：選中＝漸層（底色收在 bar 頂色→無斷層）+ 金框，往下凸
  /// 3px 與 bar 連成一體；未選＝暗底、較矮（凹陷感）。
  Widget _chromeTab(int i) {
    final sel = i == _tab;
    final tab = Container(
      margin: const EdgeInsets.only(right: 3),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: sel ? 7 : 5),
      decoration: BoxDecoration(
        gradient: sel ? _kSelTabGradient : null,
        color: sel ? null : const Color(0xFF241811),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(
          top: BorderSide(
              color: sel ? _kGoldDeep : _kGoldDeep.withOpacity(0.4),
              width: sel ? 2 : 1),
          left: BorderSide(
              color: sel ? _kGoldDeep : _kGoldDeep.withOpacity(0.4),
              width: sel ? 2 : 1),
          right: BorderSide(
              color: sel ? _kGoldDeep : _kGoldDeep.withOpacity(0.4),
              width: sel ? 2 : 1),
        ),
      ),
      child: Text(
        _cats[i].$1,
        style: TextStyle(
          color: sel ? _kGold : const Color(0xFFB0A088),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
    return MouseRegion(
      // 桌面滑鼠懸停的輕微音（觸控裝置無 hover、不觸發）。
      onEnter: (_) => GameAudio.ui('hover', volume: 0.3, throttleMs: 90),
      child: GestureDetector(
        onTap: () {
          GameAudio.ui('click', volume: 0.5);
          setState(() => _tab = i);
        },
        child: sel
            ? Transform.translate(offset: const Offset(0, 2), child: tab)
            : tab,
      ),
    );
  }

  /// 底部 bar 本體：木紋底 + 頂部金邊 + 該分類的塔列。
  Widget _barBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: _kWoodGradient,
        border: Border(top: BorderSide(color: _kGoldDeep, width: 2)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: SizedBox(width: double.infinity, height: 82, child: _towerRow()),
      ),
    );
  }

  /// 目前分類的塔按鈕列（右側保留全螢幕鈕）。
  Widget _towerRow() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // 預留右側空間給全螢幕鈕，避免最右邊的塔被蓋住點不到。
          padding: EdgeInsets.only(right: kIsWeb ? 48 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              for (final type in _cats[_tab].$2) _icon(type),
            ],
          ),
        ),
        if (kIsWeb)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _fullscreenButton(),
          ),
      ],
    );
  }

  Widget _fullscreenButton() {
    return IconButton(
      iconSize: 26,
      tooltip: '全螢幕',
      onPressed: toggleFullscreen,
      icon: const Icon(Icons.fullscreen, color: Colors.white),
    );
  }

  Widget _icon(TowerType type) {
    final button = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 3,
          ),
        ],
      ),
      // Material(圓形 + 裁切) + InkWell(圓形邊界) → 圓形水波，不再是方形。
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          // 桌面滑鼠懸停的輕微音（觸控裝置無 hover、不觸發）。
          onHover: (h) {
            if (h) GameAudio.ui('hover', volume: 0.3, throttleMs: 90);
          },
          onTap: () {
            GameAudio.ui('select', volume: 0.6);
            game.selectTower(type);
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: _kGoldDeep, width: 4, strokeAlign: BorderSide.strokeAlignCenter)),
              shape: BoxShape.circle,
            ),
            child: ClipOval(child: towerIcon(type)),
          ),
        ),
      ),
    );

    // 障礙物在圓鈕右上角疊剩餘數量徽章。
    final Widget circle = type == TowerType.obstacle
        ? ValueListenableBuilder<int>(
            valueListenable: game.freeObstacle,
            builder: (context, count, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  child!,
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            child: button,
          )
        : button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 3),
        _costLabel(type),
      ],
    );
  }

  /// 塔按鈕下方的費用標籤（障礙物顯示「免費」）。
  Widget _costLabel(TowerType type) {
    if (type == TowerType.obstacle) {
      return const Text('免費',
          style: TextStyle(
              color: _kGold, fontSize: 11, fontWeight: FontWeight.bold));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _uiIcon('coin', 14),
        const SizedBox(width: 2),
        Text('${statsOf(type).cost}',
            style: const TextStyle(
                color: _kGold, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 遊戲結束：遮罩 + 勝利 / 失敗卡片 + 重新開始。
class EndOverlay extends StatelessWidget {
  const EndOverlay({super.key, required this.game, required this.onRestart});
  final TowerDefenseGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.gameOver, game.gameWon]),
      builder: (context, _) {
        final won = game.gameWon.value;
        final lost = game.gameOver.value;
        if (!won && !lost) return const SizedBox.shrink();

        return Stack(
          children: [
            const ModalBarrier(color: Colors.black54, dismissible: false),
            _themedDialog(
              icon: won ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
              accent: won ? _kGold : Colors.redAccent,
              title: won ? '勝利！' : '遊戲結束',
              message: won ? '你成功守住了主堡！' : '主堡失守了……再挑戰一次！',
              actions: [
                _dialogButton('重新開始', onRestart),
              ],
            ),
          ],
        );
      },
    );
  }
}
