import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_defense/utils/bottom_semicircle_clipper.dart';
import 'package:tower_defense/widget/scroll/fade_edge_scroll_view.dart';

import '../../utils/fullscreen.dart';
import '../audio/game_audio.dart';
import '../board/hex.dart';
import '../components/enemy_kind.dart';
import '../components/tower/tower_factory.dart';
import '../leaderboard/leaderboard.dart';
import '../tower_defense_game.dart';
import '../tower_type.dart';

/// 遊戲 UI overlay 總庫。依區塊拆成 part 檔（同一 library，
/// 私有成員如 _kGold/_woodBox/_themedDialog 可跨檔共用）：
///
/// - overlay_theme.dart        主題：色票/木質外框/彈窗元件
/// - overlay_icons.dart        towerIcon/程式繪製圖示/敵人頭像畫家
/// - hud_overlay.dart          LeftColOverlay（狀態列/預告/開始鈕/面板）
/// - settings_drawer.dart      設定抽屜
/// - mode_select_overlay.dart  開場模式選單（闖關/無盡）
/// - end_overlay.dart          結束彈窗＋無盡成績上傳
/// - leaderboard_dialog.dart   無盡排行榜彈窗
/// - build_bar.dart            底部建造列＋分類頁籤
part 'overlay_theme.dart';
part 'overlay_icons.dart';
part 'hud_overlay.dart';
part 'settings_drawer.dart';
part 'mode_select_overlay.dart';
part 'end_overlay.dart';
part 'leaderboard_dialog.dart';
part 'build_bar.dart';
