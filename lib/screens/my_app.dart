import 'package:flutter/material.dart';

import 'home/home_screen.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Tower Defense',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,

      ),
      builder: (context, child) {
        return _OrientationGate(child: child!);
      },
      // themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

/// 直向時（主要是手機網頁，瀏覽器不吃 setPreferredOrientations）提示玩家旋轉裝置。
class _OrientationGate extends StatelessWidget {
  const _OrientationGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 只有手機(原生或網頁)才限制方向；桌機任何視窗大小都正常顯示。
    // final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
    //     defaultTargetPlatform == TargetPlatform.android;
    // if (!isMobile) return child;

    return OrientationBuilder(
      builder: (context, orientation) {
        // return RotatedBox(
        //   quarterTurns: orientation != Orientation.landscape ? 1 : 0,
        //   child: child,
        // );
        return Stack(
          children: [
            child,
            if (orientation != Orientation.landscape)
              _buildHintOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildHintOverlay() {
    return const Material(
      type: MaterialType.transparency,
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.screen_rotation, color: Colors.white70, size: 64),
                SizedBox(height: 16),
                Text(
                  '請將裝置橫向使用',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}