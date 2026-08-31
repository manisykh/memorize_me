from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import soundfile as sf


SOURCES = {
    "study_correct.wav": "정답.mp3",
    "study_incorrect.wav": "오답.mp3",
    "study_known_swipe.wav": "오른쪽 스와이프.mp3",
    "study_unknown_swipe.wav": "왼쪽 스와이프.mp3",
}

TARGET_SAMPLE_RATE = 48_000
TARGET_RMS_DBFS = -18.0
PEAK_LIMIT_DBFS = -1.0
ONSET_THRESHOLD_DB = -42.0
PREROLL_SECONDS = 0.018
TAIL_SECONDS = 0.080
FADE_SECONDS = 0.012


def db(value: float) -> float:
    return 20.0 * math.log10(max(value, 1e-12))


def load_mono(path: Path) -> tuple[np.ndarray, int]:
    audio, sample_rate = sf.read(path, always_2d=True, dtype="float64")
    return np.mean(audio, axis=1), sample_rate


def resample_linear(audio: np.ndarray, source_rate: int) -> np.ndarray:
    if source_rate == TARGET_SAMPLE_RATE:
        return audio
    output_length = max(1, round(len(audio) * TARGET_SAMPLE_RATE / source_rate))
    source_positions = np.linspace(0.0, 1.0, len(audio), endpoint=False)
    output_positions = np.linspace(0.0, 1.0, output_length, endpoint=False)
    return np.interp(output_positions, source_positions, audio)


def active_bounds(audio: np.ndarray, sample_rate: int) -> tuple[int, int]:
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    if peak <= 1e-12:
        return 0, len(audio)
    threshold = peak * (10.0 ** (ONSET_THRESHOLD_DB / 20.0))
    window_size = max(1, round(sample_rate * 0.006))
    envelope = np.convolve(
        np.abs(audio),
        np.ones(window_size, dtype=np.float64) / window_size,
        mode="same",
    )
    active = np.flatnonzero(envelope >= threshold)
    if active.size == 0:
        return 0, len(audio)
    return int(active[0]), int(active[-1] + 1)


def rms(audio: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(audio)))) if audio.size else 0.0


def describe(name: str, audio: np.ndarray, sample_rate: int) -> None:
    start, end = active_bounds(audio, sample_rate)
    active = audio[start:end]
    print(
        f"{name}: rate={sample_rate}, duration={len(audio) / sample_rate:.3f}s, "
        f"onset={start / sample_rate:.3f}s, active_end={end / sample_rate:.3f}s, "
        f"active={len(active) / sample_rate:.3f}s, "
        f"rms={db(rms(active)):.2f}dBFS, peak={db(float(np.max(np.abs(active)))):.2f}dBFS"
    )


def process(source_dir: Path, output_dir: Path) -> None:
    prepared: dict[str, np.ndarray] = {}
    print("Source analysis")
    for output_name, source_name in SOURCES.items():
        source_path = source_dir / source_name
        audio, sample_rate = load_mono(source_path)
        describe(source_name, audio, sample_rate)
        audio = resample_linear(audio, sample_rate)
        start, end = active_bounds(audio, TARGET_SAMPLE_RATE)
        preroll = round(PREROLL_SECONDS * TARGET_SAMPLE_RATE)
        tail = round(TAIL_SECONDS * TARGET_SAMPLE_RATE)
        start = max(0, start - preroll)
        end = min(len(audio), end + tail)
        prepared[output_name] = audio[start:end].copy()

    common_samples = max(len(audio) for audio in prepared.values())
    fade_samples = round(FADE_SECONDS * TARGET_SAMPLE_RATE)
    target_rms = 10.0 ** (TARGET_RMS_DBFS / 20.0)
    peak_limit = 10.0 ** (PEAK_LIMIT_DBFS / 20.0)

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"\nOutput: duration={common_samples / TARGET_SAMPLE_RATE:.3f}s")
    for output_name, audio in prepared.items():
        if fade_samples > 0 and len(audio) >= fade_samples * 2:
            audio[:fade_samples] *= np.linspace(0.0, 1.0, fade_samples)
            audio[-fade_samples:] *= np.linspace(1.0, 0.0, fade_samples)

        active_start, active_end = active_bounds(audio, TARGET_SAMPLE_RATE)
        current_rms = rms(audio[active_start:active_end])
        gain = target_rms / current_rms if current_rms > 1e-12 else 1.0
        peak = float(np.max(np.abs(audio))) if audio.size else 0.0
        if peak * gain > peak_limit:
            gain = peak_limit / peak
        audio *= gain

        padded = np.zeros(common_samples, dtype=np.float64)
        padded[: len(audio)] = audio
        output_path = output_dir / output_name
        sf.write(output_path, padded, TARGET_SAMPLE_RATE, subtype="PCM_16")
        describe(output_name, padded, TARGET_SAMPLE_RATE)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    process(args.source_dir, args.output_dir)


if __name__ == "__main__":
    main()
