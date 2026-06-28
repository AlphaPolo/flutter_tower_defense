import 'dart:html' as html;

// Web 全螢幕：用瀏覽器 Fullscreen API。需由使用者手勢(按鈕)觸發。
// iOS Safari 行動版不支援頁面全螢幕，呼叫會被忽略(需加入主畫面當 PWA)。
bool get isFullscreen => html.document.fullscreenElement != null;

void enterFullscreen() {
  html.document.documentElement?.requestFullscreen();
}

void exitFullscreen() {
  html.document.exitFullscreen();
}

void toggleFullscreen() {
  if (isFullscreen) {
    exitFullscreen();
  } else {
    enterFullscreen();
  }
}
