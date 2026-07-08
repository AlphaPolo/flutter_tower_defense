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

        return Stack(
          children: [
            const ModalBarrier(color: Colors.black54, dismissible: false),
            _themedDialog(
              icon: won
                  ? Icons.emoji_events
                  : endless
                      ? Icons.all_inclusive
                      : Icons.sentiment_very_dissatisfied,
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
