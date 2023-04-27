import 'package:flutter/material.dart';
import 'package:tower_defense/utils/platform_init.dart';

PlatformInit createStrategyInit() => DefaultPlatformInit();

class DefaultPlatformInit implements PlatformInit {
  @override
  Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
  }
}
