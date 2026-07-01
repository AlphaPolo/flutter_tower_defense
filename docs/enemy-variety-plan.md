# 敵人多樣性 — 設計規劃（討論用，尚未實作）

> 目標：讓每波不再是「同一種怪放大血量」，而是**多種各有特性的敵人 + 波次配方**，
> 並和現有的塔／陷阱（地刺、渦流、滾木、毒、減速、麻痺、雷連鎖、火炮 AoE）
> 產生剋制關係。

---

## 1. 現況（擴充的起點）

- **敵人只有一種**：`EnemyComponent`（靛藍圓 + 血條），數值只有 `EnemyStatus{totalHp, currentHp, speed}`。
- **波次**：`WaveSpawnerComponent` 每 1 秒生 1 隻、共 `total`(15) 隻，**全部同一個 `status`**。
- 每波數值：`enemyStatusForWave(w)` → `hp = 100 + (w-1)*40`、`speed = 1.5 + (w-1)*0.05`。
- **受傷**：來源直接呼叫 `enemy.dealDamage(double)`（不帶傷害類型）。
- **狀態效果**：`enemy.addEffect(BaseEffect)`；已有 `SlowMovementEffect`(減速/麻痺)、`PoisonEffect`(DoT)。
- **死亡/漏過**：`onEnemyKilled`→金幣+5、`onEnemyLeaked`→生命-1。
- **移動**：沿 flow-field `guide` 一格一格走（`logicalPos` = 顯示/判定位置）。

---

## 2. 共同地基（所有敵人變化都靠這一層）

### 2.1 敵人種類設定 `EnemyKind`
新增一個「不可變設定」描述一種敵人（放 `lib/game/components/enemy_kind.dart`）：

```dart
class EnemyKind {
  final String id;              // 'grunt' / 'scout' / 'brute' ...
  final String name;            // 顯示名（給之後的圖鑑/提示）
  final double hpMul;           // 相對該波基準血量的倍率
  final double speedMul;        // 相對基準速度的倍率
  final int reward;             // 擊殺金幣（取代固定 +5）
  final int leakDamage;         // 漏過扣幾點生命（預設 1；大怪可 2+）

  // 外觀
  final Color color;
  final double sizeMul;         // 圓半徑倍率（或之後換 sprite）

  // 抗性（只減傷、不免疫）
  final double Function(DamageType)? resist; // 各傷害類型倍率（1=正常, ~0.65=抗；不設 0）
  final double effectMul;                    // 狀態效果強度/時間倍率（1=正常, <1=較不受影響；不為 0）

  // 特殊行為旗標（見第 4 節）
  final bool flying;            // 無視地面陷阱
  final bool blocksLog;         // 擋停滾木
  final bool vortexImmune;      // 不被渦流吸/減速
  final EnemyBehavior? behavior;// 分裂 / 治療 / 再生 / 護盾…（可為 null）
}
```

> `EnemyStatus` 維持只放「當前實例的血/速」；**種類設定**與**當下數值**分開：
> spawn 時 `status = base(wave) × kind 的倍率`。

### 2.2 波次配方 `WaveRecipe`
`WaveSpawner` 從「單一 status + total」改成「一串生成指令」：

```dart
// 每波 = 一連串 (kind, 數量, 間隔) 或直接一個生成序列
class WaveRecipe {
  final List<SpawnGroup> groups; // 例：10×grunt(1s) 然後 2×brute(1.5s)
}
```
- `game` 用一張「波次表」`recipeForWave(w)` 決定每波配方（含 Boss 波）。
- 數值基準仍用 `enemyStatusForWave(w)`，各群再乘 kind 倍率。

### 2.3 依種類繪製
`EnemyComponent.render` 依 `kind` 改顏色/大小/形狀（第一版用顏色+大小即可；
之後可換成渲染好的 sprite）。血條保留。

---

## 3. 傷害類型與抗性（定案：只減傷、不完全免疫）

抗性怪對某類傷害**只是「減傷」而非完全免疫**（例：對火傷 ×0.65）。要做到這點，
`dealDamage` 需要知道**傷害類型**：

```dart
enum DamageType { physical, fire, poison, lightning, wind }
void dealDamage(double amount, {DamageType type = DamageType.physical});
```
- 各傷害來源標註類型：地刺/滾木/火炮=physical、火焰=fire、毒=poison、雷=lightning、風刃=wind。
- `dealDamage` 內乘上 `kind.resist(type)`（預設 1.0；抗性怪對某類設約 0.65）。**不設 0，不免疫。**
- 狀態效果（減速/毒 DoT）同理採「**減弱**」而非免疫（需要時縮短時間或降低強度）。

---

## 4. 與現有系統的整合點（每個特殊行為要改哪裡）

| 特性 | 掛在哪 | 做法 |
|---|---|---|
| 效果減弱（減速/毒/麻痺較無效） | `EnemyComponent.addEffect` | 依 `effectMul` 縮短時間/降強度（**不完全免疫**） |
| 傷害減抗（只減傷） | `EnemyComponent.dealDamage` | 乘 `kind.resist(type)`（約 0.65，不為 0） |
| **擋停滾木**（巨獸） | `RollingLogProjectileComponent.onTick` | 壓到 `blocksLog` 的敵人時：對它造成傷害後 `dead=true`（滾木停） |
| **不被渦流吸**（重怪） | `VortexTrap.pullPosition/slowFactor` 或 `game.applyTrapPull` | 對 `vortexImmune` 敵人跳過（需讓力場拿得到 kind 旗標，非只有 hashCode） |
| 分裂 | `EnemyComponent._die` | 死亡時在原地生成 N 隻「小號」kind（血/體型更小） |
| 治療兵 | `EnemyComponent.update` | 週期治療範圍內友軍（用現成的範圍查詢） |
| 再生 | `EnemyComponent.update` | 一段時間沒受傷則回血 |
| 護盾 | `dealDamage` | 先扣護盾值、破盾後才扣血 |

> 注意：目前渦流力場是「敵人自己在 `applyTrapPull` 取樣」，只傳了 `hashCode`。
> 要做 `vortexImmune`（巨獸），需讓取樣時能判斷該敵人的 kind（把旗標一起傳入，
> 或改成傳敵人參考）。這是唯一需要小改介面的地方。
> （`vortexImmune`/`blocksLog` 是**機制免疫**，與第 3 節的「傷害減抗」是兩回事。）

---

## 5. 敵人型錄（候選清單）

### A. 純屬性型（低難度，先做地基驗證）
| 敵人 | 血 | 速 | 賞金 | 外觀 | 剋制關係 |
|---|---|---|---|---|---|
| 雜兵 grunt | 1.0 | 1.0 | 5 | 靛藍中圓（現況） | 基準 |
| 斥候 scout | 0.5 | 1.8 | 4 | 黃、小 | 被減速(冰/雷)、渦流聚起來 |
| 坦克 brute | 3.0 | 0.6 | 12 | 紅、大 | 被毒 DoT、持續輸出；漏過扣 2 |
| 蟲群 swarm | 0.25 | 1.2 | 2 | 綠、極小、量多 | 火炮/滾木/地刺一次清 |

### B. 互動型（中難度，發揮現有陷阱/塔）
| 敵人 | 特性 | 剋制關係 |
|---|---|---|
| 巨獸 juggernaut | 極高血、慢、**擋停滾木**、**不被渦流吸**、漏過扣 2~3 | 只能靠塔硬打；毒/火持續 |
| 抗性怪 warded | 對某類傷害 ×0.65（火抗/毒抗/物抗三選一，只減傷不免疫） | 逼玩家換塔種搭配 |

> **飛行怪暫緩**：概念（無視地面陷阱）保留備用，本輪先不做。

### C. 特殊行為型（中高難度，風味足）
| 敵人 | 特性 | 剋制關係 |
|---|---|---|
| 分裂怪 splitter | 死亡分裂成 2 小隻 | AoE(火炮/滾木/地刺)收尾避免雪球 |
| 護盾兵 shielded | 前 N 點傷害被護盾吸收 | 高單發(火炮/雷)破盾 |
| 治療兵 healer | 週期治療周圍友軍 | 優先點殺（雷連鎖/狙擊） |
| 再生怪 regen | 沒被打就回血 | 持續輸出(毒/火)壓制 |

---

## 6. 波次進程（定案）

**外觀**：先用**顏色圓**（大小/顏色）區分，暫不做 sprite。
**分配**：**混合制** —— 權重填充（自動）＋ 解鎖波 / Boss / 招牌小隊（手動）。
**飛行怪**：暫緩。
**節奏**：多樣性從 **W3** 起，每約 2 波導入一種；Boss 落在 **10 / 15 / 20 / 25**。

### 6.1 組成兩層
- **權重填充（自動）**：依「已解鎖敵人的權重」把該波總量分配成背景雜混。
- **招牌小隊 combo（手動）**：在指定波插入「擠在一起出現」的互補小隊當主菜。
  > 小隊必須成群同時出現才有意義（例：補師只治療周圍友軍，得跟坦克同隊）。
- **Boss 波（手動覆蓋）**：1 Boss ＋ 少量護衛。

一波 = 有序生成序列：
```
WaveRecipe  = [SpawnEntry...]
SpawnEntry  = 單種(kind, count, interval)  |  小隊 Squad[(kind,count)...]（緊湊生成）
```
總量參考：`total ≈ 12 + round(wave × 0.6)`（W1≈13 → W25≈27）。

### 6.2 解鎖表（第一次登場）
| 敵人 | 解鎖波 | 解鎖後權重 |
|---|---|---|
| 雜兵 grunt | 1 | 高 →（後期讓位給其他） |
| 斥候 scout | 3 | 中 |
| 蟲群 swarm | 5 | 中（成群） |
| 坦克 brute | 6 | 中 |
| 抗性怪 warded | 11 | 中低 |
| 分裂怪 splitter | 13 | 中低 |
| 護盾兵 shielded | 16 | 低 |
| 補師 healer | 18 | 低（多在小隊裡） |
| 再生怪 regen | 21 | 低 |
| 巨獸 juggernaut | 僅 Boss 波 | — |
> 新敵人「解鎖那波」固定給少量（約 3 隻）試水溫，之後才按權重成長。

### 6.3 逐波進程（招牌小隊 & Boss 手動指定，其餘為權重填充）
| 波 | 新登場 | 招牌小隊 combo | 備註 |
|---|---|---|---|
| 1–2 | 雜兵 | — | 教學、建立經濟 |
| 3 | 斥候 | — | 少量斥候試水溫 |
| 4 | — | — | 雜兵＋斥候混 |
| 5 | 蟲群 | — | 蟲群首度成群 → 學 AoE |
| 6 | 坦克 | — | 坦克試水溫 |
| 7 | — | **坦克×2 ＋ 斥候×3** | 首個 combo：火力被坦吸、快兵繞側 |
| 8–9 | — | 斥候/蟲群/坦克混、加量 | 喘息＋熟悉 |
| 10 | **Boss①巨獸** | 巨獸×1 ＋ 雜兵×6 護衛 | 擋滾木／渦流免疫考核 |
| 11 | 抗性怪 | — | 逼混搭塔種 |
| 12 | — | 坦克×2 ＋ 斥候×3 | combo 加強 |
| 13 | 分裂怪 | — | |
| 14 | — | **分裂怪×3 ＋ 蟲群×6** | 數量雪球 → 逼 AoE 收尾 |
| 15 | **Boss②** | 巨獸×1 ＋ 坦克×2 ＋ 蟲群 | |
| 16 | 護盾兵 | — | |
| 17 | — | 護盾兵×2 ＋ 坦克×2 | 耐久牆 |
| 18 | 補師 | — | |
| 19 | — | **坦克×2 ＋ 補師×1** | 持久戰：先點殺補師 |
| 20 | **Boss③** | 巨獸×1 ＋ 護盾兵 ＋ 補師 護衛 | |
| 21 | 再生怪 | — | |
| 22 | — | **護盾兵 ＋ 補師 ＋ 再生** | 超級耐久牆 |
| 23 | — | 分裂怪 ＋ 蟲群 ＋ 斥候 | 數量地獄 |
| 24 | — | 綜合精英混編 | 決戰前 |
| 25 | **最終 Boss** | 大 Boss×1 ＋ 精英護衛 | 多機制總考核 |

---

## 7. 敵人資訊 UI（定案）

- 位置：**波次按鈕（開始/下一波）的右邊**放一排**敵人 icon**（顏色圓，與場上一致）。
- 互動：**點擊某個 icon → 浮出該敵人的資訊卡**（名稱 + 特性：血/速傾向、抗性、特殊行為、剋制提示）。
  沿用現有「格子資訊面板」的浮出面板概念即可。
- 顯示哪些：預設**已解鎖（出現過）的敵人**當作圖鑑，隨進度增加。
  > 待確認的小點：是否改成只顯示「下一波會出現的種類」當預覽。先做「已解鎖圖鑑」。
- 實作掛點：`game_overlays.dart` 的 `LeftColOverlay`（bottomLeft 已有開始鈕），
  在其右側加 icon 列；資訊卡用一個 overlay 面板（點 icon 設定 `ValueNotifier<EnemyKind?>`）。

---

## 8. 建議的分階段實作

1. **地基 + A 批（純屬性）**：`EnemyKind` + 波次配方（權重填充）+ 依顏色/大小繪製 + spawn 混生。
   實作 雜兵/斥候/坦克/蟲群。→ 驗證系統跑順、視覺分得清。（平衡先不抓）
2. **招牌小隊 + Boss 波**：`Squad` 生成 + 逐波進程表（§6.3）+ 巨獸 Boss。
3. **抗性減傷層**：加 `DamageType` + `dealDamage` 減抗 + `addEffect` 減弱 → 做「抗性怪」。
4. **互動型**：巨獸(擋滾木+渦流免疫)。→ 需要第 4 節的渦流力場小介面調整。
5. **特殊行為型**：分裂 → 護盾 → 補師 → 再生。
6. **敵人資訊 UI**（§7）：波次按鈕旁的 icon 列 + 點擊資訊卡。可與第 1 階段一起或緊接其後。

每階段照慣例：`flutter analyze` → build → 部署 staging 驗證 → commit。

---

## 9. 決策紀錄與待決問題

**已定案**
- ✅ 外觀：先用**顏色/大小的圓**（暫不做 sprite）。
- ✅ 分配：**混合制**（權重填充 + 手動解鎖/Boss/小隊）。
- ✅ 節奏：多樣性 W3 起、Boss 10/15/20/25、combo 從 W7（坦克+斥候）起，補師類 combo 待 W18 解鎖後。
- ✅ 一波可同時多種、且用「小隊」做互補 combo。
- ✅ 抗性：**只減傷、不完全免疫**（約 ×0.65）；狀態效果採減弱而非免疫。
- ✅ 平衡：**先不抓**（同關卡策略）。
- ✅ 敵人資訊 UI：波次按鈕右側 icon 列，點擊浮出資訊卡（見 §7）。
- ⏸ 飛行怪暫緩。

**待確認的小點**
1. 資訊 icon 列顯示「已解鎖圖鑑」還是「下一波預覽」？（暫定：已解鎖圖鑑）

---

*（本檔僅為規劃，未改動任何遊戲程式。）*
