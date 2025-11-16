local math = math

local scale = 18
local cos30 = math.cos(math.rad(30))

local function regular_hex(radius, v_scale)
    local r = radius or scale
    local v = v_scale or 1
    local x = cos30 * r
    return {
        0, -r * v,
        x, -0.5 * r * v,
        x, 0.5 * r * v,
        0, r * v,
        -x, 0.5 * r * v,
        -x, -0.5 * r * v,
    }
end

local outer_hex = regular_hex(1.1 * scale, 1.05)
local ring_hex = regular_hex(0.78 * scale, 1.0)
local inner_hex = regular_hex(0.48 * scale, 0.9)

local sensor_panel = {
    -0.38 * scale, -0.48 * scale,
    0, -0.92 * scale,
    0.38 * scale, -0.48 * scale,
    0.24 * scale, -0.18 * scale,
    -0.24 * scale, -0.18 * scale,
}

local lattice_arm = {
    0.32 * scale, -0.1 * scale,
    0.66 * scale, -0.02 * scale,
    0.66 * scale, 0.28 * scale,
    0.28 * scale, 0.16 * scale,
}

local accent_plate = {
    -0.44 * scale, 0.02 * scale,
    -0.2 * scale, -0.18 * scale,
    0.2 * scale, -0.18 * scale,
    0.44 * scale, 0.02 * scale,
    0.22 * scale, 0.26 * scale,
    -0.22 * scale, 0.26 * scale,
}

local thruster_slot = {
    -0.3 * scale, 0.56 * scale,
    0.3 * scale, 0.56 * scale,
    0.4 * scale, 0.98 * scale,
    -0.4 * scale, 0.98 * scale,
}

local underside_panel = {
    -0.32 * scale, 0.35 * scale,
    0.32 * scale, 0.35 * scale,
    0.22 * scale, 0.6 * scale,
    -0.22 * scale, 0.6 * scale,
}

local physics_polygon = outer_hex

return {
    category = "ships",
    id = "starter",
    name = "Azure Hex Drone",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "hex_drone",
        player = true,
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        hullSize = { x = 32, y = 34 },
        thrusterOffset = 0,
        engineTrailAnchor = { x = 0, y = 0 },
        drawable = {
            type = "ship",
            hull = outer_hex,
            colors = {
                hull = { 0.1, 0.2, 0.28, 1 },
                outline = { 0.05, 0.1, 0.16, 1 },
                accent = { 0.16, 0.36, 0.56, 1 },
                trim = { 0.24, 0.52, 0.76, 1 },
                core = { 0.4, 0.72, 1.0, 0.95 },
                coreGlow = { 0.22, 0.42, 0.76, 0.85 },
                engine = { 0.35, 0.6, 1.0, 1 },
                default = { 0.1, 0.2, 0.28, 1 },
            },
            parts = {
                {
                    name = "hull",
                    type = "polygon",
                    points = outer_hex,
                    fill = "hull",
                    stroke = "outline",
                    strokeWidth = 2.6,
                },
                {
                    name = "accent_plate",
                    type = "polygon",
                    points = accent_plate,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 2,
                },
                {
                    name = "ring",
                    type = "polygon",
                    points = ring_hex,
                    fill = "trim",
                    stroke = "outline",
                    strokeWidth = 2,
                },
                {
                    name = "lattice_arm",
                    type = "polygon",
                    points = lattice_arm,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 1.6,
                    mirror = true,
                },
                {
                    name = "sensor_panel",
                    type = "polygon",
                    points = sensor_panel,
                    fill = "trim",
                    stroke = "outline",
                    strokeWidth = 1.6,
                },
                {
                    name = "underside_panel",
                    type = "polygon",
                    points = underside_panel,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 1.4,
                },
                {
                    name = "core_glow",
                    type = "ellipse",
                    centerX = 0,
                    centerY = 0,
                    radiusX = 0.24 * scale,
                    radiusY = 0.26 * scale,
                    fill = { 0.4, 0.75, 1.0, 0.35 },
                    stroke = false,
                    blend = "add",
                },
                {
                    name = "core",
                    type = "polygon",
                    points = inner_hex,
                    fill = "core",
                    stroke = "coreGlow",
                    strokeWidth = 1.4,
                },
                {
                    name = "thruster_slot",
                    type = "polygon",
                    points = thruster_slot,
                    fill = "engine",
                    stroke = "outline",
                    strokeWidth = 1.4,
                },
            },
        },
        stats = {
            mass = 1.6,
            main_thrust = 115,
            reverse_thrust = 45,
            strafe_thrust = 75,
            max_acceleration = 160,
            max_speed = 210,
            linear_damping = 0.65,
            angular_damping = 0.18,
            targetingTime = 1.2,
        },
        energy = {
            max = 140,
            current = 140,
            regen = 55,
            rechargeDelay = 0.8,
            thrustDrain = 42,
        },
        cargo = {
            capacity = 50,
            items = {
                { weapon = "cannon" },
                { weapon = "missile_launcher" },
                { weapon = "laser_beam" },
                { weapon = "firework_launcher" },
                { weapon = "shock_burst_launcher" },
                { weapon = "lightning_arc" },
                { module = "ability_afterburner", installed = true },
                { module = "shield_t1" },
            },
        },
        magnet = {
            radius = 260,
            strength = 360,
            falloff = 0.55,
            collectRadius = 28,
        },
        hull = {
            max = 95,
            current = 95,
            regen = 0,
        },
        shield = {
            max = 50,
            current = 50,
            regen = 2,
            rechargeDelay = 5.0,
        },
        modules = {
            defaultType = "defense",
            slots = {
                { type = "defense" },
                { type = "ability" },
            },
        },
        colliders = {
            {
                name = "hull",
                type = "polygon",
                points = physics_polygon,
            },
        },
    },
    weapons = {
        {
            id = "laser_turret",
            mount = {
                anchor = { x = 0, y = 0.72 },
                inset = 4,
            },
        },
    },
    physics = {
        body = {
            type = "dynamic",
        },
        fixture = {
            friction = 0.18,
            restitution = 0.12,
        },
    },
}
