from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import soundfile as sf

from normalize_study_sounds import active_bounds, load_mono, resample_linear, rms


TARGET_SAMPLE_RATE = 48_000
TARGET_RMS_DBFS = -17.0
PEAK_LIMIT_DBFS = -1.0
ONSET_SECONDS = 0.018
FADE_IN_SECONDS = 0.010
FADE_OUT_SECONDS = 0.120


def replace(source_path: Path, output_path: Path) -> None:
    existing, existing_rate = load_mono(output_path)
    if existing_rate != TARGET_SAMPLE_RATE:
        raise ValueError(f"Expected a {TARGET_SAMPLE_RATE} Hz target: {output_path}")

    source, source_rate = load_mono(source_path)
    source = resample_linear(source, source_rate)
    active_start, active_end = active_bounds(source, TARGET_SAMPLE_RATE)
    source = source[active_start:active_end].copy()

    onset_samples = round(ONSET_SECONDS * TARGET_SAMPLE_RATE)
    available_samples = len(existing) - onset_samples
    source = source[:available_samples]

    fade_in_samples = min(round(FADE_IN_SECONDS * TARGET_SAMPLE_RATE), len(source))
    if fade_in_samples > 0:
        source[:fade_in_samples] *= np.linspace(0.0, 1.0, fade_in_samples)

    if len(source) == available_samples:
        fade_out_samples = min(round(FADE_OUT_SECONDS * TARGET_SAMPLE_RATE), len(source))
    else:
        fade_out_samples = min(round(0.012 * TARGET_SAMPLE_RATE), len(source))
    if fade_out_samples > 0:
        source[-fade_out_samples:] *= np.linspace(1.0, 0.0, fade_out_samples)

    current_rms = rms(source)
    target_rms = 10.0 ** (TARGET_RMS_DBFS / 20.0)
    gain = target_rms / current_rms if current_rms > 1e-12 else 1.0
    peak = float(np.max(np.abs(source))) if source.size else 0.0
    peak_limit = 10.0 ** (PEAK_LIMIT_DBFS / 20.0)
    if peak * gain > peak_limit:
        gain = peak_limit / peak
    source *= gain

    output = np.zeros(len(existing), dtype=np.float64)
    output[onset_samples : onset_samples + len(source)] = source
    sf.write(output_path, output, TARGET_SAMPLE_RATE, subtype="PCM_16")

    active_start, active_end = active_bounds(output, TARGET_SAMPLE_RATE)
    active = output[active_start:active_end]
    active_rms_db = 20.0 * math.log10(max(rms(active), 1e-12))
    peak_db = 20.0 * math.log10(max(float(np.max(np.abs(active))), 1e-12))
    print(
        f"{output_path.name}: duration={len(output) / TARGET_SAMPLE_RATE:.3f}s, "
        f"onset={active_start / TARGET_SAMPLE_RATE:.3f}s, "
        f"active={len(active) / TARGET_SAMPLE_RATE:.3f}s, "
        f"rms={active_rms_db:.2f}dBFS, peak={peak_db:.2f}dBFS"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    replace(args.source, args.output)


if __name__ == "__main__":
    main()
