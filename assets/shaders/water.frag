#version 460 core
#include <flutter/runtime_effect.glsl>

// 參考 YouTube《Creating a 2D Water Shader in Unity》(Wizard Shrimp Games) 的
// 2D 卡通水面風格，改寫成 Flutter GLSL fragment shader（水池格用）：
//   1. 雙色藍底（深/淺），用慢速大尺度雜訊做出水深變化
//   2. 兩層反向流動的雜訊疊出「會動」的水面高度場
//   3. 對高度場取等高線 + step，壓出銳利的白色焦散亮線與浪花斑塊
// uniform 維持 uSize/uTime（Dart 端 setFloat 索引不變）。
uniform vec2 uSize;  // 繪製區塊尺寸(px)
uniform float uTime; // 秒
out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// value noise
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int k = 0; k < 4; k++) {
    v += a * noise(p);
    p *= 2.0;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float t = uTime;

  // --- 底色：深/淺藍雙色，用慢速大尺度雜訊做水深變化 ---
  vec3 deep = vec3(0.03, 0.22, 0.60);
  vec3 shallow = vec3(0.18, 0.60, 0.98);
  float depth = fbm(uv * 2.5 + vec2(t * 0.03, -t * 0.02));
  vec3 base = mix(deep, shallow, smoothstep(0.30, 0.75, depth));

  // --- 兩層反向流動的雜訊 → 會動的水面高度場（含輕微扭曲）---
  vec2 warp = vec2(sin(uv.y * 8.0 + t), cos(uv.x * 7.0 + t)) * 0.03;
  float n1 = fbm(uv * 3.5 + warp + vec2(t * 0.10, t * 0.05));
  float n2 = fbm(uv * 5.5 - warp + vec2(-t * 0.07, t * 0.09));
  float surf = n1 * 0.6 + n2 * 0.4;

  // --- 焦散亮線：對高度場取等高線(topographic)，隨時間漂移 ---
  float contour = abs(fract(surf * 4.0) - 0.5) * 2.0; // 等高線邊界→1，中間→0
  float lines = smoothstep(0.80, 0.97, contour);
  lines *= smoothstep(0.45, 0.72, surf); // 只在浪峰處亮，避免整片都是線

  // --- 白色浪花斑塊（銳利 step，強化卡通感）---
  float foamPatch = smoothstep(0.80, 0.82, surf) * 0.6;

  float foam = clamp(lines + foamPatch, 0.0, 1.0);
  vec3 col = mix(base, vec3(1.0), foam);

  fragColor = vec4(col, 0.92);
}
