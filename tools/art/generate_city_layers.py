"""Original CC0 synthesized city beds; no downloaded or third-party samples."""
import math, random, wave, array
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2] / 'assets/meatspace/audio'
RATE, SECONDS = 11025, 60
for kind in ['rooftop_wind', 'distant_traffic', 'night_electric']:
    rng = random.Random(726)
    low = 0.0
    samples = array.array('h')
    for i in range(RATE * SECONDS):
        t = i / RATE
        low += 0.035 * (rng.uniform(-1, 1) - low)
        swell = 0.65 + 0.3 * math.sin(math.tau * t / 20)
        value = low * swell
        if kind == 'rooftop_wind': value += 0.015 * math.sin(math.tau * 173 * t) * swell
        if kind == 'distant_traffic':
            value += 0.07 * math.sin(math.tau * 73 * t) * (0.5 + 0.5 * math.sin(math.tau * t / 15))**4
            value += 0.035 * (math.sin(math.tau * 349 * t) + math.sin(math.tau * 440 * t)) * max(0, math.sin(math.tau * (t-7) / 30))**60
        if kind == 'night_electric': value = low * 0.25 + 0.05 * math.sin(math.tau * 60 * t) + 0.015 * math.sin(math.tau * 120 * t) * swell
        fade = min(1, t / 2, (SECONDS-t) / 2)
        samples.append(int(max(-1, min(1, value * fade)) * 24000))
    with wave.open(str(ROOT / (kind + '.wav')), 'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE); out.writeframes(samples.tobytes())
