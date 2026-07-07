#!/usr/bin/env python3
"""合成 16-bit 復古風遊戲音效 → assets/audio/*.wav

用法：python3 tool/gen_sfx.py
所有音效皆程式合成（sfxr 風格），無版權疑慮；調參數重跑即可再生成。
44.1kHz / 16-bit / mono。
"""
import wave
import struct
import os
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, decay=None, curve=3.0):
    """attack 秒線性起音 + 其餘指數衰減（curve 越大衰越快）。"""
    a = int(SR * attack)
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    d = n - a
    if d > 0:
        e[a:] = np.exp(-curve * np.arange(d) / d)
    return e


def sine(f, dur):
    return np.sin(2 * np.pi * np.cumsum(np.full(int(SR * dur), f)) / SR)


def sweep(f0, f1, dur, wave_fn=np.sin):
    """頻率由 f0 掃到 f1。"""
    n = int(SR * dur)
    freqs = np.linspace(f0, f1, n)
    phase = 2 * np.pi * np.cumsum(freqs) / SR
    return wave_fn(phase)


def square(phase):
    return np.sign(np.sin(phase))


def saw(phase):
    return 2 * ((phase / (2 * np.pi)) % 1) - 1


def noise(dur):
    return np.random.default_rng(7).uniform(-1, 1, int(SR * dur))


def lowpass(x, alpha):
    """一階 IIR 低通（alpha 0..1，越小越悶）。"""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def note_seq(freqs, each, wave_fn=np.sin, gap=0.0, curve=4.0):
    """依序播放多個音（freq, 時長 each），各自帶衰減包絡。"""
    parts = []
    for f in freqs:
        n = int(SR * each)
        phase = 2 * np.pi * f * np.arange(n) / SR
        parts.append(wave_fn(phase) * env(n, 0.004, curve=curve))
        if gap > 0:
            parts.append(np.zeros(int(SR * gap)))
    return np.concatenate(parts)


def write(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    pcm = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f'{name}.wav  {len(pcm)/SR*1000:.0f}ms  {os.path.getsize(path)//1024}KB')


def main():
    os.makedirs(OUT, exist_ok=True)

    # （click/place/upgrade 已改用 Kenney Interface Sounds，不再合成）

    # 拆除：碎裂噪音下衰
    n = int(SR * 0.28)
    write('demolish', lowpass(noise(0.28), 0.18) * env(n, 0.004, curve=4) *
          np.linspace(1, 0.4, n))

    # 一般射擊：pew（鋸齒下掃）
    n = int(SR * 0.12)
    write('shot', sweep(1400, 320, 0.12, saw) * env(n, 0.002, curve=5), 0.5)

    # 火炮出膛：低頻 boom + 噪音
    n = int(SR * 0.32)
    boom = sweep(130, 45, 0.32) * env(n, 0.004, curve=4)
    boom += lowpass(noise(0.32), 0.12) * env(n, 0.002, curve=5) * 0.7
    write('cannon', boom)

    # 爆炸：更大更長的 boom（低通噪音為主）
    n = int(SR * 0.5)
    exp = lowpass(noise(0.5), 0.10) * env(n, 0.003, curve=3.2)
    exp += sweep(100, 35, 0.5) * env(n, 0.003, curve=3.5) * 0.8
    write('explosion', exp)

    # 雷電：高頻劈啪 + 快速下掃
    n = int(SR * 0.2)
    zap = sweep(2200, 150, 0.2, square) * env(n, 0.001, curve=6)
    crack = noise(0.2) * env(n, 0.001, curve=8)
    write('thunder', zap * 0.7 + crack * 0.5, 0.6)

    # 冰凍：清脆下行琶音（冰晶感）
    write('freeze', note_seq([1760, 1320, 988], 0.08, curve=3), 0.45)

    # 滾木：低頻滾動隆隆（低通噪音 + 低頻抖動）
    n = int(SR * 0.25)
    rumble = lowpass(noise(0.25), 0.06) * env(n, 0.01, curve=3)
    wob = sine(70, 0.25) * env(n, 0.01, curve=3)
    write('log', rumble * 0.8 + wob * 0.6)

    # 敵人死亡：短促 pop（方波下掃）
    n = int(SR * 0.13)
    write('death', sweep(320, 70, 0.13, square) * env(n, 0.002, curve=5), 0.45)

    # （coin 已改用 artisticdude「Inventory Sound Effects」的 sell:buy_item）

    # 漏怪（主堡扣血）：低沉警示雙音（下行）
    write('leak', note_seq([420, 300], 0.16, square, curve=3), 0.5)

    # 失敗：下行三音 sting
    write('lose', note_seq([523, 392, 262], 0.24, square, gap=0.02, curve=2.5),
          0.5)


if __name__ == '__main__':
    main()
