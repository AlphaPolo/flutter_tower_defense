import 'utils/platform_init.dart'
if(dart.library.io) 'utils/platform/default_platform_init.dart'
if(dart.library.html) 'utils/platform/web_platform_init.dart';

import 'package:flutter/material.dart';
import 'package:tower_defense/screens/my_app.dart';



void main() async {
  await createStrategyInit().init();
  // await initSpineFlutter(enableMemoryDebugging: false);
  runApp(const MyApp());
}