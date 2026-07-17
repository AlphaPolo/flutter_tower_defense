part of 'game_overlays.dart';

// ═══ HUD：LeftColOverlay（狀態列/波次預告/開始鈕/資訊面板/圖鑑…） ═══

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
            padding: const EdgeInsets.all(8).h,
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
                      SizedBox(height: 8.h),
                      _hudButtons(),
                      SizedBox(height: 8.h),
                      _cheatButton(), // 作弊模式（在設定/重新開始列下方）
                    ],
                  ),
                ),
                // 頂部置中：Boss 血條（場上有巨獸才顯示）。
                Align(alignment: Alignment.topCenter, child: _bossBar()),

                // 左下：敵人資訊卡 +（開始鈕 + 敵人圖鑑）
                Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    // maxHeight：矮螢幕（300 高）上長說明的圖鑑卡不撐爆左欄，
                    // 卡片內文改為可捲（見 _enemyInfoCard 的 Flexible）。
                    constraints: BoxConstraints(
                        maxWidth: c.maxWidth, maxHeight: c.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(child: _enemyInfoCard()),
                        SizedBox(height: 8.h),
                        _wavePreview(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 6.h,
                          children: [
                            _startButton(),
                            _speedButton(),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7).h,
          decoration: _woodBox(radius: 22.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 14.h,
            children: [
              _stat(
                // 波次：game-icons.net「crossed-sabres」(lorc, CC BY 3.0)，
                // 白色 alpha 形狀以 srcIn 染成藍色。
                Image.asset(
                  'assets/ui/crossed_sabres.png',
                  width: 18.h,
                  height: 18.h,
                  color: Colors.lightBlueAccent,
                  colorBlendMode: BlendMode.srcIn,
                ),
                game.wave,
                (w) => w == 0
                    ? '—'
                    : game.endless.value
                        ? '$w/∞'
                        : '$w/${TowerDefenseGame.totalWaves}',
              ),

              _stat(
                _gi('hearts', size: 18.h, color: Colors.redAccent),
                game.heart,
                (v) => '$v',
              ),

              _coinStat(),
            ],
          ),
        ),
        // 密林收入：金幣旁「+xx 從密林」淡入 → 上飄 → 淡出（取代頂部 banner）。
        Positioned(
          right: 2.h,
          top: 34.h,
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
          style: TextStyle(
            color: _kGold,
            fontSize: 12.5.h,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        )
            .animate(key: ValueKey(e.$1))
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .moveY(begin: 8.h, end: -16.h, duration: 4000.ms, curve: Curves.easeOut)
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
        spacing: 4.h,
        children: [
          // 每次金幣變動，圖示彈一下（key 改變 → 重新播放）。
          if (_reduceMotion(context))
            _uiIcon('coin', 20.h)
          else
            _uiIcon('coin', 20.h).animate(key: ValueKey(v)).scaleXY(
                  begin: 1.35,
                  end: 1.0,
                  duration: 260.ms,
                  curve: Curves.easeOutBack,
                ),
          // 數字從舊值平滑跑到新值（TweenAnimationBuilder 不加 key → 保留狀態）。
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: v.toDouble()),
            duration: _reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (context, val, child) => Text(
              '${val.round()}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.h,
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
        spacing: 4.h,
        children: [
          icon,
          Text(
            fmt(v),
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.h,
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
          spacing: 6.h,
          children: [
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6).h,
                decoration: _woodBox(radius: 18, strong: false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6.h,
                  children: [
                    _gi('cog', size: 18.h),
                    Text('設定', style: TextStyle(fontSize: 13.h, fontWeight: FontWeight.bold, color: _kGold)),
                  ],
                ),
              ),
            ),

            GestureDetector(
              onTap: () => _confirmReset(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6).h,
                decoration: _woodBox(radius: 18, strong: false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6.h,
                  children: [
                    _gi('clockwise_rotation', size: 18.h),
                    Text('重新開始', style: TextStyle(fontSize: 13.h, fontWeight: FontWeight.bold, color: _kGold)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6).h,
            decoration: _woodBox(radius: 18, strong: false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6.h,
              children: [
                _gi('power_lightning', size: 18.h, color: color),
                Text(
                  '作弊模式${on ? '：開' : ''}',
                  style: TextStyle(fontSize: 13.h, fontWeight: FontWeight.bold, color: color),
                ),
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
        icon: 'clockwise_rotation',
        accent: _kGold,
        title: '重新開始？',
        message: '目前的進度（金幣、生命、已蓋的塔）會全部清除，確定要重置嗎？',
        actions: [
          _dialogButton('取消', () => Navigator.pop(ctx), filled: false),
          const SizedBox(width: 12),
          _dialogButton('確定重置', () {
            Navigator.pop(ctx);
            onRestart();
          }, filled: true, tone: _WoodTone.danger),
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
        final panel = Container(
          margin: const EdgeInsets.all(8).h,
          padding: const EdgeInsets.all(12).h,
          constraints: const BoxConstraints(maxWidth: 180).h,
          decoration: _panelBox(),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SizedBox.square(
                    dimension: 48.h,
                    child: ClipPath(
                      clipper: const BottomSemicircleClipper(),
                      child: towerIcon(type),
                    ),
                  ),
                ),
                SizedBox(height: 16.0.h),
                Text(stats.title, textAlign: TextAlign.center),
                SizedBox(height: 16.0.h),
                Text(stats.description),
                SizedBox(height: 16.0.h),
                Text('花費: ${stats.cost}'),
                // 狙擊塔射程全圖，顯示數字沒有意義。
                Text('範圍: ${type == TowerType.sniper ? '全圖' : stats.range}'),
                if (stats.damage > 0) Text('傷害: ${stats.damage}'),
              ],
            ),
          ),
        );
        if (_reduceMotion(context)) return panel;
        // 進場：與資訊面板同款（換選塔種類重播一次）。
        return panel.animate(key: ValueKey(type)).fadeIn(
              duration: 120.ms,
              curve: Curves.easeOut,
            ).scale(
              begin: const Offset(0.92, 0.92),
              duration: 160.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  /// 依格子內容產出面板頂部資訊；空地回傳 null（不顯示面板）。
  _InspectInfo? _inspectInfoFor(BoardPoint bp) {
    if (bp == game.targetLocation) {
      return (
        kind: _CellKind.castle,
        icon: _gi('castle', size: 44.h, color: Colors.green),
        title: '主堡（終點）',
        lines: const ['守住這裡！', '敵人抵達會扣 1 生命', '生命歸零即遊戲結束'],
      );
    }
    if (bp == game.spawnLocation) {
      return (
        kind: _CellKind.spawn,
        icon: _gi('flying_flag', size: 44.h, color: Colors.redAccent),
        title: '敵人出生點',
        lines: const ['敵人從這裡出現', '沿著路線前往主堡'],
      );
    }
    final e = game.environment[bp];
    if (e != null) {
      return (
        kind: _CellKind.environment,
        icon: _gi('peaks', size: 44.h, color: const Color(0xFF6D4C41)),
        title: e.label,
        lines: [e.desc, e.blocks ? '（阻擋路線）' : '（可經過）'],
      );
    }
    final type = game.typeAt(bp);
    if (type == null) return null;
    // 已蓋的塔用「有效數值」getter（含升級加成，與實際判定/射程圈一致）；
    // 陷阱不在 towers 裡 → 退回基礎值。
    final stats = statsOf(type);
    final t = game.towers[bp];
    final range = t?.range ?? stats.range;
    final damage = t?.damage ?? stats.damage;
    return (
      kind: _CellKind.tower,
      icon: SizedBox.square(
          dimension: 48.h, child: ClipOval(child: towerIcon(type))),
      title: stats.title,
      lines: type == TowerType.obstacle
          ? const ['阻擋敵人前進']
          : type == TowerType.beacon
              ? [
                  '瞄準標記：火炮/噴火/狙擊',
                  '未貫穿的狙擊箭會被擋下',
                  '目前有 ${game.towersTargeting(bp)} 座塔指向這裡',
                ]
              : [
                  '範圍: ${type == TowerType.sniper ? '全圖' : range}',
                  if (damage > 0) '傷害: $damage',
                ],
    );
  }

  /// 點到格子時顯示資訊：塔(可拆除) / 主堡 / 敵人出生點 / 天然環境。
  /// 頂部資訊由 [_inspectInfoFor] 產出；底部操作各自判斷適不適用（不適用回
  /// shrink），此處只管排版順序。
  Widget _inspectPanel() {
    return AnimatedBuilder(
      animation:
          Listenable.merge([game.inspecting, game.towerChanged, game.coin]),
      builder: (context, _) {
        final bp = game.inspecting.value;
        if (bp == null) return const SizedBox.shrink();
        final info = _inspectInfoFor(bp);
        if (info == null) return const SizedBox.shrink();

        final panel = Container(
          margin: const EdgeInsets.all(8).h,
          padding: const EdgeInsets.all(12).h,
          constraints: const BoxConstraints(maxWidth: 180).h,
          decoration: _panelBox(),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: info.icon),
                SizedBox(height: 8.h),
                Text(info.title, textAlign: TextAlign.center),
                SizedBox(height: 6.h),
                for (final l in info.lines)
                  Text(l, style: TextStyle(fontSize: 13.h)),
                if (info.kind == _CellKind.tower) ...[
                  _logRotateControl(bp),
                  _sniperSkillControl(bp),
                  _upgradeControl(bp),
                  _beaconControl(bp),
                  _towerPickControl(bp),
                  SizedBox(height: 12.h),
                  _WoodButton(
                    tone: _WoodTone.danger,
                    icon: 'trash_can',
                    label: '拆除',
                    onPressed: () => game.demolishAt(bp),
                  ),
                ],
                if (info.kind == _CellKind.environment) ...[
                  SizedBox(height: 12.h),
                  _WoodButton(
                    tone: _WoodTone.warn,
                    icon: 'broom',
                    label: '清除 (${TowerDefenseGame.envClearCost})',
                    onPressed: () => game.clearEnvironmentAt(bp),
                  ),
                ],
              ],
            ),
          ),
        );
        if (_reduceMotion(context)) return panel;
        // 進場：輕縮放＋淡入（120/160ms）；點到另一格（key 變）重播一次。
        return panel.animate(key: ValueKey(bp)).fadeIn(
              duration: 120.ms,
              curve: Curves.easeOut,
            ).scale(
              begin: const Offset(0.92, 0.92),
              duration: 160.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  /// Boss 血條：Boss 在場時頂部置中顯示彙總血量（含分裂/多 Boss 波）。
  Widget _bossBar() {
    return ValueListenableBuilder<(double, double)?>(
      valueListenable: game.bossHp,
      builder: (context, hp, _) {
        if (hp == null) return const SizedBox.shrink();
        final frac = (hp.$1 / hp.$2).clamp(0.0, 1.0);
        final bar = Container(
          width: 280.h,
          padding: EdgeInsets.symmetric(horizontal: 10.h, vertical: 6.h),
          decoration: _woodBox(radius: 12.h, strong: false),
          child: Row(
            spacing: 6.h,
            children: [
              _gi('death_skull', size: 16.h, color: const Color(0xFFFF6B5E)),
              Text('巨獸',
                  style: TextStyle(
                      color: _kTextSoft,
                      fontSize: 12.h,
                      fontWeight: FontWeight.bold)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.h),
                  child: SizedBox(
                    height: 10.h,
                    child: Stack(children: [
                      const SizedBox.expand(
                          child: ColoredBox(color: Colors.black45)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: frac,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Color(0xFFD64541),
                              Color(0xFF8E2B26),
                            ]),
                          ),
                          child: SizedBox.expand(),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        );
        if (_reduceMotion(context)) return bar;
        // 進場：從畫面頂滑入（rebuild 不重播，只在出現那次）。
        return bar.animate().fadeIn(duration: 200.ms).slideY(
              begin: -0.6,
              end: 0,
              duration: 260.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  /// 滾木塔的方向控制（非滾木塔隱藏）。
  Widget _logRotateControl(BoardPoint bp) {
    if (!game.isLogTower(bp)) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 8.h),
        Text(
          '滾木方向',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.h, color: Colors.black54),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => game.rotateLog(bp, -1),
              icon: _gi('anticlockwise_rotation',
                  size: 26.h, color: Colors.brown),
              tooltip: '逆時針',
            ),
            IconButton(
              onPressed: () => game.rotateLog(bp, 1),
              icon: _gi('clockwise_rotation',
                  size: 26.h, color: Colors.brown),
              tooltip: '順時針',
            ),
          ],
        ),
      ],
    );
  }

  /// 狙擊塔 Lv3 主動技：指向狙擊（進入瞄準模式，點地圖朝該方向射擊）。
  Widget _sniperSkillControl(BoardPoint bp) {
    if (game.towers[bp] case final SniperTowerComponent sniper
        when sniper.skillUnlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8.h),
          _SniperSkillButton(game: game, bp: bp, tower: sniper),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  /// 標靶控制（僅火炮/噴火/狙擊）：未設定 → 「設定標靶」進入點選模式；
  /// 已設定 → 可「解除」。監聽 assigningBeaconFor 顯示選取中狀態。
  Widget _beaconControl(BoardPoint bp) {
    final t = game.towers[bp];
    if (t == null || !t.supportsBeacon) return const SizedBox.shrink();
    return ValueListenableBuilder<BoardPoint?>(
      valueListenable: game.assigningBeaconFor,
      builder: (context, assigning, _) {
        final picking = assigning == bp;
        final has = t.beaconTarget != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),
            if (picking)
              Text(
                '點選場上的標靶樁…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.h, color: Colors.brown),
              ),
            _WoodButton(
              dense: true,
              tone: (has || picking) ? _WoodTone.wood : _WoodTone.gold,
              icon: picking ? 'cancel' : 'targeting',
              label: has
                  ? '解除標靶'
                  : picking
                      ? '取消選取'
                      : '設定標靶',
              onPressed: () {
                GameAudio.ui('select', volume: 0.6);
                if (has) {
                  game.clearBeaconTarget(bp);
                } else if (picking) {
                  game.assigningBeaconFor.value = null; // 再按一次取消
                } else {
                  game.startBeaconPick(bp); // 互斥入口（清其他點擊模式）
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// 標靶樁面板的「指定塔」控制：進入選塔模式（點塔切換綁定、可連續多選，
  /// 點空地或按[完成]退出）。
  Widget _towerPickControl(BoardPoint bp) {
    if (game.typeAt(bp) != TowerType.beacon) return const SizedBox.shrink();
    return ValueListenableBuilder<BoardPoint?>(
      valueListenable: game.assigningTowersFor,
      builder: (context, picking, _) {
        final active = picking == bp;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),
            if (active)
              Text(
                '點選塔切換綁定，點空地完成',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.h, color: Colors.brown),
              ),
            _WoodButton(
              dense: true,
              tone: active ? _WoodTone.wood : _WoodTone.gold,
              icon: active ? 'check_mark' : 'targeting',
              label: active ? '完成' : '指定塔',
              onPressed: () {
                GameAudio.ui('select', volume: 0.6);
                if (active) {
                  game.assigningTowersFor.value = null;
                } else {
                  game.startTowerPick(bp);
                }
              },
            ),
          ],
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
        SizedBox(height: 8.h),
        Text(
          '等級 $lv / ${maxLevelOf(type)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.h, fontWeight: FontWeight.bold),
        ),
        if (chosenPath != null) ...[
          SizedBox(height: 2.h),
          Text(
            '已選：$chosenPath',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.h, color: Colors.brown),
          ),
        ],
        if (options.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Text(
            // 單一選項的塔（冰凍/火焰/風刃）不說「N 擇一」；狙擊 Lv2 有三條。
            options.length > 1
                ? (lv == 1
                    ? '選擇升級方向（${options.length == 2 ? '二' : '三'}擇一，選了就鎖）'
                    : '選擇強化（${options.length == 2 ? '二' : '三'}擇一）')
                : (lv == 1 ? '升級方向' : '強化'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.h, color: Colors.grey),
          ),
          SizedBox(height: 4.h),
          // 面板窄（maxWidth 150），兩張選項卡改上下堆疊（各佔滿寬），避免爆版。
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(height: 6.h),
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
      padding: const EdgeInsets.all(6).h,
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8).h,
        border: Border.all(color: _kGoldDeep.withValues(alpha: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(node.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.h,
                  fontWeight: FontWeight.bold,
                  color: _kGoldDeep)),
          SizedBox(height: 2.h),
          Text(node.desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.h)),
          SizedBox(height: 4.h),
          _WoodButton(
            dense: true,
            label: '升級 (${node.cost})',
            onPressed: affordable ? () => game.upgradeTower(bp, node) : null,
          ),
        ],
      ),
    );
  }

  /// 遊戲速度切換鈕：點擊循環 1×→2×→3×→1×。非 1× 時金色高亮提醒。
  Widget _speedButton() {
    return ValueListenableBuilder<int>(
      valueListenable: game.gameSpeed,
      builder: (context, sp, _) {
        final active = sp > 1;
        return GestureDetector(
          onTap: () {
            GameAudio.ui('click', volume: 0.5);
            game.gameSpeed.value = sp >= 3 ? 1 : sp + 1;
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(left: 6, right: 6).h,
            decoration: ShapeDecoration(
              gradient: _kWoodGradient,
              shape: StadiumBorder(
                side: BorderSide(
                  color: active ? _kGold : _kGoldDeep.withValues(alpha: 0.85),
                  width: (active ? 2 : 1.3).h,
                ),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // 速度圖示：1/2/3 個重疊的 ▶（Material 沒有內建三箭頭，
            // 用 play_arrow 疊排組出經典的倍速標示）。
            child: Row(
              spacing: 8.h,
              children: [
                SizedBox(
                  width: 30.h,
                  height: 30.h,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < sp; i++)
                        Transform.translate(
                          offset: Offset(((i - (sp - 1) / 2) * 8.0).h, 0),
                          child: Icon(
                            Icons.play_arrow,
                            size: 19.h,
                            color: active ? _kGold : _kTextDim,
                          ),
                        ),
                    ],
                  ),
                ),

                Text('x $sp', style: TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 16.h)),

              ],
            ),
          ),
        );
      },
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
        // 無盡模式沒有「全部完成」。
        final allDone = !game.endless.value &&
            game.waveNumber >= TowerDefenseGame.totalWaves;
        final canStart = !ended && !running && !allDone;

        final String label;
        if (running) {
          label = '第 ${game.waveNumber} 波進行中…';
        } else if (allDone) {
          label = '全部完成';
        } else if (game.waveNumber == 0) {
          label = '開始遊戲';
        } else if (game.endless.value) {
          label = '下一波 (${game.waveNumber + 1})';
        } else {
          label = '下一波 (${game.waveNumber + 1}/${TowerDefenseGame.totalWaves})';
        }

        final disableForegroundColor = Colors.white70;

        final button = InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(80)),
          onTap: canStart ? game.startGame : null,
          child: Container(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: canStart ? Colors.green : Colors.grey.shade600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5).h,
            child: Row(
              spacing: 4.h,
              children: [
                _gi('play_button', size: 24.h, color: canStart ? Colors.white : disableForegroundColor),
                Text(label, style: TextStyle(fontSize: 16.h, fontWeight: FontWeight.bold, color: canStart ? Colors.white : disableForegroundColor)),
              ],
            ),
          ),
        );

        return button;
      },
    );
  }

  /// 下一波預告：頭像 ×數量 的橫列（與實際生成共用同一份快取組成，所見即所得）。
  /// 波次進行中 / 遊戲結束 / 已打完全部波次時隱藏。
  Widget _wavePreview() {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [game.wave, game.waveRunning, game.gameOver, game.gameWon]),
      builder: (context, _) {
        if (game.waveRunning.value ||
            game.gameOver.value ||
            game.gameWon.value) {
          return const SizedBox.shrink();
        }
        final next = game.waveNumber + 1;
        if (!game.endless.value && next > TowerDefenseGame.totalWaves) {
          return const SizedBox.shrink();
        }
        // 依「首次出現順序」聚合數量。
        final counts = <EnemyKind, int>{};
        for (final k in game.waveLineup(next)) {
          counts[k] = (counts[k] ?? 0) + 1;
        }
        final boss = game.isBossWave(next);
        Widget card = Container(
          margin: const EdgeInsets.only(bottom: 8).h,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6).h,
          decoration: _woodBox(
              radius: 14,
              strong: false,
              borderColor: boss ? const Color(0xFFD64541) : null),
          // 後期敵種多時可橫向捲動，窄螢幕不爆版。
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  boss ? '巨獸來襲' : '下一波',
                  style: TextStyle(
                    color: boss ? const Color(0xFFFF6B5E) : _kGold,
                    fontSize: 12.h,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8.h),
                Row(
                  spacing: 8.h,
                  children: [
                    for (final e in counts.entries)
                      _previewChip(e.key, e.value)
                  ],
                ),
              ],
            ),
          ),
        );
        if (boss && !_reduceMotion(context)) {
          // Boss 波：卡片外圈紅光呼吸脈動（0.9 秒往返）。
          card = card.animate(onPlay: (c) => c.repeat(reverse: true)).custom(
                duration: 900.ms,
                curve: Curves.easeInOut,
                builder: (context, v, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.h),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD64541)
                            .withValues(alpha: 0.2 + 0.3 * v),
                        blurRadius: 8 + 8 * v,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
        }
        return card;
      },
    );
  }

  /// 預告用小徽章：敵人頭像 + ×數量；Boss 用紅框強調。
  Widget _previewChip(EnemyKind kind, int count) {
    final boss = kind == EnemyKind.juggernaut;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3.h,
      children: [
        Container(
          width: 26.h,
          height: 26.h,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: boss ? Colors.redAccent : Colors.white24,
              width: (boss ? 2 : 1.2).h,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _EnemyAvatarPainter(game.enemySheets[kind.id], kind),
          ),
        ),
        Text(
          '×$count',
          style: TextStyle(
            color: boss ? Colors.redAccent : Colors.white,
            fontSize: 12.h,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 敵人圖鑑：已解鎖敵人的頭像列，最多露出 3.5 顆頭像（暗示可捲動）。
  /// FadeEdgeScrollView（自家 widget）：僅在該側還有內容時亮起邊緣暗影。
  Widget _enemyBestiary() {
    return ValueListenableBuilder<int>(
      valueListenable: game.wave,
      builder: (context, _, __) {
        final kinds = game.unlockedKinds();
        return ValueListenableBuilder<EnemyKind?>(
          valueListenable: game.inspectingEnemy,
          // 木質膠囊容器（與狀態列同家族）：截斷發生在「框內」才有語義；
          // fade 蓋色＝容器底色 → 邊緣頭像像沉入框內陰影，不再是硬切。
          builder: (context, sel, ___) => ConstrainedBox(
            // 3 顆全臉 + 3 個間距 + 半顆 = 最多 3.5 顆，之後靠捲動。
            constraints: BoxConstraints(maxWidth: (3 * 46 + 20).h),
            child: ClipPath(
              clipper: const ShapeBorderClipper(shape: StadiumBorder()),
              child: FadeEdgeScrollView(
                axis: Axis.horizontal,
                size: 18.h,
                color: _kWoodDark,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6.h,
                  children: [
                    for (final k in kinds)
                      _enemyAvatarButton(k, sel == k),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _enemyAvatarButton(EnemyKind kind, bool selected) {
    return GestureDetector(
      onTap: () => game.inspectingEnemy.value = selected ? null : kind,
      child: Container(
        width: 40.h,
        height: 40.h,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? _kGold : _kGoldDeep.withValues(alpha: 0.45),
            width: (selected ? 2.5 : 1.5).h,
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
        final card = Container(
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
              // 空間不足時說明可捲動（矮螢幕＋長說明），數值行維持可見。
              Flexible(
                child: SingleChildScrollView(
                  child: Text(kind.desc, style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 6),
              Text('血量：${_hpLabel(kind)}　速度：${_spdLabel(kind)}',
                  style: const TextStyle(fontSize: 12)),
              Text('賞金：${kind.reward}　漏過扣血：${kind.leakDamage}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
        if (_reduceMotion(context)) return card;
        // 與資訊面板同款進場（換敵人重播）。
        return card.animate(key: ValueKey(kind)).fadeIn(
              duration: 120.ms,
              curve: Curves.easeOut,
            ).scale(
              begin: const Offset(0.92, 0.92),
              duration: 160.ms,
              curve: Curves.easeOutCubic,
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

/// 狙擊塔主動技鈕：就緒時按下進入瞄準模式（點地圖朝該方向射擊）、瞄準中再按
/// 一次取消；CD 中禁用並顯示剩餘秒數（每 0.2 秒刷新，只重繪這顆小按鈕）。
class _SniperSkillButton extends StatefulWidget {
  const _SniperSkillButton(
      {required this.game, required this.bp, required this.tower});
  final TowerDefenseGame game;
  final BoardPoint bp;
  final SniperTowerComponent tower;

  @override
  State<_SniperSkillButton> createState() => _SniperSkillButtonState();
}

class _SniperSkillButtonState extends State<_SniperSkillButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tower;
    final game = widget.game;
    return ValueListenableBuilder<BoardPoint?>(
      valueListenable: game.aimingSkill,
      builder: (context, aiming, _) {
        final isAiming = aiming == widget.bp;
        final ready = t.skillReady;
        final label = isAiming
            ? '瞄準中…按此取消'
            : ready
                ? '指向狙擊'
                : '冷卻 ${(t.skillCdLeft / 1000).ceil()} 秒';
        return _WoodButton(
          tone: isAiming ? _WoodTone.warn : _WoodTone.danger,
          icon: 'targeting',
          label: label,
          onPressed: !ready && !isAiming
              ? null
              : () {
                  GameAudio.ui('click', volume: 0.5);
                  if (isAiming) {
                    game.aimingSkill.value = null;
                  } else {
                    game.startSkillAim(widget.bp);
                  }
                },
        );
      },
    );
  }
}

// ═══ 資訊面板的資料模型 ═══

/// 被點選格子的種類：決定面板底部顯示哪些操作鈕。
enum _CellKind { castle, spawn, environment, tower }

/// 面板頂部的「圖示＋標題＋說明行」內容（[_CellKind.tower] 含陷阱/障礙）。
typedef _InspectInfo = ({
  _CellKind kind,
  Widget icon,
  String title,
  List<String> lines,
});

