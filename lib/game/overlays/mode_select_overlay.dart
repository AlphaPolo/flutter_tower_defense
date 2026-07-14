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
        // 首屏氛圍：低飽和光暈在暗化棋盤上緩慢漂移（金＝品牌、紫＝無盡）。
        // 純徑向漸層、無模糊濾鏡 → web 上便宜；reduce-motion 時靜止。
        IgnorePointer(child: _ambient(context)),
        Center(
          child: Container(
            margin: const EdgeInsets.all(24).h,
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24).h,
            constraints: const BoxConstraints(maxWidth: 340).h,
            decoration: _dialogBox(),
            child: LayoutBuilder(
              builder: (context, constraint) {
                // 卡片 stagger：彈窗彈出後依序浮現（reduce-motion 直接顯示）。
                Widget stagger(int i, Widget child) {
                  if (_reduceMotion(context)) return child;
                  final delay = (150 + 80 * i).ms;
                  return child
                      .animate()
                      .fadeIn(
                          delay: delay, duration: 200.ms, curve: Curves.easeOut)
                      .slideY(
                          begin: 0.12,
                          end: 0,
                          delay: delay,
                          duration: 240.ms,
                          curve: Curves.easeOutCubic);
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 遊戲徽章 + 名稱
                    if (constraint.maxHeight > 300)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _floaty(
                          context,
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16).h,
                            child: Image.asset(
                              'assets/images/logo_256.png',
                              width: 72.h, height: 72.h, fit: BoxFit.cover,
                            ),
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
                    stagger(0, _modeCard(
                      icon: Icons.play_circle,
                      color: Colors.green,
                      title: '闖關模式',
                      subtitle: '守住 ${TowerDefenseGame.totalWaves} 波，贏得勝利',
                      onTap: () => onChosen(false),
                    )),
                    SizedBox(height: 10.h),
                    stagger(1, ValueListenableBuilder<int>(
                      valueListenable: game.bestEndless,
                      builder: (context, best, _) => _modeCard(
                        icon: Icons.all_inclusive,
                        color: const Color(0xFF7E57C2),
                        title: '無盡模式',
                        subtitle: best > 0 ? '最佳紀錄：$best 波' : '波次無盡，拚最高紀錄',
                        onTap: () => onChosen(true),
                      ),
                    )),
                    SizedBox(height: 12.h),
                    // 排行榜（無盡模式，季號分桶）：監聽 available——init 是非同步的，
                    // 選單常在它完成前就 build，好了按鈕即時浮現；失敗則一直隱藏。
                    stagger(2, ValueListenableBuilder<bool>(
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
                    )),
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

  /// 首屏氛圍層：三團光暈各自以不同週期緩慢漂移（8~12 秒往返）。
  Widget _ambient(BuildContext context) {
    Widget blob(
        Color color, double size, Alignment align, Offset drift, int ms) {
      Widget b = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      );
      if (!_reduceMotion(context)) {
        b = b
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .move(end: drift, duration: ms.ms, curve: Curves.easeInOut);
      }
      return Align(alignment: align, child: b);
    }

    return Stack(children: [
      blob(_kGold.withValues(alpha: 0.10), 420, const Alignment(-1.1, -0.9),
          const Offset(60, 40), 9000),
      blob(const Color(0xFF7E57C2).withValues(alpha: 0.08), 380,
          const Alignment(1.2, 1.0), const Offset(-50, -30), 12000),
      blob(_kGoldDeep.withValues(alpha: 0.06), 300, const Alignment(0.9, -1.1),
          const Offset(-40, 50), 10500),
    ]);
  }

  /// logo 微浮動（2.8 秒上下 3px；reduce-motion 靜止）。
  Widget _floaty(BuildContext context, Widget child) {
    if (_reduceMotion(context)) return child;
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -3, duration: 2800.ms, curve: Curves.easeInOut);
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
