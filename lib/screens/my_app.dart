import 'dart:async';

import 'package:flutter/material.dart';

import 'home/home_screen.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

Timer? _bannerTimer;

/// 從畫面「上方」彈出一則提示，改用 Material 官方的 [MaterialBanner]（顯示在頂部，
/// 不再壓到底部建造列）。MaterialBanner 本身不會自動消失、且至少要有一個 action，
/// 所以這裡附一個「✕」關閉鈕，並用 Timer 到時自動收起。
void showTopMessage(String message,
    {Duration duration = const Duration(seconds: 2)}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  _bannerTimer?.cancel();
  messenger
    ..clearMaterialBanners()
    ..showMaterialBanner(
      MaterialBanner(
        // elevation != 0 → Scaffold 不把 body 往下推，banner 改成「浮」在遊戲上方
        // （像 floating SnackBar），因此不會 resize 遊戲 → 不觸發相機重置。
        elevation: 3,
        backgroundColor: const Color(0xFFD64541).withOpacity(0.96),
        content: Text(message),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: () => messenger.hideCurrentMaterialBanner(),
          ),
        ],
      ),
    );
  _bannerTimer = Timer(duration, messenger.hideCurrentMaterialBanner);
}

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