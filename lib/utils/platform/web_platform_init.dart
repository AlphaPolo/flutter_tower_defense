import 'dart:html' as htmlfile;
import 'package:flutter/material.dart';
import '../platform_init.dart';

PlatformInit createStrategyInit() => WebPlatformInit();

class WebPlatformInit implements PlatformInit {
  @override
  Future<void> init() async {
    htmlfile.window.document.onContextMenu.listen((evt) => evt.preventDefault());
    WidgetsFlutterBinding.ensureInitialized();
  }
}
