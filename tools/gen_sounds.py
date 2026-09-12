#!/usr/bin/env python3
"""Synthesize soft pastel sound effects + a gentle ambient music loop for Light Path.
Pure stdlib (math/wave/struct) — no numpy. Outputs 16-bit mono 44.1kHz WAVs."""
import math, wave, struct, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "LightPath", "Sounds")
os.makedirs(OUT, exist_ok=True)

def midi(n):
    return 440.0 * (2.0 ** ((n - 69) / 12.0))

def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = min(1.0, 0.9 / peak) if peak > 0.9 else 1.0
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32000)) for s in samples))
    print("wrote", name, len(samples))

def env_adsr(i, n, a, d, s_level, r):
    """ADSR envelope value for sample i of n (a,d,r in seconds, s_level 0..1)."""
    t = i / SR
    total = n / SR
    if t < a:
        return t / a
    if t < a + d:
        return 1 - (1 - s_level) * (t - a) / d
    if t < total - r:
        return s_level
    return s_level * max(0.0, (total - t) / r)

def note(freq, dur, amp=0.5, a=0.005, d=0.05, s=0.5, r=0.08, harmonics=(1.0, 0.35, 0.12)):
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for k, h in enumerate(harmonics, start=1):
            v += h * math.sin(2 * math.pi * freq * k * t)
        out.append(v * amp * env_adsr(i, n, a, d, s, r))
    return out

def add_into(buf, start, samples):
    while len(buf) < start + len(samples):
        buf.append(0.0)
    for i, s in enumerate(samples):
        buf[start + i] += s

def seq(notes):
    """notes: list of (freq, dur, amp, start_offset)."""
    buf = []
    for (f, dur, amp, off) in notes:
        add_into(buf, int(off * SR), note(f, dur, amp=amp, a=0.004, d=0.06, s=0.4, r=0.12))
    return buf


write("tap.wav", note(midi(76), 0.13, amp=0.45, a=0.002, d=0.04, s=0.0, r=0.09,
                      harmonics=(1.0, 0.25)))

write("coin.wav", seq([(midi(88), 0.12, 0.4, 0.0), (midi(95), 0.18, 0.4, 0.08)]))

write("hint.wav", seq([(midi(84), 0.1, 0.3, 0.0), (midi(88), 0.1, 0.3, 0.06),
                       (midi(91), 0.16, 0.3, 0.12)]))

write("win.wav", seq([(midi(72), 0.16, 0.42, 0.00), (midi(76), 0.16, 0.42, 0.10),
                      (midi(79), 0.16, 0.42, 0.20), (midi(84), 0.45, 0.48, 0.32)]))


def pad_chord(midi_notes, dur, amp=0.16):
    n = int(dur * SR)
    out = [0.0] * n
    for m in midi_notes:
        f = midi(m)
        for i in range(n):
            t = i / SR
            e = env_adsr(i, n, a=0.7, d=0.4, s_level=0.8, r=1.0)
            out[i] += amp * e * (math.sin(2 * math.pi * f * t)
                                 + 0.3 * math.sin(2 * math.pi * f * 2 * t))
    return out

bar = 4.0
music = []
chords = [[48, 55, 64, 67],
          [43, 50, 59, 62],
          [45, 52, 60, 64],
          [41, 48, 57, 60]]
for ci, ch in enumerate(chords):
    add_into(music, int(ci * bar * SR), pad_chord(ch, bar + 0.6, amp=0.13))

arp_notes = [72, 76, 79, 83, 79, 76]
for ci in range(4):
    for j, m in enumerate(arp_notes):
        off = ci * bar + j * (bar / len(arp_notes))
        add_into(music, int(off * SR), note(midi(m), 0.5, amp=0.07,
                 a=0.01, d=0.1, s=0.2, r=0.3, harmonics=(1.0, 0.2)))

music = music[:int(16.0 * SR)]
write("music.wav", music)
print("done")
