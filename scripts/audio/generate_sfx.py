#!/usr/bin/env python3
"""Preset-driven procedural audio generator for Novus SFX."""
from __future__ import annotations

import argparse
import json
import math
import random
import struct
import wave
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict, Iterable, Tuple

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SAMPLE_RATE = 44100
DEFAULT_DURATION = 0.4
DEFAULT_ATTACK = 0.01
DEFAULT_RELEASE = 0.1
DEFAULT_DECAY = 4.0
SUPPORTED_FORMATS = {"wav"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate procedural sound effects from presets.")
    parser.add_argument("--preset", required=True, type=Path, help="Path to preset JSON file.")
    parser.add_argument(
        "--output",
        type=Path,
        help="Override output directory (relative to repo root or absolute).",
    )
    parser.add_argument(
        "--variant",
        action="append",
        help="Render only specific variant names (can repeat). Defaults to all variants.",
    )
    return parser.parse_args()


def read_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def deep_merge(base: Dict[str, Any], overrides: Dict[str, Any]) -> Dict[str, Any]:
    result = deepcopy(base)
    for key, value in overrides.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result


def resolve_output_paths(preset: Dict[str, Any], override_dir: Path | None) -> Tuple[Path, str, str]:
    output_cfg = preset.get("output", {})
    directory = output_cfg.get("directory", f"assets/sounds/generated/{preset.get('name', 'unnamed')}")
    base_filename = output_cfg.get("base_filename", preset.get("name", "sound"))
    file_format = output_cfg.get("format", "wav").lower()
    if file_format not in SUPPORTED_FORMATS:
        raise ValueError(f"Unsupported output format '{file_format}'. Only {sorted(SUPPORTED_FORMATS)} supported.")

    if override_dir:
        directory = str(override_dir)

    output_dir = Path(directory)
    if not output_dir.is_absolute():
        output_dir = ROOT / output_dir

    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir, base_filename, file_format


def ensure_variants(preset: Dict[str, Any]) -> Iterable[Dict[str, Any]]:
    variants = preset.get("variants")
    if not variants:
        return [
            {
                "name": "default",
                "seed": None,
                "overrides": {},
            }
        ]
    return variants


def synthesize(parameters: Dict[str, Any], seed: int | None, output_path: Path) -> Dict[str, Any]:
    duration = float(parameters.get("duration", DEFAULT_DURATION))
    sample_rate = int(parameters.get("sample_rate", DEFAULT_SAMPLE_RATE))
    total_samples = max(1, int(sample_rate * duration))

    freq_cfg = parameters.get("frequency", {})
    base_start = float(freq_cfg.get("start", 900))
    base_decay = float(freq_cfg.get("decay", DEFAULT_DECAY))
    base_floor = float(freq_cfg.get("floor", 180))
    jitter_amp = float(freq_cfg.get("jitter_amplitude", 0.0))
    jitter_freq = float(freq_cfg.get("jitter_frequency", 60))

    harmonics = parameters.get("harmonics", [])
    burst_cfg = parameters.get("burst", {})
    trem_cfg = parameters.get("tremolo", {})
    sub_cfg = parameters.get("sub", {})
    noise_cfg = parameters.get("noise", {})
    env_cfg = parameters.get("envelope", {})

    attack = float(env_cfg.get("attack", DEFAULT_ATTACK))
    decay = float(env_cfg.get("decay", DEFAULT_DECAY))
    release = float(env_cfg.get("release", DEFAULT_RELEASE))

    if seed is not None:
        random.seed(seed)

    trem_floor = float(trem_cfg.get("floor", 1.0 - trem_cfg.get("depth", 0.0)))
    trem_depth = float(trem_cfg.get("depth", 0.0))
    trem_freq = float(trem_cfg.get("frequency", 5.0))

    burst_freq = float(burst_cfg.get("frequency", 12.0))

    sub_ratio = float(sub_cfg.get("ratio", 0.5))
    sub_amp = float(sub_cfg.get("amplitude", 0.0))

    noise_amp = float(noise_cfg.get("amplitude", 0.0))
    noise_decay = float(noise_cfg.get("decay", decay))

    with wave.open(str(output_path), "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for n in range(total_samples):
            t = n / sample_rate
            freq = base_start * math.exp(-base_decay * t) + base_floor
            if jitter_amp:
                freq *= 1 + jitter_amp * math.sin(2 * math.pi * jitter_freq * t)

            phase = 2 * math.pi * freq * t
            harmonic_sum = 0.0
            for harmonic in harmonics:
                ratio = float(harmonic.get("ratio", 1.0))
                amp = float(harmonic.get("amplitude", 0.0))
                phase_offset = float(harmonic.get("phase", 0.0))
                harmonic_sum += amp * math.sin(phase * ratio + phase_offset)

            burst_env = math.sin(2 * math.pi * burst_freq * t) ** 2 if burst_freq > 0 else 1.0
            tremolo = trem_floor + trem_depth * math.sin(2 * math.pi * trem_freq * t)
            sub = sub_amp * math.sin(2 * math.pi * freq * sub_ratio * t)
            hiss = ((random.random() * 2) - 1) * noise_amp * math.exp(-noise_decay * t)

            envelope = math.exp(-decay * t)
            if t < attack:
                envelope *= t / attack if attack > 0 else 1
            if duration - t < release:
                envelope *= max(0.0, (duration - t) / release) if release > 0 else 1

            sample = (harmonic_sum * burst_env * tremolo + sub + hiss) * envelope
            sample = max(-0.999, min(0.999, sample))
            wav.writeframes(struct.pack("<h", int(sample * 32767)))

    return {
        "path": str(output_path.relative_to(ROOT)),
        "duration": duration,
        "sample_rate": sample_rate,
        "seed": seed,
        "parameters": parameters,
    }


def render_preset(preset_path: Path, output_override: Path | None, allowed_variants: set[str] | None) -> None:
    preset = read_json(preset_path)
    output_dir, base_filename, file_format = resolve_output_paths(preset, output_override)
    parameters = preset.get("parameters", {})

    manifest_entries = []
    for variant in ensure_variants(preset):
        name = variant.get("name", "variant")
        if allowed_variants and name not in allowed_variants:
            continue

        seed = variant.get("seed")
        overrides = variant.get("overrides", {})
        merged_params = deep_merge(parameters, overrides)

        suffix = f"_{name}" if name else ""
        filename = f"{base_filename}{suffix}.{file_format}"
        output_path = output_dir / filename

        entry = synthesize(merged_params, seed, output_path)
        entry.update({
            "variant": name,
            "seed": seed,
            "filename": filename,
        })
        manifest_entries.append(entry)
        print(f"Generated {output_path.relative_to(ROOT)}")

    manifest = {
        "preset": preset.get("name"),
        "description": preset.get("description"),
        "source": str(preset_path.relative_to(ROOT) if preset_path.is_absolute() else preset_path),
        "variants": manifest_entries,
    }

    manifest_path = output_dir / "manifest.json"
    with manifest_path.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    print(f"Wrote manifest to {manifest_path.relative_to(ROOT)}")


def main() -> None:
    args = parse_args()
    preset_path = args.preset
    if not preset_path.is_absolute():
        preset_path = (ROOT / preset_path).resolve()

    allowed_variants = set(args.variant) if args.variant else None
    output_override = args.output
    if output_override and not output_override.is_absolute():
        output_override = ROOT / output_override

    render_preset(preset_path, output_override, allowed_variants)


if __name__ == "__main__":
    main()
