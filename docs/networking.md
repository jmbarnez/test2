# Networking Setup

## Dependency: lua-enet

1. **Download binaries**
   - For Windows, grab the compiled `enet.dll` (and matching `lua51.dll` if needed) from the LÖVE wiki or community builds.
   - Place the DLLs under `libs/enet/` and ensure they ship with the game.

2. **Source option**
   - Alternatively, clone https://github.com/leafo/lua-enet and build using MSYS2/MinGW.

3. **Love executable bundling**
   - If packaging a fused executable, drop `enet.dll` next to the bundled `.exe`.

### Usage quickstart
```lua
local enet = require("enet")
local host = enet.host_create("localhost:12345")
local peer = host:connect("127.0.0.1:12345")
```

Ensure `package.cpath` includes the DLL directory when running from source.
