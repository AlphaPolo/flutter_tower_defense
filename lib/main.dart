import 'dart:html';

import 'package:flutter/material.dart';
import 'package:tower_defense/screens/my_app.dart';

void main() async {
  window.document.onContextMenu.listen((evt) => evt.preventDefault());
  WidgetsFlutterBinding.ensureInitialized();
  // await initSpineFlutter(enableMemoryDebugging: false);
  runApp(const MyApp());
}