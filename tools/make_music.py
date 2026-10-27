"""Moonpull soundtrack generator (synthwave). Writes game/music/run.ogg and menu.ogg.

Everything is synthesised here (no samples), so the music is 100% ours to use
commercially. Run:  python3 tools/make_music.py   (needs numpy, scipy, ffmpeg)

Both tracks loop seamlessly: the tails of delays/reverb that run past the loop
end are folded back onto the start.
"""
import os
import subprocess
import numpy as np
from scipy.signal import butter, lfilter, fftconvolve

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(7)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lp(x, cutoff, order=2):
    b, a = butter(order, min(cutoff / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, cutoff, order=2):
    b, a = butter(order, cutoff / (SR / 2), "high")
    return lfilter(b, a, x)


def saw(f, n, detune=0.0, phase=0.0):
    t = np.arange(n) / SR
    p = (f * (1 + detune) * t + phase) % 1.0
    return 2 * p - 1


def square(f, n, pw=0.5):
    t = np.arange(n) / SR
    return np.where((f * t) % 1.0 < pw, 1.0, -1.0)


class Track:
    def __init__(self, bpm, bars, tail=4.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.length = bars * 4 * self.beat
        self.n = int(self.length * SR)
        total = self.n + int(tail * SR)
        self.bus = {k: np.zeros((total, 2)) for k in ["drums", "bass", "pad", "arp", "lead", "fx"]}
        self.kicks = []

    def at(self, beat):
        return int(beat * self.beat * SR)

    def put(self, bus, sig, start, pan=0.0):
        s = self.at(start) if isinstance(start, float) or isinstance(start, int) else start
        buf = self.bus[bus]
        end = min(s + len(sig), len(buf))
        if end <= s:
            return
        l = np.cos((pan + 1) * np.pi / 4)
        r = np.sin((pan + 1) * np.pi / 4)
        buf[s:end, 0] += sig[: end - s] * l * 1.414
        buf[s:end, 1] += sig[: end - s] * r * 1.414

    # ---------------------------------------------------------------- drums
    def kick(self, beat, vol=1.0):
        n = int(0.45 * SR)
        t = np.arange(n) / SR
        f = 48 + 110 * np.exp(-t * 28)
        ph = 2 * np.pi * np.cumsum(f) / SR
        body = np.sin(ph) * np.exp(-t * 7.5)
        click = hp(rng.standard_normal(n), 3000) * np.exp(-t * 300) * 0.25
        self.put("drums", np.tanh((body + click) * 1.6) * 0.9 * vol, beat)
        self.kicks.append(self.at(beat))

    def snare(self, beat, vol=1.0):
        n = int(0.5 * SR)
        t = np.arange(n) / SR
        noise = hp(lp(rng.standard_normal(n), 9000), 400) * np.exp(-t * 9)
        tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.6
        self.put("drums", (noise * 0.55 + tone) * 0.55 * vol, beat)
        # big 80s room: a gated reverb burst
        room = hp(rng.standard_normal(int(0.28 * SR)), 900) * np.linspace(0.18, 0.0, int(0.28 * SR)) ** 0.6
        self.put("fx", room * 0.22 * vol, beat + 0.02)

    def hat(self, beat, vol=1.0, open_=False):
        n = int((0.22 if open_ else 0.06) * SR)
        t = np.arange(n) / SR
        x = hp(rng.standard_normal(n), 7000) * np.exp(-t * (14 if open_ else 70))
        self.put("drums", x * 0.22 * vol, beat, pan=0.25)

    def clap(self, beat, vol=1.0):
        n = int(0.3 * SR)
        t = np.arange(n) / SR
        x = np.zeros(n)
        for k, d in enumerate([0.0, 0.011, 0.022]):
            i = int(d * SR)
            x[i:] += hp(lp(rng.standard_normal(n - i), 6000), 800) * np.exp(-t[: n - i] * (60 if k < 2 else 14))
        self.put("drums", x * 0.3 * vol, beat, pan=-0.1)

    # ---------------------------------------------------------------- tonal
    def bass(self, beat, length, midi, vol=1.0):
        n = int((length * self.beat + 0.05) * SR)
        f = hz(midi)
        x = saw(f, n) * 0.6 + saw(f, n, 0.004) * 0.4 + np.sin(2 * np.pi * f / 2 * np.arange(n) / SR) * 0.5
        t = np.arange(n) / SR
        y = lp(x, 900) * 0.4 + lp(x, 380) * 0.6
        y = y * (0.6 + 0.4 * np.exp(-t * 12))
        e = np.minimum(1, t / 0.004) * np.minimum(1, (n / SR - t) / 0.03)
        self.put("bass", np.tanh(y * 1.4) * e * 0.42 * vol, beat)

    def pad(self, beat, length, notes, vol=1.0, bright=1800):
        n = int((length * self.beat + 1.2) * SR)
        t = np.arange(n) / SR
        hold = length * self.beat
        e = np.minimum(1, t / 0.35) * np.where(t < hold, 1.0, np.exp(-(t - hold) / 0.45))
        for i, m in enumerate(notes):
            f = hz(m)
            for d, pan in [(-0.006, -0.6), (0.0, 0.0), (0.0065, 0.6)]:
                x = saw(f, n, d, phase=rng.random())
                self.put("pad", lp(x, bright) * e * 0.055 * vol, beat, pan=pan)

    def arp_note(self, beat, midi, vol=1.0, pan=0.0, length=0.22):
        n = int(length * SR)
        t = np.arange(n) / SR
        f = hz(midi)
        x = square(f, n, 0.3) * 0.5 + saw(f, n, 0.003) * 0.5
        k = np.exp(-t * 20)            # filter "pluck": bright attack, darker tail
        x = lp(x, 5000) * k + lp(x, 2400) * (1 - k)
        self.put("arp", x * np.exp(-t * 11) * np.minimum(1, t / 0.002) * 0.17 * vol, beat, pan=pan)

    def lead_note(self, beat, length, midi, vol=1.0):
        n = int((length * self.beat + 0.25) * SR)
        t = np.arange(n) / SR
        hold = length * self.beat
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.35)
        f = hz(midi) * vib
        ph = np.cumsum(f) / SR
        x = (2 * (ph % 1.0) - 1) * 0.55 + np.where((ph * 1.003) % 1.0 < 0.5, 1, -1) * 0.35 + np.sin(2 * np.pi * ph * 0.5) * 0.3
        x = lp(x, 3200)
        e = np.minimum(1, t / 0.012) * np.where(t < hold, 0.85 + 0.15 * np.exp(-t * 6), np.exp(-(t - hold) / 0.08))
        self.put("lead", x * e * 0.2 * vol, beat)

    def bell(self, beat, midi, vol=1.0, decay=1.4, bus="lead", pan=0.0):
        """FM bell / glockenspiel."""
        n = int(decay * 2.2 * SR)
        t = np.arange(n) / SR
        f = hz(midi)
        idx = 2.2 * np.exp(-t * 6)
        x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t))
        x += 0.3 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 5)
        e = np.exp(-t / decay * 2.2) * np.minimum(1, t / 0.002)
        self.put(bus, x * e * 0.22 * vol, beat, pan=pan)

    def organ(self, beat, length, notes, vol=1.0):
        n = int((length * self.beat + 0.6) * SR)
        t = np.arange(n) / SR
        hold = length * self.beat
        e = np.minimum(1, t / 0.08) * np.where(t < hold, 1.0, np.exp(-(t - hold) / 0.2))
        vib = 1 + 0.004 * np.sin(2 * np.pi * 6.2 * t)
        for m in notes:
            f = hz(m)
            ph = np.cumsum(f * vib) / SR
            x = sum(w * np.sin(2 * np.pi * ph * h) for h, w in [(0.5, 0.5), (1, 1.0), (2, 0.6), (3, 0.35), (4, 0.2)])
            self.put("pad", x * e * 0.05 * vol, beat, pan=0.0)

    def sleigh(self, beat, vol=1.0):
        n = int(0.12 * SR)
        t = np.arange(n) / SR
        x = hp(lp(rng.standard_normal(n), 12000), 6500)
        x = x * (1 + 0.6 * np.sin(2 * np.pi * 70 * t)) * np.exp(-t * 30)
        self.put("drums", x * 0.2 * vol, beat, pan=0.3)

    def riser(self, beat, beats):
        n = int(beats * self.beat * SR)
        t = np.arange(n) / SR
        x = hp(rng.standard_normal(n), 1200) * (t / t[-1]) ** 2
        self.put("fx", lp(x, 9000) * 0.08, beat)

    # ---------------------------------------------------------------- mix
    def render(self, duck=0.55):
        total = len(self.bus["drums"])
        # sidechain pump from the kicks (classic synthwave breathing)
        g = np.ones(total)
        for k in self.kicks:
            m = min(int(0.32 * SR), total - k)
            if m > 0:
                g[k : k + m] = np.minimum(g[k : k + m], 1 - duck * np.exp(-np.arange(m) / SR / 0.11))
        g2 = g[:, None]
        # delay on arp + lead (dotted eighth, ping-pong)
        d = int(0.75 * self.beat * SR)
        for name, fb, mix in [("arp", 0.38, 0.45), ("lead", 0.3, 0.32)]:
            dry = self.bus[name]
            wet = np.zeros_like(dry)
            mono = dry.mean(axis=1)
            for k in range(1, 6):   # echoes bounce left / right
                shift = d * k
                if shift >= total:
                    break
                wet[shift:, k % 2] += mono[: total - shift] * (fb ** k)
            self.bus[name] = dry + lp(wet.T, 4000).T * mix
        # reverb (decaying-noise impulse response, separate per channel)
        ir_len = int(2.4 * SR)
        tt = np.arange(ir_len) / SR
        irs = [lp(rng.standard_normal(ir_len), 6000) * np.exp(-tt / 0.55) for _ in range(2)]
        irs = [ir / np.sqrt(np.sum(ir ** 2)) for ir in irs]
        send = self.bus["pad"] * 0.35 + self.bus["lead"] * 0.5 + self.bus["arp"] * 0.3 + self.bus["fx"] * 0.6 + self.bus["drums"] * 0.08
        rev = np.stack([fftconvolve(send[:, c], irs[c])[:total] for c in range(2)], axis=1) * 0.55
        mix = (self.bus["drums"] * 1.0
               + self.bus["bass"] * g2
               + self.bus["pad"] * (0.35 + 0.65 * g2)
               + self.bus["arp"] * (0.7 + 0.3 * g2)
               + self.bus["lead"] * 1.0
               + self.bus["fx"]
               + rev * (0.5 + 0.5 * g2))
        # fold the tail back onto the start -> seamless loop
        out = mix[: self.n].copy()
        tail = mix[self.n :]
        out[: len(tail)] += tail[: self.n]
        # gentle master: low-cut, glue, soft clip, normalise
        out = hp(out.T, 30).T
        out = np.tanh(out * 1.25) / np.tanh(1.25)
        out = out / np.max(np.abs(out)) * 0.89
        return out


def write_ogg(sig, name):
    os.makedirs(os.path.join(ROOT, "game/music"), exist_ok=True)
    raw = os.path.join(ROOT, "game/music", name + ".raw")
    (sig * 32767).astype("<i2").tofile(raw)
    dst = os.path.join(ROOT, "game/music", name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", raw,
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    os.remove(raw)
    print(name, f"{len(sig) / SR:.1f}s", os.path.getsize(dst) // 1024, "KB")


# A minor: Am - F - C - G (i - VI - III - VII), two bars each
CHORDS = [
    (45, [57, 60, 64]),   # Am
    (41, [57, 60, 65]),   # F
    (48, [55, 60, 64]),   # C
    (43, [55, 59, 62]),   # G
]

# lead hook, 8 bars: (beat, length, midi)
HOOK = [
    (0, 1, 69), (1, 0.5, 72), (1.5, 1.5, 76), (3, 0.5, 74), (3.5, 0.5, 72),
    (4, 2, 72), (6, 1, 71), (7, 1, 69),
    (8, 1, 69), (9, 0.5, 72), (9.5, 1.5, 77), (11, 1, 76),
    (12, 3, 72), (15, 1, 74),
    (16, 1, 76), (17, 0.5, 79), (17.5, 1.5, 79), (19, 0.5, 76), (19.5, 0.5, 74),
    (20, 2, 76), (22, 1, 74), (23, 1, 72),
    (24, 1, 71), (25, 0.5, 74), (25.5, 1.5, 79), (27, 1, 78),
    (28, 4, 79),
]
HOOK_B = [  # answer phrase (second time round)
    (0, 1.5, 81), (1.5, 0.5, 79), (2, 1, 76), (3, 1, 72),
    (4, 3, 76), (7, 1, 74),
    (8, 1.5, 77), (9.5, 0.5, 76), (10, 1, 72), (11, 1, 69),
    (12, 4, 72),
    (16, 1.5, 79), (17.5, 0.5, 76), (18, 1, 72), (19, 1, 76),
    (20, 3, 74), (23, 1, 72),
    (24, 1, 71), (25, 1, 74), (26, 1, 79), (27, 1, 83),
    (28, 4, 81),
]


def make_run():
    tr = Track(bpm=112, bars=24)
    for bar in range(tr.bars):
        b0 = bar * 4
        root, notes = CHORDS[(bar // 2) % 4]
        section = bar // 8          # 0 = build, 1 = hook, 2 = answer
        # drums
        for q in range(4):
            tr.kick(b0 + q, 0.95)
            tr.hat(b0 + q + 0.5, 0.9, open_=(q % 2 == 1))
            if section > 0:
                tr.hat(b0 + q + 0.25, 0.45)
                tr.hat(b0 + q + 0.75, 0.45)
        tr.snare(b0 + 1, 1.0 if section > 0 else 0.75)
        tr.snare(b0 + 3, 1.0 if section > 0 else 0.75)
        if section > 0:
            tr.clap(b0 + 1)
            tr.clap(b0 + 3)
        if bar % 8 == 7:
            tr.snare(b0 + 3.5, 0.6)
            tr.snare(b0 + 3.75, 0.7)
        # bass: driving octave eighths
        for e in range(8):
            m = root if e % 2 == 0 else root + 12
            tr.bass(b0 + e * 0.5, 0.45, m, 1.0 if e % 2 == 0 else 0.8)
        # pad
        if bar % 2 == 0:
            tr.pad(b0, 8, notes + [notes[0] + 12], 0.9 if section == 0 else 1.0, bright=1500 if section == 0 else 2300)
        # arp: 16ths over the chord, two octaves
        seq = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[0] + 24, notes[2] + 12, notes[1] + 12]
        for s in range(16):
            tr.arp_note(b0 + s * 0.25, seq[(bar * 16 + s) % len(seq)], 0.9 if s % 4 == 0 else 0.65, pan=-0.35 if s % 2 else 0.35)
        if bar == 7 or bar == 15 or bar == 23:
            tr.riser(b0, 4)
    for bt, ln, m in HOOK:
        tr.lead_note(8 * 4 + bt, ln, m)
    for bt, ln, m in HOOK_B:
        tr.lead_note(16 * 4 + bt, ln, m, 0.95)
    return tr.render(duck=0.6)


def make_menu():
    tr = Track(bpm=90, bars=16)
    for bar in range(tr.bars):
        b0 = bar * 4
        root, notes = CHORDS[(bar // 2) % 4]
        tr.kick(b0, 0.7)
        tr.kick(b0 + 2.5, 0.45)
        tr.snare(b0 + 2, 0.45)
        for q in range(4):
            tr.hat(b0 + q + 0.5, 0.5)
        tr.bass(b0, 1.5, root, 0.9)
        tr.bass(b0 + 2, 1.0, root, 0.7)
        tr.bass(b0 + 3.5, 0.45, root + 12, 0.6)
        if bar % 2 == 0:
            tr.pad(b0, 8, notes + [notes[1] + 12], 1.1, bright=1300)
        seq = [notes[0] + 12, notes[2] + 12, notes[1] + 24, notes[2] + 12]
        for s in range(8):
            tr.arp_note(b0 + s * 0.5, seq[(bar * 8 + s) % 4], 0.6, pan=-0.4 if s % 2 else 0.4, length=0.35)
    for bt, ln, m in HOOK:
        tr.lead_note(8 * 4 + bt, ln, m, 0.55)
    return tr.render(duck=0.35)


# ---------------------------------------------------------------- seasonal

HALLOWEEN_CHORDS = [(50, [62, 65, 69]), (46, [62, 65, 70]), (43, [62, 67, 70]), (45, [61, 64, 69])]
HALLOWEEN_TUNE = [
    (0, 1, 74), (1, 1, 77), (2, 1.5, 81), (3.5, 0.5, 80), (4, 2, 81), (6, 1, 79), (7, 1, 77),
    (8, 1, 74), (9, 1, 77), (10, 1.5, 82), (11.5, 0.5, 81), (12, 3, 77), (15, 1, 76),
    (16, 1, 74), (17, 1, 79), (18, 1.5, 82), (19.5, 0.5, 81), (20, 2, 79), (22, 1, 77), (23, 1, 76),
    (24, 1, 73), (25, 1, 76), (26, 1, 79), (27, 1, 81), (28, 4, 81),
]


def make_halloween():
    """Spooky synthwave: organ, bells, harmonic minor (D minor)."""
    tr = Track(bpm=104, bars=16)
    for bar in range(tr.bars):
        b0 = bar * 4
        root, notes = HALLOWEEN_CHORDS[(bar // 2) % 4]
        for q in range(4):
            tr.kick(b0 + q, 0.9)
            tr.hat(b0 + q + 0.5, 0.7)
        tr.snare(b0 + 1, 0.85)
        tr.snare(b0 + 3, 0.85)
        if bar % 4 == 3:
            tr.snare(b0 + 3.5, 0.5)
        for e in range(8):
            tr.bass(b0 + e * 0.5, 0.45, root if e % 4 != 3 else root + 7, 0.9)
        if bar % 2 == 0:
            tr.organ(b0, 8, notes, 0.9)
        seq = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[1] + 12]
        for s in range(8):
            tr.arp_note(b0 + s * 0.5, seq[(bar * 8 + s) % 4], 0.6, pan=-0.4 if s % 2 else 0.4, length=0.3)
    for rep in range(2):
        for bt, ln, m in HALLOWEEN_TUNE:
            tr.bell(rep * 32 + bt, m, 0.9 if rep == 0 else 1.0, decay=0.6 + ln * 0.3)
    return tr.render(duck=0.45)


# "Jingle Bells" (James Lord Pierpont, 1857 - public domain), chorus in C major
JINGLE = [
    (0, 1, 76), (1, 1, 76), (2, 2, 76), (4, 1, 76), (5, 1, 76), (6, 2, 76),
    (8, 1, 76), (9, 1, 79), (10, 1.5, 72), (11.5, 0.5, 74), (12, 4, 76),
    (16, 1, 77), (17, 1, 77), (18, 1.5, 77), (19.5, 0.5, 77), (20, 1, 77), (21, 1, 76), (22, 1, 76), (23, 0.5, 76), (23.5, 0.5, 76),
    (24, 1, 76), (25, 1, 74), (26, 1, 74), (27, 1, 76), (28, 2, 74), (30, 2, 79),
    (32, 1, 76), (33, 1, 76), (34, 2, 76), (36, 1, 76), (37, 1, 76), (38, 2, 76),
    (40, 1, 76), (41, 1, 79), (42, 1.5, 72), (43.5, 0.5, 74), (44, 4, 76),
    (48, 1, 77), (49, 1, 77), (50, 1.5, 77), (51.5, 0.5, 77), (52, 1, 77), (53, 1, 76), (54, 1, 76), (55, 0.5, 76), (55.5, 0.5, 76),
    (56, 1, 79), (57, 1, 79), (58, 1, 77), (59, 1, 74), (60, 4, 72),
]
JINGLE_CHORDS = [48, 48, 48, 48, 41, 48, 50, 43, 48, 48, 48, 48, 41, 48, 43, 48]


def triad(root):
    """Major triad two octaves above the bass root."""
    return [root + 24, root + 28, root + 31]


def make_christmas():
    """Festive synthwave: sleigh bells, glockenspiel melody, bright pads (C major)."""
    tr = Track(bpm=124, bars=16)
    for bar in range(tr.bars):
        b0 = bar * 4
        root = JINGLE_CHORDS[bar]
        notes = triad(root)
        for q in range(4):
            tr.kick(b0 + q, 0.85)
            tr.hat(b0 + q + 0.5, 0.6, open_=True)
        tr.clap(b0 + 1)
        tr.clap(b0 + 3)
        for s in range(16):
            tr.sleigh(b0 + s * 0.25, 1.0 if s % 4 == 2 else 0.55)
        for e in range(8):
            tr.bass(b0 + e * 0.5, 0.45, root - 12 if e % 2 == 0 else root, 0.9)
        tr.pad(b0, 4, [n - 12 for n in notes], 0.8, bright=2600)
        for s in range(8):
            tr.arp_note(b0 + s * 0.5, notes[s % 3], 0.45, pan=-0.4 if s % 2 else 0.4, length=0.25)
    for bt, ln, m in JINGLE:
        tr.bell(bt, m + 12, 1.1, decay=0.5 + ln * 0.25)
        tr.lead_note(bt, ln * 0.9, m, 0.45)
    return tr.render(duck=0.4)


if __name__ == "__main__":
    import sys
    which = sys.argv[1:] or ["run", "menu", "halloween", "christmas"]
    makers = {"run": make_run, "menu": make_menu, "halloween": make_halloween, "christmas": make_christmas}
    for w in which:
        write_ogg(makers[w](), w)
