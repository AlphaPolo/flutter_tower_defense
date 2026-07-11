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
                const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
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
          _uiIcon('coin', 20.h).animate(key: ValueKey(v)).scaleXY(
                begin: 1.35,
                end: 1.0,
                duration: 260.ms,
                curve: Curves.easeOutBack,
              ),
          // 數字從舊值平滑跑到新值（TweenAnimationBuilder 不加 key → 保留狀態）。
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: v.toDouble()),
            duration: const Duration(milliseconds: 450),
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
                    Icon(Icons.settings, color: _kGold, size: 18.h),
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
                    Icon(Icons.refresh, color: _kGold, size: 18.h),
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
                Icon(Icons.bolt, color: color, size: 18.h),
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
          icon = Icon(Icons.castle, color: Colors.green, size: 44.h);
          title = '主堡（終點）';
          lines = ['守住這裡！', '敵人抵達會扣 1 生命', '生命歸零即遊戲結束'];
        } else if (bp == game.spawnLocation) {
          icon = Icon(Icons.flag, color: Colors.redAccent, size: 44.h);
          title = '敵人出生點';
          lines = ['敵人從這裡出現', '沿著路線前往主堡'];
        } else if (game.environment.containsKey(bp)) {
          env = true;
          final e = game.environment[bp]!;
          icon = Icon(Icons.terrain, color: Color(0xFF6D4C41), size: 44.h);
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
          icon = SizedBox.square(dimension: 48.h, child: ClipOval(child: towerIcon(type)));
          title = stats.title;
          lines = type == TowerType.obstacle
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
                    ];
        }

        return Container(
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
                Center(child: icon),
                SizedBox(height: 8.h),
                Text(title, textAlign: TextAlign.center),
                SizedBox(height: 6.h),
                for (final l in lines)
                  Text(l, style: TextStyle(fontSize: 13.h)),
                if (game.isLogTower(bp)) ...[
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
                        icon: const Icon(Icons.rotate_left),
                        iconSize: 26.h,
                        color: Colors.brown,
                        tooltip: '逆時針',
                      ),
                      IconButton(
                        onPressed: () => game.rotateLog(bp, 1),
                        icon: const Icon(Icons.rotate_right),
                        iconSize: 26.h,
                        color: Colors.brown,
                        tooltip: '順時針',
                      ),
                    ],
                  ),
                ],
                // 狙擊塔 Lv3 主動技：指向狙擊（進入瞄準模式，點地圖朝該方向射擊）。
                if (game.towers[bp] case final SniperTowerComponent sniper
                    when sniper.skillUnlocked) ...[
                  SizedBox(height: 8.h),
                  _SniperSkillButton(game: game, bp: bp, tower: sniper),
                ],
                if (tower) _upgradeControl(bp),
                if (tower) _beaconControl(bp),
                if (game.typeAt(bp) == TowerType.beacon) _towerPickControl(bp),
                if (tower) ...[
                  SizedBox(height: 12.h),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => game.demolishAt(bp),
                    icon: Icon(Icons.delete_outline, size: 18.h),
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
                    icon: Icon(Icons.cleaning_services, size: 18.h),
                    label: Text('清除 (${TowerDefenseGame.envClearCost})'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    has ? Colors.brown : const Color(0xFFB6832B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4).h,
                minimumSize: Size(0, 30.h),
                textStyle: TextStyle(fontSize: 12.h, fontWeight: FontWeight.bold),
              ),
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
              icon: Icon(picking ? Icons.close : Icons.gps_fixed, size: 16.h),
              label: Text(
                has
                    ? '解除標靶'
                    : picking
                        ? '取消選取'
                        : '設定標靶',
              ),
            ),
          ],
        );
      },
    );
  }

  /// 標靶樁面板的「指定塔」控制：進入選塔模式（點塔切換綁定、可連續多選，
  /// 點空地或按[完成]退出）。
  Widget _towerPickControl(BoardPoint bp) {
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                active ? Colors.brown : const Color(0xFFB6832B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4).h,
                minimumSize: Size(0, 30.h),
                textStyle: TextStyle(fontSize: 12.h, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                GameAudio.ui('select', volume: 0.6);
                if (active) {
                  game.assigningTowersFor.value = null;
                } else {
                  game.startTowerPick(bp);
                }
              },
              icon: Icon(active ? Icons.check : Icons.gps_fixed, size: 16.h),
              label: Text(active ? '完成' : '指定塔'),
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
        border: Border.all(color: Colors.amber.shade700),
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
                  color: Colors.brown)),
          SizedBox(height: 2.h),
          Text(node.desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.h)),
          SizedBox(height: 4.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4).h,
              minimumSize: Size(0, 30.h),
              textStyle: TextStyle(fontSize: 12.h, fontWeight: FontWeight.bold),
            ),
            onPressed: affordable ? () => game.upgradeTower(bp, node) : null,
            child: Text('升級 (${node.cost})'),
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
                            color: active ? _kGold : const Color(0xFFD8C9A6),
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
                Icon(Icons.play_circle, color: canStart ? Colors.white : disableForegroundColor, size: 24.h),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 8).h,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6).h,
          decoration: _woodBox(radius: 14, strong: false),
          // 後期敵種多時可橫向捲動，窄螢幕不爆版。
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '下一波',
                  style: TextStyle(
                    color: _kGold,
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
              spacing: 6.h,
              children: [
                for (final k in kinds)
                  _enemyAvatarButton(k, sel == k),
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
        width: 40.h,
        height: 40.h,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.orangeAccent : Colors.white24,
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
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isAiming ? Colors.orange.shade800 : Colors.redAccent.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.blueGrey.shade200,
            disabledForegroundColor: Colors.white,
          ),
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
          icon: Icon(Icons.gps_fixed, size: 18.h),
          label: Text(label, style: TextStyle(fontSize: 13.h)),
        );
      },
    );
  }
}
