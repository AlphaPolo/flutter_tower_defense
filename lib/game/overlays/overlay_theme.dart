part of 'game_overlays.dart';

// ═══ 主題：色票/漸層/木質外框/彈窗元件（_kGold、_woodBox、_themedDialog…） ═══

// ── HUD 主題：奇幻木質風（暖木底 + 金銅邊 + 柔和陰影）───────────────────
// ── 色票 token：overlay 一律引用具名色，不散落裸 hex ────────────────
const Color _kGold = Color(0xFFE8C877); // 金銅亮（標題/高亮）
const Color _kGoldDeep = Color(0xFFB6832B); // 金銅暗（描邊）
const Color _kWoodLight = Color(0xFF574029); // 木質亮（選中頁籤頂）
const Color _kWoodMid = Color(0xFF4A3627); // 木質中（木框漸層頂）
const Color _kWoodDark = Color(0xFF241811); // 木質暗（木框漸層底/深色文字）
const Color _kParchment = Color(0xFFF8EED6); // 羊皮紙亮（內容卡頂/按鈕文字）
const Color _kParchmentDark = Color(0xFFEAD8AE); // 羊皮紙暗（內容卡底）
const Color _kTextSoft = Color(0xFFE8DCC0); // 木質面上的柔和內文
const Color _kTextDim = Color(0xFFD8C9A6); // 木質面上的次要文字
const Color _kTextFaint = Color(0xFFB0A088); // 木質面上的弱化文字（未選/停用）

const LinearGradient _kWoodGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_kWoodMid, _kWoodDark],
);

/// 選中分頁的漸層：底部收在「bar 頂端的顏色」(#4A3627) → 分頁底＝bar 頂、同色
/// 相接，連接處不會有顏色斷層；頂部再稍亮做立體感。
const LinearGradient _kSelTabGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_kWoodLight, _kWoodMid],
);

/// 木質膠囊/列的通用外框：木紋漸層 + 金銅細邊 + 柔和陰影。
/// [strong] 決定陰影深淺（大面板用深、小晶片用淺）。
BoxDecoration _woodBox({double radius = 20, bool strong = true}) =>
    BoxDecoration(
      gradient: _kWoodGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _kGoldDeep.withValues(alpha: 0.85), width: 1.3),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: strong ? 0.45 : 0.3),
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
        colors: [_kParchment, _kParchmentDark],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _kGoldDeep.withValues(alpha: 0.7), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
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
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

/// 統一彈窗按鈕：[filled] 為主要動作（木質按鈕、[tone] 色調）；
/// 否則為次要動作（安靜的文字鈕）。
Widget _dialogButton(String label, VoidCallback onTap,
    {bool filled = true, _WoodTone tone = _WoodTone.gold}) {
  if (!filled) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: _kTextDim),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
  return _WoodButton(label: label, onPressed: onTap, tone: tone);
}

/// 統一風格彈窗面板（勝利／失敗／確認共用）：圖示 + 標題 + 說明 + 動作列。
Widget _themedDialog({
  required IconData icon,
  required Color accent,
  required String title,
  String? message,
  Widget? extra, // 插在訊息與動作列之間的自訂區塊（如上傳成績）
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
                    color: _kTextSoft, fontSize: 14, height: 1.4)),
          ],
          if (extra != null) ...[
            const SizedBox(height: 14),
            extra,
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

// ═══ 木質按鈕：取代素顏 ElevatedButton 的統一控件 ═══

/// 按鈕色調：決定漸層底色；金銅描邊與按壓行為全色調一致。
enum _WoodTone { gold, wood, danger, warn }

/// 各色調的漸層端點（上亮下暗，光源同 [_woodBox]）；null＝停用的灰木。
(Color, Color) _woodToneColors(_WoodTone? tone) => switch (tone) {
      _WoodTone.gold => (const Color(0xFFC9963C), const Color(0xFF9E6F22)),
      _WoodTone.wood => (_kWoodLight, const Color(0xFF3A2A1D)),
      _WoodTone.danger => (const Color(0xFF9E3B32), const Color(0xFF75261F)),
      _WoodTone.warn => (const Color(0xFFB86A26), const Color(0xFF8F4F1B)),
      null => (const Color(0xFF564E44), const Color(0xFF413A32)),
    };

/// 木質按鈕：木紋漸層＋金銅邊＋按壓下沉（70ms 微回饋）。
/// [onPressed] 為 null＝停用（灰木、無陰影）。[dense]＝面板內的小尺寸。
class _WoodButton extends StatefulWidget {
  const _WoodButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = _WoodTone.gold,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final _WoodTone tone;
  final bool dense;

  @override
  State<_WoodButton> createState() => _WoodButtonState();
}

class _WoodButtonState extends State<_WoodButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (top, bottom) = _woodToneColors(enabled ? widget.tone : null);
    final fg = enabled ? _kParchment : _kTextFaint;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        height: (widget.dense ? 30 : 38).h,
        padding: EdgeInsets.symmetric(horizontal: widget.dense ? 10 : 16).h,
        // 按下：往下沉 1.5px、漸層壓平、收掉陰影 → 實體按鍵手感。
        transform: Matrix4.translationValues(0, _pressed ? 1.5 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pressed ? [bottom, bottom] : [top, bottom],
          ),
          borderRadius: BorderRadius.circular(9).h,
          border: Border.all(
              color: _kGoldDeep.withValues(alpha: enabled ? 0.9 : 0.4),
              width: 1.2),
          boxShadow: [
            if (enabled && !_pressed)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: (widget.dense ? 14 : 16).h, color: fg),
              SizedBox(width: 6.h),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: fg,
                fontSize: (widget.dense ? 12 : 13).h,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
