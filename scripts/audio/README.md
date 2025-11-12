# Procedural Audio Generators

This folder hosts small Python utilities that synthesize sound effects directly from
parameterized presets. The workflow is:

1. Describe a sound family in `presets/<name>.json` (see schema below).
2. Run `python generate_sfx.py --preset presets/<name>.json` to render one or more
   variants into `assets/sounds/...`.
3. Reference the generated files in blueprints or systems. AudioManager will pick
them up automatically because it scans the `assets/sounds` tree.

## Preset schema (v1)

```jsonc
{
  "name": "laser_turret",                // used for output folders + manifest ids
  "description": "Pulse laser turret shots",
  "output": {
    "directory": "assets/sounds/generated/laser_turret", // relative to repo root
    "base_filename": "laser_turret",    // base file name (variants append suffix)
    "format": "wav"                      // currently only wav is supported
  },
  "parameters": {
    "duration": 0.55,                    // seconds
    "sample_rate": 44100,
    "frequency": {
      "start": 1100,
      "decay": 3.8,
      "floor": 220,
      "jitter_amplitude": 0.04,
      "jitter_frequency": 90
    },
    "harmonics": [                       // oscillators summed together
      { "ratio": 1.0, "amplitude": 0.7 },
      { "ratio": 1.9, "amplitude": 0.3, "phase": 0.4 },
      { "ratio": 2.8, "amplitude": 0.15, "phase": -0.2 }
    ],
    "burst": {                           // squared-sine pulse for punch
      "frequency": 16
    },
    "tremolo": {
      "frequency": 7,
      "depth": 0.4,
      "floor": 0.6
    },
    "sub": {
      "ratio": 0.45,
      "amplitude": 0.45
    },
    "noise": {
      "amplitude": 0.18,
      "decay": 6.2
    },
    "envelope": {
      "attack": 0.02,
      "decay": 4.4,
      "release": 0.18
    }
  },
  "variants": [
    {
      "name": "default",
      "seed": 8721,
      "overrides": {
        "noise": { "amplitude": 0.18 }
      }
    }
  ]
}
```

Any `overrides` entry uses a deep merge to tweak parameters per variant. New fields can be
added to `parameters` as necessary – the generator ignores terms it does not yet understand.

## Manifest output

Running the generator writes a `manifest.json` next to the rendered audio. The manifest
captures file names, seeds, and merged parameters for each variant. Tooling (or humans)
can use this to wire the sounds into blueprints, or simply inspect what was produced.

```
assets/sounds/generated/laser_turret/
  ├── laser_turret_default.wav
  └── manifest.json
```

AudioManager assigns IDs based on the file path (e.g. `sfx:generated:laser_turret:laser_turret_default`).
Use those IDs inside weapon definitions.
