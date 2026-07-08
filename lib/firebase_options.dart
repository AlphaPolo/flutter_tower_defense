import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase 設定（來源：`firebase apps:sdkconfig WEB`，手動整理）。
/// 本專案只部署 web，其他平台不設定。
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Firebase 僅設定 web 平台');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCaWEfJSts_LR7DpjIFP7yiGhfbCt8KLLE',
    appId: '1:1065760260290:web:41e2da62ecc1180aeafb5b',
    messagingSenderId: '1065760260290',
    projectId: 'fluttertowerdefense',
    authDomain: 'fluttertowerdefense.firebaseapp.com',
    storageBucket: 'fluttertowerdefense.firebasestorage.app',
    // 注意：RTDB 實例建立後要填正確的 databaseURL（依所選地區而異）。
    databaseURL:
        'https://fluttertowerdefense-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
