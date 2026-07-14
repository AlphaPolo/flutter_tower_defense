import 'utils/platform_init.dart'
if(dart.library.io) 'utils/platform/default_platform_init.dart'
if(dart.library.html) 'utils/platform/web_platform_init.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tower_defense/game/audio/game_audio.dart';
import 'package:tower_defense/game/leaderboard/leaderboard.dart';
import 'package:tower_defense/screens/my_app.dart';
import 'package:tower_defense/utils/debug_overflow.dart';



void main() async {
  // debug 時只靜音「掛了 kAllowOverflow 標籤」的溢出紅字；未標籤的照常
  // 大聲回報（矩陣測試不經過 main()，一樣照抓）。用法見 debug_overflow.dart。
  installOverflowFilter();
  await createStrategyInit().init();
  GameAudio.loadPrefs(); // 音訊設定（開關/音量）持久化：載入不阻塞啟動
  Leaderboard.init(); // 排行榜（Firebase）：失敗安靜降級、不阻塞啟動
  // 手機鎖定橫向（原生 iOS/Android）。Web 由 OrientationGate 提示旋轉。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // 原生手機全螢幕（隱藏狀態列/導覽列）。Web 為 no-op，由 index.html 處理。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}