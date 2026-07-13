part of 'game_overlays.dart';

// ═══ 開場模式選單（闖關/無盡） ═══

/// 開場模式選單：蓋在整個畫面上（棋盤當背景），選「闖關 / 無盡」後才進場。
/// 重新開始會再次顯示。
class ModeSelectOverlay extends StatelessWidget {
  const ModeSelectOverlay({super.key, required this.game, required this.onChosen});
  final TowerDefenseGame game;
  final void Function(bool endless) onChosen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Center(
          child: Container(
            margin: const EdgeInsets.all(24).h,
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24).h,
            constraints: const BoxConstraints(maxWidth: 340).h,
            decoration: _dialogBox(),
            child: LayoutBuilder(
              builder: (context, constraint) {
                print(constraint.maxHeight);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 遊戲徽章 + 名稱
                    if (constraint.maxHeight > 300)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16).h,
                          child: Image.asset(
                            'assets/images/logo_256.png',
                            width: 72.h, height: 72.h, fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Text(
                      '元素塔防',
                      style: TextStyle(color: _kGold, fontSize: 26.h, fontWeight: FontWeight.w900, letterSpacing: 4),
                    ),
                    SizedBox(height: 4.h),
                    Text('選擇模式', style: TextStyle(color: _kTextDim, fontSize: 13.h)),
                    SizedBox(height: 18.h),
                    _modeCard(
                      icon: Icons.play_circle,
                      color: Colors.green,
                      title: '闖關模式',
                      subtitle: '守住 ${TowerDefenseGame.totalWaves} 波，贏得勝利',
                      onTap: () => onChosen(false),
                    ),
                    SizedBox(height: 10.h),
                    ValueListenableBuilder<int>(
                      valueListenable: game.bestEndless,
                      builder: (context, best, _) => _modeCard(
                        icon: Icons.all_inclusive,
                        color: const Color(0xFF7E57C2),
                        title: '無盡模式',
                        subtitle: best > 0 ? '最佳紀錄：$best 波' : '波次無盡，拚最高紀錄',
                        onTap: () => onChosen(true),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // 排行榜（無盡模式，季號分桶）：監聽 available——init 是非同步的，
                    // 選單常在它完成前就 build，好了按鈕即時浮現；失敗則一直隱藏。
                    ValueListenableBuilder<bool>(
                      valueListenable: Leaderboard.available,
                      builder: (context, ok, _) => !ok
                          ? const SizedBox.shrink()
                          : TextButton.icon(
                              onPressed: () {
                                GameAudio.ui('click', volume: 0.5);
                                showLeaderboardDialog(context);
                              },
                              icon: const Icon(Icons.emoji_events,
                                  color: _kGold, size: 20),
                              label: const Text('排行榜',
                                  style: TextStyle(
                                      color: _kGold,
                                      fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ],
                );
              }
            ),
          )
              .animate()
              .fadeIn(duration: 180.ms)
              .scale(
                begin: const Offset(0.25, 1.5),
                duration: 300.ms,
                curve: const Cubic(0.34, 1.56, 0.64, 1),
              ),
        ),
      ],
    );
  }

  /// 模式卡片：色塊圖示 + 標題 + 副標，整卡可點。
  Widget _modeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        GameAudio.ui('confirm', volume: 0.6);
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.h, vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 1.6),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30.h),
            SizedBox(width: 12.h),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontSize: 17.h, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(subtitle, style: TextStyle(color: _kTextSoft, fontSize: 12.h)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
