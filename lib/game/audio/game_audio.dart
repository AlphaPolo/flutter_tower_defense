import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tower_type.dart';

/// 全域音訊（flutter_soloud）：
/// - UI 音效用一般 2D 播放；世界音效（開火/爆炸/擊殺）用 3D 定位——
///   listener 掛在相機上（拉遠 z 升高 → 變遠變小聲；偏左的塔聲音偏左耳）。
/// - BGM 雙軌（皆為 Alexandr Zhelanov「Unused music」，CC-BY 3.0，
///   https://opengameart.org/content/unused-music）：開場佈陣播 improvisation 1
///   （calm），第一波開打 crossfade 到 Track_1（battle）；重新開始切回 calm。
///   勝利 jingle 為 xDeviruchi「Victory!」（Marllon Silva）。
/// - 網頁的聲音要在「首次使用者互動」後才能出聲 → [ensureStarted] 掛在輸入事件，
///   第一次點擊才初始化引擎並開始 BGM。
class GameAudio {
  GameAudio._();

  static final ValueNotifier<bool> sfxOn = ValueNotifier(true);
  static final ValueNotifier<bool> bgmOn = ValueNotifier(true);

  /// 玩家音量（0..1）。SFX 為每次播放的乘數；BGM 直接是循環軌的音量。
  static final ValueNotifier<double> sfxVol = ValueNotifier(0.8);
  static final ValueNotifier<double> bgmVol = ValueNotifier(0.35);

  static bool _ready = false;
  static bool _starting = false;
  static bool _prefsLoaded = false;

  /// 讀取音訊設定（開關/音量），之後任何變更自動寫回。app 啟動時呼叫一次。
  static Future<void> loadPrefs() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      sfxOn.value = p.getBool('sfxOn') ?? sfxOn.value;
      bgmOn.value = p.getBool('bgmOn') ?? bgmOn.value;
      sfxVol.value = p.getDouble('sfxVol') ?? sfxVol.value;
      bgmVol.value = p.getDouble('bgmVol') ?? bgmVol.value;
      sfxOn.addListener(() => p.setBool('sfxOn', sfxOn.value));
      bgmOn.addListener(() => p.setBool('bgmOn', bgmOn.value));
      sfxVol.addListener(() => p.setDouble('sfxVol', sfxVol.value));
      bgmVol.addListener(() => p.setDouble('bgmVol', bgmVol.value));
    } catch (e) {
      debugPrint('GameAudio loadPrefs failed: $e'); // 存取失敗照預設值走
    }
  }
  static final Map<String, AudioSource> _srcs = {};
  static SoundHandle? _bgmHandle;
  static final Map<String, int> _lastMs = {}; // 每音效上次播放時間 → 節流

  /// 音效名 → 檔名。UI 層用 Kenney Interface Sounds（CC0）；
  /// 世界/戰鬥層用 tool/gen_sfx.py 合成的 16-bit 風格音。
  static const _sfxFiles = {
    // ── UI（Kenney）──
    'click': 'click.ogg', // 按鈕/頁籤
    'select': 'select.ogg', // 選取要蓋的塔
    'drop': 'drop.ogg', // 蓋塔/陷阱落地
    'confirm': 'confirm.ogg', // 升級成功
    'error': 'error.ogg', // 金幣不足/不能放
    'switch': 'switch.ogg', // 設定開關
    'hover': 'hover.ogg', // 滑鼠懸停建造列（Kenney UI Audio rollover）
    // ── 世界/戰鬥（合成）──
    'demolish': 'demolish.wav',
    'shot': 'shot.wav',
    'cannon': 'cannon.ogg', // rubberduck「25 CC0 bang SFX」cannon_04（CC0）
    'explosion': 'explosion.wav',
    'thunder': 'thunder.wav',
    'log': 'log.wav',
    'death': 'death.wav',
    'coin': 'coin.wav', // artisticdude「Inventory SFX」sell/buy（CC-BY 3.0）
    'leak': 'leak.wav',
    'lose': 'lose.wav',
  };

  /// 首次使用者互動時呼叫：初始化引擎、載入音檔、開 BGM。可重複呼叫（冪等）。
  static Future<void> ensureStarted() async {
    if (_ready || _starting) return;
    _starting = true;
    try {
      final so = SoLoud.instance;
      await so.init();
      // listener 面向 -z（俯視棋盤）、up=+y → 世界 +x 在右耳。
      so.set3dListenerAt(0, 0, -1);
      so.set3dListenerUp(0, 1, 0);
      for (final e in _sfxFiles.entries) {
        _srcs[e.key] = await so.loadAsset('assets/audio/${e.value}');
      }
      _srcs['bgm_calm'] = await so.loadAsset('assets/audio/bgm_calm.mp3');
      _srcs['bgm_battle'] = await so.loadAsset('assets/audio/bgm_main.ogg');
      _srcs['victory'] = await so.loadAsset('assets/audio/victory.mp3');
      _ready = true;
      bgmOn.addListener(_syncBgm);
      bgmVol.addListener(() {
        final h = _bgmHandle;
        if (h != null) so.setVolume(h, bgmVol.value);
      });
      _syncBgm();
    } catch (e) {
      debugPrint('GameAudio init failed: $e'); // 無聲降級，不影響遊戲
    } finally {
      _starting = false;
    }
  }

  static const _fade = Duration(milliseconds: 1500);
  static String _bgmTrack = 'bgm_calm'; // 目前想播的軌（calm/battle）
  static String? _playingTrack; // _bgmHandle 實際在播的軌

  /// 開打（第一波開始）→ crossfade 到戰鬥曲。冪等：已在戰鬥曲則無動作。
  static void bgmBattle() => _switchBgm('bgm_battle');

  /// 回到佈陣（重新開始）→ crossfade 回開場曲。
  static void bgmCalm() => _switchBgm('bgm_calm');

  static Future<void> _switchBgm(String key) async {
    _bgmTrack = key;
    if (!_ready || !bgmOn.value) return; // 關著就只記狀態，開啟時 _syncBgm 補播
    if (_playingTrack == key && _bgmHandle != null) return;
    final so = SoLoud.instance;
    final old = _bgmHandle;
    if (old != null) {
      // 舊軌淡出並排程停止（淡出結束的瞬間停，避免殘留 voice）。
      so.fadeVolume(old, 0, _fade);
      so.scheduleStop(old, _fade);
    }
    // 新軌從 0 淡入到目標音量。
    final h = await so.play(_srcs[key]!, volume: 0, looping: true);
    so.fadeVolume(h, bgmVol.value, _fade);
    _bgmHandle = h;
    _playingTrack = key;
  }

  static Future<void> _syncBgm() async {
    if (!_ready) return;
    final so = SoLoud.instance;
    final h = _bgmHandle;
    if (bgmOn.value) {
      if (h == null || _playingTrack != _bgmTrack) {
        // 尚未播或軌不對 → 播目前想要的軌（含淡入）。
        _playingTrack = null;
        await _switchBgm(_bgmTrack);
      } else {
        so.setPause(h, false);
      }
    } else if (h != null) {
      so.setPause(h, true);
    }
  }

  /// UI / 全域音效（不定位）。[throttleMs] 內同名只播一次，避免同幀疊爆。
  static void ui(String name, {double volume = 1, int throttleMs = 70}) {
    if (!_ready || !sfxOn.value) return;
    if (_throttled(name, throttleMs)) return;
    SoLoud.instance
        .play(_srcs[name]!, volume: volume * sfxVol.value)
        .ignore();
  }

  /// 世界音效：以世界座標 3D 播放（隨相機距離衰減、左右定位）。
  static void world(String name, Vector2 pos,
      {double volume = 1, int throttleMs = 70}) {
    if (!_ready || !sfxOn.value) return;
    if (_throttled(name, throttleMs)) return;
    final so = SoLoud.instance;
    so
        .play3d(_srcs[name]!, pos.x, pos.y, 0,
            volume: volume * sfxVol.value)
        .then((h) {
      // 線性衰減：300px 內全音量，3200px 外靜音（棋盤圖對角約 2200）。
      so.set3dSourceMinMaxDistance(h, 300, 3200);
      so.set3dSourceAttenuation(h, 2 /*linear*/, 1.0);
    }).ignore();
  }

  /// 每幀由 game.update 呼叫：listener 跟著相機走，拉遠(zoom 小)時 z 升高
  /// → 整體變遠變小聲；拉近貼地 → 聲音近而清晰。
  static void updateListener(Vector2 camPos, double zoom) {
    if (!_ready) return;
    final z = 500 / zoom.clamp(0.2, 3.0);
    SoLoud.instance.set3dListenerPosition(camPos.x, camPos.y, z);
  }

  /// 塔開火音效（依塔種），在塔的世界座標 3D 播放。
  static void fire(TowerType type, Vector2 pos) {
    switch (type) {
      case TowerType.cannon:
        world('cannon', pos, volume: 0.9, throttleMs: 90);
      case TowerType.thunder:
        world('thunder', pos, volume: 0.55, throttleMs: 90);
      case TowerType.freezing:
        break; // 冰環施放頻繁、疊起來吵，不配音
      case TowerType.log:
        world('log', pos, volume: 0.9, throttleMs: 140);
      case TowerType.flame:
        break; // 持續噴射型：常駐音焦躁，先不配
      default:
        world('shot', pos, volume: 0.4, throttleMs: 80);
    }
  }

  /// 勝/敗演出：BGM 淡出停止、播對應 jingle。
  static void gameEnd({required bool won}) {
    if (!_ready) return;
    final h = _bgmHandle;
    if (h != null) {
      SoLoud.instance.fadeVolume(h, 0, const Duration(milliseconds: 600));
      SoLoud.instance.scheduleStop(h, const Duration(milliseconds: 600));
      _bgmHandle = null;
      _playingTrack = null;
    }
    if (!sfxOn.value && !bgmOn.value) return;
    SoLoud.instance
        .play(_srcs[won ? 'victory' : 'lose']!, volume: 0.6 * sfxVol.value)
        .ignore();
  }

  /// 重新開始：回到開場（佈陣）曲，淡入接手（勝/敗 jingle 可能還在放尾音）。
  static void restart() {
    if (!_ready) return;
    bgmCalm();
  }

  static bool _throttled(String name, int ms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastMs[name] ?? 0) < ms) return true;
    _lastMs[name] = now;
    return false;
  }
}
