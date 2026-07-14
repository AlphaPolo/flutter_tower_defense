import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 「此處允許溢出」標籤：掛在會溢出的 Row/Column/Flex 的 key 上，
/// debug 時該處的 RenderFlex overflow 紅字會被 [installOverflowFilter]
/// 靜音；沒掛標籤的 overflow 照常大聲回報（矩陣測試也照抓）。
///
/// ```dart
/// Row(
///   key: kAllowOverflow, // 已知且無害的溢出，宣告靜音
///   children: [...],
/// )
/// ```
///
/// 注意：同一個父層下若有多個要標記的兄弟節點，key 不能重複，
/// 改用 `ValueKey('$kAllowOverflowTag-xxx')`（比對只看字串前綴）。
/// 黃黑條紋是引擎 debug 繪製、標籤管不到；release 兩者皆無。
const String kAllowOverflowTag = 'allow-overflow';
const Key kAllowOverflow = Key(kAllowOverflowTag);

/// debug 專用：靜音「帶 [kAllowOverflow] 標籤」的 RenderFlex overflow 紅字。
/// 其他錯誤（含未標籤的 overflow）照走原本的完整回報。release 為 no-op。
void installOverflowFilter() {
  if (!kDebugMode) return;
  final defaultHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed') && text.contains(kAllowOverflowTag)) {
      return;
    }
    defaultHandler?.call(details);
  };
}
