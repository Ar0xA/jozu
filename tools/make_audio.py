"""Builds Jozu's synthesised music and sound effects into audio/.

    python tools/make_audio.py

Koto and shamisen are Karplus-Strong plucked strings; taiko is a pitched thump with a
noise attack. Music is written in the miyako-bushi (In) scale. Needs numpy.
"""
import os, wave
import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1185)

NOTE = {'C': -9, 'C#': -8, 'Db': -8, 'D': -7, 'Eb': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'Ab': -1, 'A': 0, 'Bb': 1, 'B': 2}

def hz(name):
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[n] + (o - 4) * 12) / 12.0)

def pluck(f, dur, bright=0.5, decay=0.996, amp=1.0):
    """Karplus-Strong string. bright 0..1 sets how hard the pick is."""
    n = max(2, int(round(SR / f)))
    buf = rng.uniform(-1, 1, n)
    # soften the excitation: a duller pick has less high content
    k = int(1 + (1 - bright) * 6)
    buf = np.convolve(np.concatenate([buf, buf[:k]]), np.ones(k) / k, 'valid')[:n]
    buf -= buf.mean()
    periods = int(dur * SR / n) + 1
    out = np.empty(periods * n)
    for i in range(periods):
        out[i * n:(i + 1) * n] = buf
        buf = decay * 0.5 * (buf + np.roll(buf, 1))
    out = out[:int(dur * SR)]
    out[:40] *= np.linspace(0, 1, 40)
    out[-200:] *= np.linspace(1, 0, 200)
    return out * amp

def taiko(dur=0.7, f0=95.0, f1=48.0, amp=1.0):
    t = np.arange(int(dur * SR)) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.5)
    click = rng.uniform(-1, 1, len(t)) * np.exp(-t * 90) * 0.5
    return (body + click) * amp

def rim(dur=0.12, amp=1.0):
    """Stick on the rim of the drum / wooden clappers."""
    t = np.arange(int(dur * SR)) / SR
    return (np.sin(2 * np.pi * 1450 * t) + 0.6 * np.sin(2 * np.pi * 2300 * t)) * np.exp(-t * 60) * amp

def flute(f, dur, amp=1.0):
    """A breathy shakuhachi-like tone that scoops up into the note."""
    t = np.arange(int(dur * SR)) / SR
    bend = 1 - 0.05 * np.exp(-t * 9)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.6, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * bend * vib) / SR
    tone = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.10 * np.sin(3 * ph)
    breath = np.convolve(rng.uniform(-1, 1, len(t)), np.ones(24) / 24, 'same') * 1.6
    env = np.clip(t / 0.18, 0, 1) * np.clip((dur - t) / 0.35, 0, 1)
    return (tone * 0.8 + breath * (0.35 + 0.5 * np.exp(-t * 6))) * env * amp

def bell(f, dur, amp=1.0):
    t = np.arange(int(dur * SR)) / SR
    out = sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-t * d) for m, a, d in
              [(1.0, 1.0, 2.2), (2.76, 0.5, 3.5), (5.4, 0.25, 6.0), (8.9, 0.12, 9.0)])
    return out * amp

def swish(dur, f_lo, f_hi, amp=1.0, rise=True):
    """Band of noise sweeping in pitch: a brush or a blade through air."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    f = np.linspace(f_lo, f_hi, n) if rise else np.linspace(f_hi, f_lo, n)
    out = np.zeros(n)
    lp = bp = 0.0
    q = 0.35
    for i in range(n):          # state-variable band-pass, swept
        w = 2 * np.sin(np.pi * min(f[i], SR / 6.5) / SR)
        hp = noise[i] - lp - q * bp
        bp += w * hp
        lp += w * bp
        out[i] = bp
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return out * env * amp

class Mix:
    def __init__(self, seconds):
        self.a = np.zeros(int(seconds * SR) + SR)
    def add(self, t, snd):
        i = int(t * SR)
        if i >= len(self.a):
            return
        snd = snd[:len(self.a) - i]
        self.a[i:i + len(snd)] += snd
    def save(self, name, seconds=None, peak=0.85):
        a = self.a if seconds is None else self.a[:int(seconds * SR)]
        # a little room: two short echoes
        for d, g in ((0.11, 0.22), (0.23, 0.12)):
            k = int(d * SR)
            a[k:] += a[:-k] * g
        a = a / max(1e-9, np.abs(a).max()) * peak
        if len(a) > 20 * SR:
            # music: Ogg Vorbis, about a seventh the size of the same thing as a WAV
            import soundfile as sf
            with sf.SoundFile(os.path.join(OUT, name + '.ogg'), 'w', samplerate=SR, channels=1, format='OGG', subtype='VORBIS') as f:
                for i in range(0, len(a), SR):   # a second at a time: libsndfile can fail on one very long write
                    f.write(a[i:i + SR].astype('float32'))
            print('%-10s %5.1fs' % (name, len(a) / SR))
            return
        with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((a * 32767).astype('<i2').tobytes())
        print('%-10s %5.1fs' % (name, len(a) / SR))

# ------------------------------------------------------------------ Sakura Sakura (traditional)
def sakura():
    beat = 0.62
    # (note, beats)
    A = [('A4', 1), ('A4', 1), ('B4', 2), ('A4', 1), ('A4', 1), ('B4', 2)]
    B = [('A4', 1), ('B4', 1), ('C5', 1), ('B4', 1), ('A4', 1), ('B4', .5), ('A4', .5), ('F4', 2)]
    C = [('E4', 1), ('C4', 1), ('E4', 1), ('F4', 1), ('E4', 1), ('E4', .5), ('C4', .5), ('B3', 2)]
    D = [('E4', 1), ('F4', 1), ('B4', .5), ('A4', .5), ('F4', 1), ('E4', 4)]
    tune = A + B + C + B + C + A + D
    total = sum(b for _, b in tune) * beat
    m = Mix(total * 2 + 6)
    for rep in range(2):
        t = rep * (total + 2.4)
        bt = 0.0
        for i, (nt, b) in enumerate(tune):
            f = hz(nt)
            m.add(t, pluck(f, min(3.2, b * beat + 1.6), bright=0.55, amp=0.9))
            if rep == 1 and b >= 1:          # second time: octave answer under the tune
                m.add(t + beat * 0.5, pluck(f / 2, 2.4, bright=0.3, amp=0.42))
            if abs(bt % 4) < 1e-6:           # a low string on each bar line
                bass = {'A': 'A2', 'B': 'E2', 'C': 'A2', 'E': 'E2', 'F': 'F2'}[nt[0]]
                m.add(t, pluck(hz(bass), 3.5, bright=0.25, amp=0.5))
            t += b * beat
            bt += b
        # a falling sweep across the strings to close the verse
        for k, nt in enumerate(['E5', 'C5', 'B4', 'A4', 'F4', 'E4', 'C4', 'B3', 'A3']):
            m.add(t + 0.2 + k * 0.07, pluck(hz(nt), 2.6, bright=0.5, amp=0.38))
    m.save('title', total * 2 + 6.5)

# ------------------------------------------------------------------ original pieces in the In scale
IN_D = ['D', 'Eb', 'G', 'A', 'Bb']

def scale(root_oct, octaves=2):
    out = []
    for o in range(root_oct, root_oct + octaves):
        for n in IN_D:
            out.append(n + str(o))
    out.append('D' + str(root_oct + octaves))
    return out

def piece(name, bpm, bars, seed, drive):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    sc = scale(4)
    m = Mix(bars * 4 * beat + 5)
    deg = 5
    for bar in range(bars):
        t0 = bar * 4 * beat
        sect = (bar // 8) % 3
        # drum: sparse and patient, or insistent
        if drive:
            for b in (0, 1, 2, 3):
                m.add(t0 + b * beat, taiko(amp=0.75 if b in (0, 2) else 0.45))
            if bar % 2 == 1:
                m.add(t0 + 3.5 * beat, taiko(0.4, 120, 70, 0.5))
            if bar % 4 == 3:
                for k in range(4):
                    m.add(t0 + (3 + k * 0.25) * beat, rim(amp=0.3))
        else:
            m.add(t0, taiko(amp=0.5))
            if bar % 2 == 1:
                m.add(t0 + 2.5 * beat, taiko(0.5, 110, 60, 0.3))
            if bar % 4 == 3:
                m.add(t0 + 3 * beat, rim(amp=0.25))
        # drone string
        m.add(t0, pluck(hz('D2' if bar % 4 < 2 else 'A2'), 3.8, bright=0.2, amp=0.5))
        if sect == 2 and not drive:
            # a breath: the flute holds one long tone over the drum
            if bar % 4 == 0:
                m.add(t0 + beat, flute(hz(r.choice(['D5', 'A4', 'G4'])), beat * 9, amp=0.28))
            continue
        # melody: a wandering line that leans on D and A, in short phrases with rests
        steps = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5] if drive else [0, 1, 1.5, 2, 3, 3.5]
        for s in steps:
            if r.random() < (0.22 if drive else 0.30):
                continue
            deg = int(np.clip(deg + r.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(sc) - 1))
            if s == 0 and r.random() < 0.5:
                deg = r.choice([0, 3, 5, 8])
            f = hz(sc[deg])
            if drive:        # shamisen: short, bright, percussive
                m.add(t0 + s * beat, pluck(f, 0.9, bright=0.95, decay=0.985, amp=0.6))
            else:            # koto: long and ringing
                m.add(t0 + s * beat, pluck(f, 2.6, bright=0.55, amp=0.6))
        if bar % 8 == 7:     # string sweep into the next section
            run = sc[::-1] if r.random() < 0.5 else sc
            for k, nt in enumerate(run[:9]):
                m.add(t0 + 3 * beat + k * 0.05, pluck(hz(nt), 2.0, bright=0.6, amp=0.3))
    m.save(name, bars * 4 * beat)

# ------------------------------------------------------------------ sound effects
def sfx():
    def one(name, parts, length):
        m = Mix(length)
        for t, s in parts:
            m.add(t, s)
        m.save(name, length, peak=0.8)
    one('step', [(0, swish(0.16, 900, 2600, 0.9)), (0.02, pluck(hz('D3'), 0.25, 0.2, 0.97, 0.25))], 0.3)
    one('cut', [(0, swish(0.22, 1800, 6500, 1.0)), (0.10, rim(0.1, 0.5))], 0.4)
    one('kill', [(0, swish(0.25, 1500, 6000, 0.7)), (0.08, bell(hz('A5'), 1.6, 0.5)), (0.08, bell(hz('D5'), 1.6, 0.35))], 1.7)
    one('hit', [(0, taiko(0.6, 140, 45, 1.0)), (0, swish(0.2, 300, 900, 0.5, False))], 0.7)
    one('ward', [(0, rim(0.14, 1.0)), (0.16, rim(0.14, 0.8))], 0.45)
    one('leap', [(0, swish(0.3, 500, 4200, 0.9)), (0.24, pluck(hz('A4'), 0.5, 0.7, 0.99, 0.3))], 0.8)
    one('katsu', [(0, taiko(1.0, 150, 40, 1.0)), (0.0, swish(0.45, 400, 1800, 0.8)), (0.12, taiko(0.8, 100, 38, 0.7))], 1.2)
    one('sheathe', [(0, swish(0.14, 2600, 900, 0.5, False)), (0.12, rim(0.07, 0.45))], 0.3)
    one('click', [(0, rim(0.08, 0.6))], 0.12)
    one('win', [(k * 0.13, pluck(hz(n), 2.4, 0.6, 0.996, 0.6)) for k, n in enumerate(['D4', 'G4', 'A4', 'D5', 'G5', 'A5', 'D6'])] + [(0, taiko(0.8, 100, 50, 0.5))], 3.2)
    # a temple bell: low, struck once, and a long time dying away
    one('bell', [(0, taiko(0.25, 130, 95, 0.45)), (0, bell(hz('D3'), 3.4, 0.9)), (0.01, bell(hz('A2'), 3.4, 0.55))], 3.6)
    one('lose', [(0, taiko(1.4, 80, 36, 0.9)), (0.25, pluck(hz('Eb3'), 2.5, 0.3, 0.996, 0.6)), (0.7, pluck(hz('D3'), 3.0, 0.3, 0.996, 0.6))], 3.4)

sakura()
piece('battle', 84, 48, 7, False)
piece('boss', 128, 48, 11, True)
sfx()

def late_sfx():
    """Sounds added after the first set; made last so the earlier files come out unchanged."""
    def one(name, parts, length):
        m = Mix(length)
        for t, s in parts:
            m.add(t, s)
        m.save(name, length, peak=0.8)
    # a yokai eating: two soft knocks of a wooden bowl
    one('eat', [(0, rim(0.09, 0.5)), (0.11, pluck(hz('G2'), 0.3, 0.15, 0.96, 0.4)), (0.24, rim(0.08, 0.4)), (0.33, pluck(hz('E2'), 0.3, 0.15, 0.96, 0.35))], 0.7)
    # planks into the river
    one('splash', [(0, rim(0.12, 0.8)), (0.05, taiko(0.5, 90, 40, 0.7)), (0.06, swish(0.55, 3800, 500, 0.9, False)), (0.3, swish(0.5, 1500, 300, 0.4, False))], 1.0)
    # caught in a web: a string pulled tight
    one('web', [(0, pluck(hz('E5'), 0.5, 0.9, 0.985, 0.5)), (0.05, pluck(hz('F5'), 0.5, 0.9, 0.985, 0.4)), (0.02, swish(0.18, 5000, 2500, 0.25, False))], 0.6)
    # the sickle weasel: a quick rising wind and a blade
    one('kama', [(0, swish(0.22, 700, 5200, 0.8)), (0.16, swish(0.1, 6000, 3000, 0.5, False)), (0.2, rim(0.05, 0.3))], 0.4)
    # a tile of the character painted: one wet touch of the brush
    one('ink', [(0, swish(0.2, 500, 1400, 0.6)), (0.03, pluck(hz('A3'), 0.3, 0.1, 0.96, 0.2))], 0.3)

def clappers():
    """Hyoshigi: the two blocks of hard wood struck together to open and close a scene."""
    def clack(amp):
        t = np.arange(int(0.16 * SR)) / SR
        wood = np.sin(2 * np.pi * 1650 * t) * np.exp(-t * 55) + 0.6 * np.sin(2 * np.pi * 2480 * t) * np.exp(-t * 70) + 0.35 * np.sin(2 * np.pi * 3900 * t) * np.exp(-t * 95)
        crack = np.random.default_rng(7).standard_normal(len(t)) * np.exp(-t * 320)
        return (wood + 0.7 * crack) * amp
    for name, hits, length in (('ki', [(0, 0.9)], 0.3), ('ki2', [(0, 0.7), (0.24, 1.0)], 0.55)):
        m = Mix(length)
        for at, amp in hits:
            m.add(at, clack(amp))
        m.save(name, length, peak=0.7)

late_sfx()
clappers()

# ------------------------------------------------------------------ more music for the road
# Made after everything above, so the earlier files come out exactly as before.
def zen(name, bars, seed):
    """For the kōan, the garden, the circle and the written character: no drum, a great deal of
    silence, a few koto notes left to ring, a long breath on the flute, and now and then a bell."""
    r = np.random.default_rng(seed)
    beat = 60.0 / 52
    sc = scale(3, 3)
    m = Mix(bars * 4 * beat + 8)
    deg = 7
    for bar in range(bars):
        t0 = bar * 4 * beat
        if bar % 8 == 0:
            m.add(t0, bell(hz('D3'), 6.0, 0.30))
            m.add(t0, pluck(hz('D2'), 6.0, bright=0.15, amp=0.45))
        if bar % 4 == 2:
            m.add(t0 + beat * 0.5, flute(hz(r.choice(['D4', 'A4', 'G4', 'D5'])), beat * 7, amp=0.24))
        if bar % 8 == 7:
            continue                       # a whole bar of nothing
        for s in (0, 1.5, 3):
            if r.random() < 0.52:
                continue
            deg = int(np.clip(deg + r.choice([-3, -2, -1, 1, 2, 3]), 0, len(sc) - 1))
            m.add(t0 + s * beat, pluck(hz(sc[deg]), 5.0, bright=0.45, decay=0.9975, amp=0.55))
            if r.random() < 0.3:           # the octave answered softly, as the left hand does on a koto
                m.add(t0 + (s + 0.5) * beat, pluck(hz(sc[max(0, deg - 5)]), 4.0, bright=0.3, decay=0.9975, amp=0.28))
    m.save(name, bars * 4 * beat)

def late_music():
    piece('road2', 92, 24, 21, False)      # a brisker koto for the middle of the road
    piece('road3', 74, 20, 33, False)      # a slower one, with more flute
    piece('boss2', 120, 28, 44, True)      # shamisen and drum for the later endings
    zen('zen', 28, 5)

late_music()

def brush_sound():
    """Hair on paper: a soft, short hush. The game plays it lower and longer as a stroke runs on."""
    n = int(0.30 * SR)
    t = np.arange(n) / SR
    hush = np.random.default_rng(11).standard_normal(n)
    # soften it: a running mean takes the hiss off the top
    k = 9
    hush = np.convolve(hush, np.ones(k) / k, mode='same')
    env = np.clip(t / 0.03, 0, 1) * np.exp(-t * 9.0)
    m = Mix(0.4)
    m.add(0, hush * env * 0.9)
    m.save('brush', 0.34, peak=0.45)

brush_sound()
