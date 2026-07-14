part of 'game_overlays.dart';

// ═══ 底部建造列＋分類頁籤 ═══

/// 底部：防禦塔選單。點擊選取要蓋的塔。
class BuildBar extends StatefulWidget {
  const BuildBar({super.key, required this.game});
  final TowerDefenseGame game;

  @override
  State<BuildBar> createState() => _BuildBarState();
}

class _BuildBarState extends State<BuildBar> {
  TowerDefenseGame get game => widget.game;
  int _tab = 0;

  /// 建造分類頁籤（涵蓋全部塔種）。
  static const List<(String, List<TowerType>)> _cats = [
    ('元素', [
      TowerType.flame,
      TowerType.freezing,
      TowerType.thunder,
      TowerType.poison,
    ]),
    ('物理', [
      TowerType.log,
      TowerType.cannon,
      TowerType.airBlade,
      TowerType.sniper,
    ]),
    ('陷阱', [TowerType.spike, TowerType.vortex, TowerType.beacon]),
    ('支援', [TowerType.multishot, TowerType.obstacle]),
  ];

  static const double _tabH = 34; // 分頁列高度

  int? _hoverTab; // 滑鼠懸停中的分頁（桌面 hover 視覺用）

  @override
  Widget build(BuildContext context) {
    // Chrome 分頁感：頁籤嵌在底部 bar 上方；用 Stack 讓分頁畫在 bar 之上，選中頁籤
    // 往下凸並蓋住 bar 頂邊 → 與內容連成一體。
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _tabH).h,
          child: _barBody(),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SizedBox(height: _tabH.h, child: _tabStrip()),
        ),
      ],
    );
  }

  /// 分頁列（水平；超出可左右捲）。
  Widget _tabStrip() {
    return Padding(
      padding: const EdgeInsets.only(left: 10).h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none, // 讓選中頁籤往下凸出不被裁掉
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end, // 底部對齊到 bar 頂
          spacing: 3.h,
          children: [for (var i = 0; i < _cats.length; i++) _chromeTab(i)],
        ),
      ),
    );
  }

  /// 單一分頁（頂部圓角）：選中＝漸層（底色收在 bar 頂色→無斷層）+ 金框，往下凸
  /// 3px 與 bar 連成一體；未選＝暗底、較矮（凹陷感）。
  Widget _chromeTab(int i) {
    final sel = i == _tab;
    final hover = _hoverTab == i && !sel;
    final borderSide = BorderSide(
      color: sel ? _kGoldDeep : _kGoldDeep.withValues(alpha: hover ? 0.7 : 0.4),
      width: (sel ? 2 : 1).h,
    );
    final tab = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: sel ? 7 : 5).h,
      decoration: BoxDecoration(
        gradient: sel ? _kSelTabGradient : null,
        color: sel ? null : _kWoodDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)).h,
        border: Border(
          top: borderSide,
          left: borderSide,
          right: borderSide,
        ),
      ),
      child: Text(
        _cats[i].$1,
        style: TextStyle(
          color: sel ? _kGold : (hover ? _kTextDim : _kTextFaint),
          fontWeight: FontWeight.bold,
          fontSize: 13.h,
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // 桌面滑鼠懸停：輕微音 + 提亮（觸控裝置無 hover、不觸發）。
      onEnter: (_) {
        GameAudio.ui('hover', volume: 0.3, throttleMs: 90);
        setState(() => _hoverTab = i);
      },
      onExit: (_) => setState(() => _hoverTab = null),
      child: GestureDetector(
        onTap: () {
          GameAudio.ui('click', volume: 0.5);
          setState(() => _tab = i);
        },
        child: sel
            // 選中分頁下沉與 bar 金色頂線等距相接；tab 底緣的抗鋸齒縫用
            // 一條同色補丁蓋掉——Positioned 出血、不佔版面（Column 疊加會把
            // 頁籤列撐高造成溢出），寬度讓開兩側金邊、側線不會突下去。
            ? Transform.translate(
                offset: Offset(0, 2.h),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    tab,
                    Positioned(
                      left: 2.h,
                      right: 2.h,
                      bottom: -1,
                      height: 2.5,
                      child: const ColoredBox(color: _kWoodMid),
                    ),
                  ],
                ),
              )
            : tab,
      ),
    );
  }

  /// 底部 bar 本體：木紋底 + 頂部金邊 + 該分類的塔列。
  Widget _barBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: _kWoodGradient,
        border: Border(top: BorderSide(color: _kGoldDeep, width: 2.h)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8).h,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 75.h,
          // 切頁過場：卡片列淡入＋約 6px 右滑進場（reduce-motion 直接切）。
          child: AnimatedSwitcher(
            duration: _reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.015, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_tab), child: _towerRow()),
          ),
        ),
      ),
    );
  }

  /// 目前分類的塔按鈕列（右側保留全螢幕鈕）。
  Widget _towerRow() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // 預留右側空間給全螢幕鈕，避免最右邊的塔被蓋住點不到。
          padding: EdgeInsets.only(right: kIsWeb ? 48 : 0).h,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12.h,
            children: [
              for (final type in _cats[_tab].$2) _icon(type),
            ],
          ),
        ),
        if (kIsWeb)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _fullscreenButton(),
          ),
      ],
    );
  }

  Widget _fullscreenButton() {
    return IconButton(
      tooltip: '全螢幕',
      onPressed: toggleFullscreen,
      icon: _gi('expand', size: 26, color: Colors.white),
    );
  }

  Widget _icon(TowerType type) {
    final button = Container(
      width: 50.h,
      height: 50.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 2,
            blurRadius: 3,
          ),
        ],
      ),
      // Material(圓形 + 裁切) + InkWell(圓形邊界) → 圓形水波，不再是方形。
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          hoverColor: _kGold.withValues(alpha: 0.22), // 桌面 hover 金色微亮
          // 桌面滑鼠懸停的輕微音（觸控裝置無 hover、不觸發）。
          onHover: (h) {
            if (h) GameAudio.ui('hover', volume: 0.3, throttleMs: 90);
          },
          onTap: () {
            GameAudio.ui('select', volume: 0.6);
            game.selectTower(type);
          },
          child: Container(
            padding: const EdgeInsets.all(2).h,
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: _kGoldDeep, width: 4, strokeAlign: BorderSide.strokeAlignCenter)),
              shape: BoxShape.circle,
            ),
            child: ClipOval(child: towerIcon(type)),
          ),
        ),
      ),
    );

    // 障礙物在圓鈕右上角疊剩餘數量徽章。
    final Widget circle = type == TowerType.obstacle
        ? ValueListenableBuilder<int>(
            valueListenable: game.freeObstacle,
            builder: (context, count, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  child!,
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(6).h,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.h,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            child: button,
          )
        : button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 3),
        _costLabel(type),
      ],
    );
  }

  /// 塔按鈕下方的費用標籤（障礙物顯示「免費」）。
  Widget _costLabel(TowerType type) {
    if (type == TowerType.obstacle) {
      return Text('免費',
        style: TextStyle(
        color: _kGold, fontSize: 11.h, fontWeight: FontWeight.bold),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _uiIcon('coin', 14.h),
        SizedBox(width: 2.h),
        Text(
          '${statsOf(type).cost}',
          style: TextStyle(color: _kGold, fontSize: 11.h, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
