part of 'game_overlays.dart';

// ═══ 主題：色票/漸層/木質外框/彈窗元件（_kGold、_woodBox、_themedDialog…） ═══

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
                    color: Color(0xFFE8DCC0), fontSize: 14, height: 1.4)),
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
