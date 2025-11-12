# Novus
A high-velocity spacefaring prototype built with the LÖVE 11.5 framework. Pilot a modular ship, chart uncharted sectors, and manage your fleet through a crisp, flat-styled interface.

## Features
- **Immersive sector sandbox** – dynamic asteroids, stations, and encounters stitched together by Tiny-ecs systems.
- **Responsive flight & combat** – precise mouse aiming, configurable weapon cycling, and smooth thruster control.
- **Command cockpit UI** – flat, hard-edged panels for cargo, options, and tactical maps that stay readable in the thick of battle.
- **Adaptive audio landscape** – the audio manager autoloads music and SFX for a seamless soundscape @src/audio/manager.lua#1-240.

## Quick Start
1. **Install LÖVE 11.5** – download from [love2d.org](https://love2d.org/).
2. **Clone or download** this repository and open a terminal in the project root.
3. Launch the game:
   - **Windows:** run `run.bat` for a logged debug session @run.bat#1-74.
   - **Any platform:** run `love . --debug` (or just `love .`).

The window title and runtime configuration are pulled from `src/constants/game.lua` @src/constants/game.lua#17-41 via `love.conf` @conf.lua#5-25.

## Default Controls
| Action | Keys |
| --- | --- |
| Thrust / Strafe | **W A S D** or arrow keys |
| Aim & Fire Primary | Mouse position & **Left Click** |
| Fire Secondary | **Right Click** |
| Cycle Weapons | **Q** / **E** |
| Toggle Cargo | **Tab** |
| Toggle Star Map | **M** |
| Toggle Skills | **K** |
| Pause Menu | **Esc** |
| Fullscreen Toggle | **F11** |
| Quick Save | **F5** |
| Quick Load | **F9** |

All bindings can be remapped in the Options window @src/ui/windows/options.lua#32-110.

## Project Layout
- `src/` – core gameplay states, ECS systems, UI, player logic, and entity factories.
- `assets/` – music, SFX, and typefaces (Orbitron family) used across the UI.
- `libs/` – bundled third-party helpers (Tiny ECS, HUMP Gamestate, JSON utilities).
- `run.bat` / `build.bat` – Windows helpers for local playtesting or packaging.

## Contributing
Pull requests are welcome. Keep code style consistent with existing Lua modules and preserve the cohesive flat UI aesthetic. When adding new assets, drop them into `assets/` so the audio manager and loaders can pick them up automatically.

---
*Novus is in active development. Strap in, share feedback, and help shape the frontier.*
