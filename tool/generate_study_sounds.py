from pathlib import Path
import wave

import numpy as np


SAMPLE_RATE = 48000
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "sounds"
RNG = np.random.default_rng(20260829)


def timeline(seconds: float) -> np.ndarray:
    return np.arange(round(SAMPLE_RATE * seconds), dtype=np.float64) / SAMPLE_RATE


def modal_chime(t, start, frequency, decay, level=1.0):
    x = t - start
    active = x >= 0
    x = np.maximum(x, 0)
    attack = np.minimum(x / 0.006, 1.0)
    envelope = attack * np.exp(-x / decay) * active
    ratios = (1.0, 2.01, 2.997, 4.13, 5.43)
    weights = (1.0, 0.27, 0.13, 0.055, 0.025)
    phases = (0.0, 0.31, 0.67, 1.02, 1.39)
    signal = sum(
        weight * np.sin(2 * np.pi * frequency * ratio * x + phase)
        for ratio, weight, phase in zip(ratios, weights, phases)
    )
    return signal * envelope * level


def soft_mallet(t, start, frequency, decay, level=1.0):
    x = t - start
    active = x >= 0
    x = np.maximum(x, 0)
    attack = np.minimum(x / 0.0035, 1.0)
    envelope = attack * np.exp(-x / decay) * active
    body = np.sin(2 * np.pi * frequency * x)
    warmth = 0.19 * np.sin(2 * np.pi * frequency * 2.73 * x + 0.42)
    return (body + warmth) * envelope * level


def filtered_air(length):
    noise = RNG.normal(0, 1, length)
    kernel = np.hanning(41)
    kernel /= kernel.sum()
    return np.convolve(noise, kernel, mode="same")


def add_room(signal, taps):
    output = signal.copy()
    for delay_seconds, gain in taps:
        delay = round(delay_seconds * SAMPLE_RATE)
        if delay < len(signal):
            output[delay:] += signal[:-delay] * gain
    return output


def stereo_master(mono, room=0.12):
    left = add_room(mono, ((0.019, room), (0.047, room * 0.48), (0.083, room * 0.23)))
    right = add_room(mono, ((0.027, room * 1.05), (0.059, room * 0.43), (0.097, room * 0.20)))
    stereo = np.column_stack((left, right))
    stereo -= np.mean(stereo, axis=0, keepdims=True)

    fade_in = min(round(0.002 * SAMPLE_RATE), len(stereo))
    fade_out = min(round(0.045 * SAMPLE_RATE), len(stereo))
    stereo[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    stereo[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]

    stereo = np.tanh(stereo * 1.08)
    peak = np.max(np.abs(stereo))
    if peak > 0:
        stereo *= 0.82 / peak
    dither = RNG.uniform(-1 / 65536, 1 / 65536, stereo.shape)
    return np.clip(stereo + dither, -1, 1)


def correct_sound():
    t = timeline(0.78)
    sound = (
        modal_chime(t, 0.000, 587.33, 0.31, 0.56)
        + modal_chime(t, 0.092, 739.99, 0.39, 0.62)
        + modal_chime(t, 0.184, 880.00, 0.36, 0.42)
    )
    return stereo_master(sound, room=0.14)


def incorrect_sound():
    t = timeline(0.58)
    sound = (
        soft_mallet(t, 0.000, 293.66, 0.20, 0.58)
        + soft_mallet(t, 0.135, 246.94, 0.25, 0.62)
    )
    return stereo_master(sound, room=0.075)


def known_swipe_sound():
    t = timeline(0.46)
    position = np.clip(t / t[-1], 0, 1)
    air = filtered_air(len(t)) * np.sin(np.pi * position) ** 1.8 * 0.19
    sound = (
        air
        + modal_chime(t, 0.070, 523.25, 0.22, 0.34)
        + modal_chime(t, 0.155, 659.25, 0.24, 0.40)
    )
    return stereo_master(sound, room=0.095)


def unknown_swipe_sound():
    t = timeline(0.48)
    position = np.clip(t / t[-1], 0, 1)
    air = filtered_air(len(t)) * np.sin(np.pi * position) ** 1.8 * 0.13
    sound = (
        air
        + soft_mallet(t, 0.070, 329.63, 0.19, 0.38)
        + soft_mallet(t, 0.175, 261.63, 0.23, 0.43)
    )
    return stereo_master(sound, room=0.075)


def write_wave(path: Path, audio: np.ndarray):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(audio * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def main():
    sounds = {
        "study_correct.wav": correct_sound(),
        "study_incorrect.wav": incorrect_sound(),
        "study_known_swipe.wav": known_swipe_sound(),
        "study_unknown_swipe.wav": unknown_swipe_sound(),
    }
    for name, audio in sounds.items():
        write_wave(OUTPUT_DIR / name, audio)
        print(f"generated {name}")


if __name__ == "__main__":
    main()
