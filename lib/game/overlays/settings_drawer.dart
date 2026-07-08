part of 'game_overlays.dart';

// ═══ 設定抽屜 ═══

/// 設定抽屜：特效開關（由左上「設定」鈕開啟）。
/// 作弊模式與重新開始鈕都在左上 HUD、不在此。
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer(
      {super.key, required this.game, required this.onBackToMenu});
  final TowerDefenseGame game;

  /// 返回主選單（重建遊戲並重新顯示模式選單）。
  final VoidCallback onBackToMenu;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      backgroundColor: const Color(0xFF241811), // 深木底
      child: SafeArea(
        child: Column(
          children: [
            // 標題
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.settings, color: _kGold, size: 24),
                  SizedBox(width: 10),
                  Text(
                    '設定',
                    style: TextStyle(color: _kGold, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(color: _kGoldDeep, height: 1),

            Expanded(
              child: CustomScrollView(
                slivers: [

                  SliverToBoxAdapter(child: _sectionHeader('特效')),
                  SliverToBoxAdapter(
                    child: _switchTile(game.dimFlame,
                            () => game.dimFlame.value = !game.dimFlame.value,
                        Icons.local_fire_department, '火焰特效變淡', Colors.orangeAccent),
                  ),
                  SliverToBoxAdapter(
                    child: _switchTile(
                        game.waterReflection,
                            () => game.waterReflection.value = !game.waterReflection.value,
                        Icons.water,
                        '水面倒影',
                        Colors.lightBlueAccent),
                  ),
                  SliverToBoxAdapter(child: _sectionHeader('音訊')),
                  SliverToBoxAdapter(
                    child: _switchTile(
                        GameAudio.sfxOn,
                            () => GameAudio.sfxOn.value = !GameAudio.sfxOn.value,
                        Icons.volume_up,
                        '音效',
                        _kGold),
                  ),
                  SliverToBoxAdapter(
                    child: _volumeTile(
                      GameAudio.sfxOn,
                      GameAudio.sfxVol,
                      // 放開滑條時播一聲金幣試聽，立刻感受音量。
                      onChangeEnd: () =>
                          GameAudio.ui('coin', volume: 0.45, throttleMs: 0),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _switchTile(
                        GameAudio.bgmOn,
                            () => GameAudio.bgmOn.value = !GameAudio.bgmOn.value,
                        Icons.music_note,
                        '音樂',
                        _kGold),
                  ),
                  SliverToBoxAdapter(child: _volumeTile(GameAudio.bgmOn, GameAudio.bgmVol)),
                  // 返回主選單（清進度，需確認）。
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: AlignmentGeometry.bottomCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmBackToMenu(context),
                              icon: const Icon(Icons.home, size: 18),
                              label: const Text('返回主選單',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kGold,
                                side: const BorderSide(color: _kGoldDeep, width: 1.3),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          // 音樂授權標註（xDeviruchi 授權條款要求）。
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Text(
                              'Music: Alexandr Zhelanov (CC-BY 3.0)\n'
                                  'Victory theme by Marllon Silva (xDeviruchi)\n'
                                  'SFX: artisticdude (CC-BY 3.0), Kenney (CC0)',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 返回主選單前先確認（會清掉目前進度）。
  void _confirmBackToMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _themedDialog(
        icon: Icons.home,
        accent: _kGold,
        title: '返回主選單？',
        message: '目前的進度（金幣、生命、已蓋的塔）會全部清除，回到模式選擇畫面。',
        actions: [
          _dialogButton('取消', () => Navigator.pop(ctx), filled: false),
          const SizedBox(width: 12),
          _dialogButton('返回主選單', () {
            Navigator.pop(ctx); // 關確認彈窗
            Navigator.pop(context); // 關抽屜
            onBackToMenu();
          }, filled: true, color: Colors.redAccent),
        ],
      ),
    );
  }

  /// 分區標題（特效 / 音訊…）：小字灰金、與上方拉開間距。
  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
      child: Text(
        label,
        style: TextStyle(
          color: _kGoldDeep.withValues(alpha: 0.9),
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  /// 單一開關列：圖示 + 標籤 + CupertinoSwitch；開啟時以 [onColor] 上色。
  Widget _switchTile(ValueListenable<bool> vn, VoidCallback onToggle,
      IconData icon, String label, Color onColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: vn,
      builder: (context, on, _) => ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        leading: Icon(icon, color: on ? onColor : Colors.grey[500]),
        title: Text(label,
            style: TextStyle(
                color: on ? onColor : Colors.grey[300],
                fontWeight: FontWeight.bold)),
        trailing: CupertinoSwitch(
            value: on,
            onChanged: (_) {
              GameAudio.ui('switch', volume: 0.6);
              onToggle();
            }),
        onTap: () {
          GameAudio.ui('switch', volume: 0.6);
          onToggle();
        },
      ),
    );
  }

  /// 音量滑條列（縮排在開關列之下）：對應開關關閉時變暗、不可拖。
  /// [onChangeEnd] 放開滑條時呼叫（試聽用）。
  Widget _volumeTile(ValueListenable<bool> onVn, ValueNotifier<double> vol,
      {VoidCallback? onChangeEnd}) {
    return ValueListenableBuilder<bool>(
      valueListenable: onVn,
      builder: (context, on, _) => ValueListenableBuilder<double>(
        valueListenable: vol,
        builder: (context, v, _) => Padding(
          padding: const EdgeInsets.only(left: 40, right: 16),
          // SizedBox + noOverlay：去掉 Slider 預設的 48px 保留高度與外圈光暈，
          // 讓滑條貼近上方的開關列。
          child: SizedBox(
            height: 26,
            child: SliderTheme(
              data: SliderThemeData(
                // 開啟：金色已填段 + 淡白底軌。
                activeTrackColor: _kGold,
                inactiveTrackColor: Colors.white24,
                thumbColor: _kGold,
                // 關閉（onChanged=null → disabled 狀態吃這組）：整體轉灰但
                // 「已填段(灰) vs 底軌(淡白)」仍有層次，深木底上看得到。
                disabledActiveTrackColor: Colors.grey[600],
                disabledInactiveTrackColor: Colors.white12,
                disabledThumbColor: Colors.grey[600],
                overlayShape: SliderComponentShape.noOverlay,
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: v,
                onChanged: on ? (nv) => vol.value = nv : null,
                onChangeEnd: on ? (_) => onChangeEnd?.call() : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
