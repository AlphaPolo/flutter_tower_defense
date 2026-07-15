part of 'game_overlays.dart';

// ═══ 主題：色票/漸層/木質外框/彈窗元件（_kGold、_woodBox、_themedDialog…） ═══

// ── HUD 主題：奇幻木質風（暖木底 + 金銅邊 + 柔和陰影）───────────────────
/// 尊重系統「減少動態效果」設定：true 時動效降級為直接顯示。
bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

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
BoxDecoration _woodBox(
        {double radius = 20, bool strong = true, Color? borderColor}) =>
    BoxDecoration(
      gradient: _kWoodGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: borderColor ?? _kGoldDeep.withValues(alpha: 0.85),
          width: 1.3),
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

/// game-icons.net 白色 alpha 圖示（srcIn 染色）——取代 Material Icons，
/// 與像素 UI 同視覺語言。素材 assets/ui/gi_<name>.png（128px，CC BY 3.0，
/// 來源對照見 assets/ui/SOURCES.md）。
Widget _gi(String name, {double? size, Color color = _kGold}) => Image.asset(
      'assets/ui/gi_$name.png',
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
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
  required String icon, // game-icons 名（見 _gi）
  required Color accent,
  required String title,
  String? message,
  Widget? extra, // 插在訊息與動作列之間的自訂區塊（如上傳成績）
  required List<Widget> actions,
}) {
  return Builder(builder: (context) {
    final card = Container(
      // 固定設計畫布：內部全用絕對數字排版；裝不下時整張等比縮小。
      width: 340,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: _dialogBox(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gi(icon, size: 46, color: accent),
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
    );
    // flutter_animate 入場：淡入 + 由小彈出（easeOutBack 過衝），有彈跳感。
    final animated = _reduceMotion(context)
        ? card
        : card.animate().fadeIn(duration: 180.ms).scale(
              begin: const Offset(0.25, 1.5),
              duration: 300.ms,
              curve: const Cubic(0.34, 1.56, 0.64, 1),
            );
    // 路線2「固定畫布」：鍵盤/小螢幕吃掉空間時，整張卡等比縮小塞進
    // 剩餘空間 → 永不溢出，比例永遠跟設計稿一致。
    // Material：showDialog 的 route 沒有 Material 祖先（以前 AlertDialog 自帶），
    // 卡片裡有 TextField（改暱稱/上傳成績）沒有它會直接 throw。
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(16),
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: animated),
        ),
      ),
    );
  });
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
  final String? icon; // game-icons 名（見 _gi）
  final _WoodTone tone;
  final bool dense;

  @override
  State<_WoodButton> createState() => _WoodButtonState();
}

class _WoodButtonState extends State<_WoodButton> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    var (top, bottom) = _woodToneColors(enabled ? widget.tone : null);
    if (_hover && enabled && !_pressed) {
      // 桌面 hover：整體提亮一階（觸控裝置不會觸發）。
      top = Color.lerp(top, Colors.white, 0.08)!;
      bottom = Color.lerp(bottom, Colors.white, 0.08)!;
    }
    final fg = enabled ? _kParchment : _kTextFaint;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
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
                color: _kGoldDeep.withValues(
                    alpha: !enabled ? 0.4 : (_hover ? 1.0 : 0.9)),
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
                _gi(widget.icon!, size: (widget.dense ? 14 : 16).h, color: fg),
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
      ),
    );
  }
}

// ═══ 頂部訊息 toast：取代素顏紅色 MaterialBanner ═══

/// 給 [showTopMessage] 取得 overlay 用；由 MyApp 綁進 MaterialApp.navigatorKey。
final GlobalKey<NavigatorState> gameNavigatorKey = GlobalKey<NavigatorState>();

OverlayEntry? _toastEntry;
Timer? _toastTimer;

/// 頂部彈出一則木質膠囊提示（金幣不足/拆除退款/操作指引共用），
/// [duration] 後自動收起；再次呼叫直接替換。浮在遊戲上、不擋點擊。
void showTopMessage(String message,
    {Duration duration = const Duration(seconds: 2)}) {
  final overlay = gameNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _toastTimer?.cancel();
  _toastEntry?.remove();
  final entry = OverlayEntry(
    builder: (_) => _TopToast(message: message, holdMs: duration.inMilliseconds),
  );
  _toastEntry = entry;
  overlay.insert(entry);
  // 移除交給外部 timer（widget 內的退場動畫剛好在此之前結束）。
  _toastTimer = Timer(duration, () {
    if (_toastEntry == entry) {
      _toastEntry = null;
      entry.remove();
    }
  });
}

class _TopToast extends StatelessWidget {
  const _TopToast({required this.message, required this.holdMs});
  final String message;
  final int holdMs;

  @override
  Widget build(BuildContext context) {
    Widget pill = Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9).h,
      decoration: _woodBox(radius: 22),
      child: Text(
        message,
        style: TextStyle(
            color: _kTextSoft, fontSize: 14.h, fontWeight: FontWeight.bold),
      ),
    );
    if (!_reduceMotion(context)) {
      // 進場：上方滑入＋淡入；停留後淡出上滑（退場結束略早於 entry 移除）。
      final out = (holdMs - 400).clamp(0, 1 << 30);
      pill = pill
          .animate()
          .fadeIn(duration: 160.ms, curve: Curves.easeOut)
          .slideY(begin: -0.6, end: 0, duration: 200.ms, curve: Curves.easeOutCubic)
          .then(delay: (out - 200).clamp(0, 1 << 30).ms)
          .fadeOut(duration: 200.ms)
          .slideY(end: -0.4, duration: 200.ms);
    }
    // OverlayEntry 不在任何 Material 之下 → 不包會出現黃底線除錯字樣。
    return Material(
      type: MaterialType.transparency,
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(padding: EdgeInsets.only(top: 10.h), child: pill),
          ),
        ),
      ),
    );
  }
}
