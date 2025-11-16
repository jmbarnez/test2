# Controls & UX Reference

This reference lists default inputs, how intent mapping works, and how UI capture affects gameplay actions.

## Default Key Bindings

| Intent            | Default Keys          | Notes                               |
|-------------------|-----------------------|-------------------------------------|
| Toggle Pause      | `Esc`                 | Opens the pause menu                |
| Toggle Debug      | `F1`                  | Toggles debug overlays              |
| Toggle Fullscreen | `F11`                 | Switches fullscreen mode            |
| Confirm / Select  | `Enter`, `Space`      | Context-sensitive confirmations     |
| Interact          | `E`                   | Dock stations, loot, talk           |
| Toggle Cargo      | `Tab`                 | Opens cargo/inventory UI            |
| Toggle Map        | `M`                   | Displays sector map                 |
| Toggle Skills     | `K`                   | Opens pilot skill window            |
| Quick Save        | `F5`                  | Writes `savegame.json`              |
| Quick Load        | `F9`                  | Restores the latest save            |
| Weapon Slots 1–0  | `1-0` (number row)    | Selects weapon banks                |

## Mouse Controls

- **Primary Fire** — Left mouse button (unless UI captures the mouse)
- **Secondary Fire** — Right mouse button
- **Aim** — Cursor position translated to world coordinates via camera zoom/offset
- **Target Lock** — Hold `Ctrl` + click (processed in targeting system)

## Intent Processing

1. `src/input/bindings.lua` maps keys -> intent names.
2. `src/input/mapper.lua` translates key events into intent flags each frame.
3. `src/systems/input_local.lua` normalizes movement vectors and aim coordinates.
4. Systems like `player_control` consume intents to move/attack.

### UI Capture Rules

- `uiInput.mouseCaptured` prevents firing when hovering UI windows.
- `uiInput.keyboardCaptured` blocks gameplay toggles (inventory, interact, etc.).
- `input_local` checks these flags before setting `firePrimary`, `fireSecondary`, or responding to keyboard intents.

### Tips for Designers

- When adding new UI windows, ensure they set `uiInput.mouseCaptured`/`keyboardCaptured` appropriately via `UIStateManager`.
- To add new bindings, update `bindings.lua` and handle the intent in relevant systems.
- Use `Intent.setAbility(intent, index, isDown)` for ability hotkeys (currently `Space` -> `ability1`).

## UI Interaction Highlights

- Start menu buttons respond to hover/click with smooth styling (see `start_menu.lua`).
- `UIStateManager` centralizes modal windows, transitions, and focus states.
- The HUD shows health, shields, and targeting status; check `src/systems/hud.lua` for draw order.

Keep this sheet updated whenever inputs, UI flows, or intent handling changes.
