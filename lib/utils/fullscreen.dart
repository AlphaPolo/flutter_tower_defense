// 跨平台全螢幕：web 走 dart:html 的 Fullscreen API，其餘平台為 no-op。
export 'fullscreen/fullscreen_stub.dart'
    if (dart.library.html) 'fullscreen/fullscreen_web.dart';
