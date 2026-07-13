part of 'game_overlays.dart';

// ═══ 無盡排行榜彈窗 ═══

/// 排行榜彈窗：前 50 名 + 自己高亮 + 暱稱編輯。木質主題、載入/失敗狀態。
Future<void> showLeaderboardDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => const _LeaderboardDialog(),
  );
}

class _LeaderboardDialog extends StatefulWidget {
  const _LeaderboardDialog();

  @override
  State<_LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<_LeaderboardDialog> {
  late Future<List<LeaderboardEntry>> _top;
  String _myName = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // 先確保登入（自己那行才能高亮），再抓榜。
    _top = Leaderboard.ensureSignedIn().then((_) => Leaderboard.top());
    Leaderboard.playerName().then((n) {
      if (mounted) setState(() => _myName = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final envTag = Leaderboard.env == 'staging' ? '（staging）' : '';
    final seasonLabel =
        Leaderboard.kSeason < 1 ? '測試季' : '第 ${Leaderboard.kSeason} 季';
    // 路線2「固定畫布」：360×440 設計稿，小螢幕整張等比縮小 → 永不溢出。
    return Padding(
      padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(20),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxHeight: 440),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: _dialogBox(),
            child: AnimatedSize(
              curve: Curves.easeOut,
              duration: 150.ms,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: _kGold, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('無盡排行榜 · $seasonLabel$envTag',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _kGold,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: _kTextDim),
                      ),
                    ],
                  ),
                  const Divider(color: _kGoldDeep, height: 10),
                  Flexible(
                    child: FutureBuilder<List<LeaderboardEntry>>(
                      future: _top,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(color: _kGold),
                          );
                        }
                        final list = snap.data ?? const [];
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('還沒有紀錄——去無盡模式搶頭香！',
                                style: TextStyle(color: _kTextDim)),
                          );
                        }
                        final myUid = Leaderboard.currentUid;
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final e = list[i];
                            final mine = e.uid == myUid;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: mine
                                  ? BoxDecoration(
                                      color: _kGold.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _kGoldDeep),
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      '${i + 1}.',
                                      style: TextStyle(
                                        color: i < 3 ? _kGold : Colors.grey[400],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: mine ? _kGold : Colors.white,
                                        fontWeight: mine
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  Text('${e.wave} 波',
                                      style: const TextStyle(
                                          color: _kTextSoft,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(color: _kGoldDeep, height: 10),
                  // 我的暱稱 + 編輯
                  Row(
                    children: [
                      Text('暱稱：$_myName',
                          style: const TextStyle(color: _kTextDim, fontSize: 13)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _editName,
                        icon: const Icon(Icons.edit, color: _kGoldDeep, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _myName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _themedDialog(
        icon: Icons.edit,
        accent: _kGold,
        title: '修改暱稱',
        extra: TextField(
          controller: ctrl,
          maxLength: 16,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            counterStyle: TextStyle(color: _kTextFaint),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: _kGoldDeep)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: _kGold)),
          ),
        ),
        actions: [
          _dialogButton('取消', () => Navigator.pop(ctx, false), filled: false),
          const SizedBox(width: 12),
          _dialogButton('儲存', () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // 更新暱稱並同步榜上名字（同分重送，規則允許 >=）。
    final p = await SharedPreferences.getInstance();
    final best = p.getInt('bestEndlessWave') ?? 0;
    await Leaderboard.setPlayerName(ctrl.text, currentWave: best);
    setState(_reload);
  }
}
