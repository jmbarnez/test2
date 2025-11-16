# Getting Started

This guide walks you through setting up Novus for development and playtesting on Windows.

## Prerequisites

- **LÖVE 11.5** — Download from [love2d.org](https://love2d.org/) and install.
- **Git** — Recommended for pulling updates. Install from [git-scm.com](https://git-scm.com/) if needed.
- **Visual Studio Code** (or your preferred editor) with Lua support for best results.

## Project Layout

```
├── assets/           # Fonts, music, SFX
├── libs/             # Third-party Lua libraries (hump, tiny-ecs, json)
├── scripts/          # Utility scripts for audio generation
├── src/              # Game source code
│   ├── states/       # Game states (start menu, gameplay)
│   ├── systems/      # ECS systems (input, combat, AI, etc.)
│   ├── player/       # Player management and runtime logic
│   ├── blueprints/   # Data-driven entity definitions
│   └── util/         # Shared helpers (serialization, math, tables)
├── tools/            # Bundled DLLs/EXEs for Windows builds
├── conf.lua          # LÖVE configuration
├── main.lua          # Application entry point
├── run.bat           # Windows helper to launch with logging
└── README.md         # Project overview
```

## Running the Game

### Option 1: Using the Windows Helper Script
1. Double-click `run.bat`.
2. The script searches for `love.exe`, launches the game, and streams output to `logs/debug_output_*.txt`.
3. Inspect the log if you encounter crashes.

### Option 2: Command Line
```powershell
love .
```

### Option 3: VS Code Task (Optional)
Create a VS Code task that runs `love .` in the workspace folder for quick toggling between edit and play.

## Debugging Tips

- Press `F1` to toggle debug overlay (if bound in input bindings).
- Check `logs/` for captured console output when using `run.bat`.
- Enable physics or rendering debug flags in `src/constants/game.lua` under `constants.debug`.

## Saving and Loading

- Press the quick save key (`F5` by default) to serialize the current game state.
- Quick load (`F9`) restores from `savegame.json` using the component registry.
- Save files live in the LÖVE app data directory (e.g., `%AppData%/LOVE/Novus`).

## Next Steps

- Review the [Architecture Overview](./architecture.md) to understand how systems connect.
- Read [Controls & UX](./controls.md) to learn available inputs.
- Visit [Content Pipeline](./content_pipeline.md) when creating new ships, stations, or items.
