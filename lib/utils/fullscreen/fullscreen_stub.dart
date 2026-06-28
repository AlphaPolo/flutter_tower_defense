// 非 web 平台：全螢幕由原生 SystemUiMode 處理，這裡是 no-op。
bool get isFullscreen => false;

void enterFullscreen() {}

void exitFullscreen() {}

void toggleFullscreen() {}
