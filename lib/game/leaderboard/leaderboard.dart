import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';

/// 排行榜單筆紀錄。
class LeaderboardEntry {
  const LeaderboardEntry(this.uid, this.name, this.wave, this.ts);
  final String uid;
  final String name;
  final int wave;
  final int ts;
}

/// 無盡模式線上排行榜（Firebase RTDB + 匿名登入）。
///
/// 路徑分桶：`/leaderboards/{env}/s{季號}/{uid}`
/// - env：執行期用網域判斷——正式站 `prod`、其他（staging 站/本機）`staging`；
///   staging 桶在每次部署新版時清空（部署流程跑 database:remove）。
/// - 季號 [kSeason]：「關卡難度有變」才 +1（敵人/塔數值、波次組成、經濟、
///   升級樹、地形規則）；不影響難度的修正（UI/音效/視覺/效能）沿用同一季。
/// - 規則面：只能寫自己的 uid、wave 只能 >=（同分可改名）、欄位驗證。
/// 所有操作失敗都安靜降級（離線/未設定 → 排行榜功能隱藏，本機紀錄照常）。
class Leaderboard {
  Leaderboard._();

  /// 平衡季號：關卡難度有變才 +1。
  static const int kSeason = 1;

  static bool _inited = false;

  /// 是否可用（init 完成後變 true）——UI 監聽它讓排行榜按鈕即時浮現。
  static final ValueNotifier<bool> available = ValueNotifier(false);

  /// app 啟動時呼叫一次；失敗（未設定/離線/測試環境）安靜降級。
  static Future<void> init() async {
    if (!kIsWeb) return; // 目前僅部署 web
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      _inited = true;
      available.value = true;
    } catch (e) {
      debugPrint('Leaderboard init failed: $e');
    }
  }

  /// 環境桶：正式站網域 → prod；其他（-staging 站、localhost）→ staging。
  static String get env {
    if (!kIsWeb) return 'staging';
    final host = Uri.base.host;
    if (host == 'fluttertowerdefense.web.app' ||
        host == 'fluttertowerdefense.firebaseapp.com') {
      return 'prod';
    }
    return 'staging';
  }

  static String get _path => 'leaderboards/$env/s$kSeason';

  /// 匿名登入（冪等），回傳 uid；失敗回 null。
  static Future<String?> ensureSignedIn() async {
    if (!_inited) return null;
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      return auth.currentUser?.uid;
    } catch (e) {
      debugPrint('Leaderboard sign-in failed: $e');
      return null;
    }
  }

  /// 目前 uid（尚未登入回 null，不觸發登入）。
  static String? get currentUid {
    if (!_inited) return null;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // ── 暱稱（prefs 持久化；沒有就自動生成）─────────────────────
  static const _adjectives = [
    '狂暴', '敏捷', '沉默', '炙熱', '冰霜', '雷鳴', '幽影', '嗜金', '不屈', '迅捷', //
  ];
  static const _nouns = [
    '巨蛛', '薩滿', '巨獸', '斥候', '滾木', '火炮', '風刃', '野豬', '哨兵', '獵手', //
  ];

  static Future<String> playerName() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString('playerName');
      if (saved != null && saved.isNotEmpty) return saved;
      final r = Random();
      final name = '${_adjectives[r.nextInt(_adjectives.length)]}的'
          '${_nouns[r.nextInt(_nouns.length)]}${r.nextInt(90) + 10}';
      await p.setString('playerName', name);
      return name;
    } catch (_) {
      return '無名玩家';
    }
  }

  /// 改暱稱：寫回 prefs，並以同分重送更新榜上名字（規則允許 wave >=）。
  static Future<void> setPlayerName(String name, {int? currentWave}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 16) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('playerName', trimmed);
    } catch (_) {}
    if (currentWave != null && currentWave > 0) await submit(currentWave);
  }

  /// 前 [n] 名（wave 大→小；同分早達成者在前）。失敗回空清單。
  static Future<List<LeaderboardEntry>> top({int n = 50}) async {
    if (!_inited) return [];
    try {
      final snap = await FirebaseDatabase.instance
          .ref(_path)
          .orderByChild('wave')
          .limitToLast(n)
          .get();
      final list = <LeaderboardEntry>[];
      for (final c in snap.children) {
        final m = c.value;
        if (m is! Map) continue;
        list.add(LeaderboardEntry(
          c.key ?? '',
          (m['name'] ?? '?').toString(),
          (m['wave'] as num?)?.toInt() ?? 0,
          (m['ts'] as num?)?.toInt() ?? 0,
        ));
      }
      list.sort((a, b) =>
          b.wave != a.wave ? b.wave.compareTo(a.wave) : a.ts.compareTo(b.ts));
      return list;
    } catch (e) {
      debugPrint('Leaderboard top failed: $e');
      return [];
    }
  }

  /// 上傳成績。規則只允許 wave >=（沒破紀錄會被拒）。
  /// 回傳是否成功寫入（false＝被規則拒/離線/未登入）。
  static Future<bool> submit(int wave) async {
    if (wave < 1) return false;
    final uid = await ensureSignedIn();
    if (uid == null) return false;
    try {
      final name = await playerName();
      await FirebaseDatabase.instance.ref('$_path/$uid').set({
        'name': name,
        'wave': wave,
        'ts': ServerValue.timestamp,
      });
      return true;
    } catch (e) {
      debugPrint('Leaderboard submit rejected: $e'); // 沒破紀錄/離線
      return false;
    }
  }
}
