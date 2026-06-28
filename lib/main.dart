import 'utils/platform_init.dart'
if(dart.library.io) 'utils/platform/default_platform_init.dart'
if(dart.library.html) 'utils/platform/web_platform_init.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tower_defense/screens/my_app.dart';



void main() async {
  await createStrategyInit().init();
  // 手機鎖定橫向（原生 iOS/Android）。Web 由 OrientationGate 提示旋轉。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}