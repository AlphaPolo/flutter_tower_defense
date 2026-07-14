part of 'game_overlays.dart';

// ═══ 結束彈窗（勝/敗）＋無盡成績上傳區塊 ═══

/// 無盡戰敗彈窗裡的「上傳成績」區塊：暱稱可改、可選擇不傳。
/// 狀態：詢問中 → 上傳中 → 已上傳/未破紀錄；「不上傳」直接收起。
class _EndlessUploadSection extends StatefulWidget {
  const _EndlessUploadSection({required this.waves});
  final int waves;

  @override
  State<_EndlessUploadSection> createState() => _EndlessUploadSectionState();
}

enum _UploadState { asking, busy, done, rejected, skipped }

class _EndlessUploadSectionState extends State<_EndlessUploadSection> {
  final _name = TextEditingController();
  var _state = _UploadState.asking;

  @override
  void initState() {
    super.initState();
    Leaderboard.playerName().then((n) {
      if (mounted && _name.text.isEmpty) _name.text = n;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    setState(() => _state = _UploadState.busy);
    await Leaderboard.setPlayerName(_name.text); // 先存暱稱（不重送）
    final ok = await Leaderboard.submit(widget.waves);
    if (!mounted) return;
    setState(() => _state = ok ? _UploadState.done : _UploadState.rejected);
  }

  @override
  Widget build(BuildContext context) {
    if (!Leaderboard.available.value) return const SizedBox.shrink();
    switch (_state) {
      case _UploadState.skipped:
        return const SizedBox.shrink();
      case _UploadState.done:
        return const Text('✓ 已上傳排行榜',
            style: TextStyle(color: _kGold, fontWeight: FontWeight.bold));
      case _UploadState.rejected:
        return Text('未超過你在榜上的紀錄（或連線失敗），未上傳',
            style: TextStyle(color: Colors.grey[400], fontSize: 12.5));
      case _UploadState.busy:
        return const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: _kGold, strokeWidth: 2.5));
      case _UploadState.asking:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 暱稱（可直接改，上傳時一併儲存）
            SizedBox(
              width: 220,
              child: TextField(
                controller: _name,
                maxLength: 16,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  labelText: '排行榜暱稱',
                  labelStyle:
                      TextStyle(color: Colors.grey[500], fontSize: 12),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: _kGoldDeep)),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: _kGold)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogButton('上傳成績', _upload),
                const SizedBox(width: 10),
                _dialogButton('不上傳',
                    () => setState(() => _state = _UploadState.skipped),
                    filled: false),
              ],
            ),
          ],
        );
    }
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

        // 無盡模式失敗：顯示撐過幾波 + 最佳紀錄（破紀錄時金色強調）。
        final endless = game.endless.value;
        final String title;
        final String message;
        if (won) {
          title = '勝利！';
          message = '你成功守住了主堡！';
        } else if (endless) {
          title = '挑戰結束';
          message = '無盡模式：撐過 ${game.completedWaves} 波\n'
              '${game.newEndlessRecord ? '🏆 新紀錄！' : '最佳紀錄：${game.bestEndless.value} 波'}';
        } else {
          title = '遊戲結束';
          message = '主堡失守了……再挑戰一次！';
        }

        final celebrate = won || (endless && game.newEndlessRecord);
        return Stack(
          children: [
            // 失敗遮罩更深一階＋紅色暗角；勝利維持標準遮罩＋金色彩帶。
            ModalBarrier(
                color: celebrate ? Colors.black54 : Colors.black87,
                dismissible: false),
            if (!celebrate)
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [
                        Colors.transparent,
                        Color(0x40801515), // 邊緣滲入的暗紅
                      ],
                      stops: [0.55, 1.0],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
            if (celebrate) const Positioned.fill(child: _Confetti()),
            _themedDialog(
              icon: won
                  ? 'trophy_cup'
                  : endless
                      ? 'infinity'
                      : 'death_skull',
              accent: won || (endless && game.newEndlessRecord)
                  ? _kGold
                  : Colors.redAccent,
              title: title,
              message: message,
              // 無盡戰敗且排行榜可用 → 詢問是否上傳成績（可改暱稱、可不傳）。
              extra: !won && endless && game.completedWaves > 0
                  ? _EndlessUploadSection(waves: game.completedWaves)
                  : null,
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

/// 勝利/新紀錄彩帶：金色紙屑一次性向上噴發後飄落（reduce-motion 不播）。
/// 純 CustomPainter：無元件配置、一條 1.8 秒的 controller 驅動全部粒子。
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(painter: _ConfettiPainter(_c), size: Size.infinite),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _colors = [_kGold, _kGoldDeep, _kParchment, Color(0xFFFFF3C8)];

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v >= 1) return;
    final rnd = Random(7); // 固定種子 → 每次噴發形狀一致、免存粒子狀態
    final origin = Offset(size.width / 2, size.height * 0.62);
    final paint = Paint();
    for (var i = 0; i < 30; i++) {
      // 向上扇形初速 + 重力下墜；尾段淡出。
      final ang = -pi / 2 + (rnd.nextDouble() - 0.5) * pi * 0.9;
      final speed = size.shortestSide * (0.55 + rnd.nextDouble() * 0.55);
      final x = origin.dx + cos(ang) * speed * v;
      final y = origin.dy +
          sin(ang) * speed * v +
          size.shortestSide * 0.9 * v * v; // 重力
      final fade = (1 - (v - 0.65) / 0.35).clamp(0.0, 1.0);
      paint.color = _colors[i % _colors.length].withValues(alpha: fade);
      final s = 3.0 + rnd.nextDouble() * 4.5;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((rnd.nextDouble() * 2 - 1) * 8 * v); // 翻轉飄落感
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.55), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}
