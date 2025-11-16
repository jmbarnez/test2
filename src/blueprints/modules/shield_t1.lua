local blueprint = {
    category = "modules",
    id = "shield_t1",
    name = "Aegis Micro-Shield",
    slot = "defense",
    rarity = "common",
    description = "Tier-1 shield generator providing a small rechargeable barrier.",
    components = {
        module = {
            shield_bonus = 35,
            shield_regen = 6,
            shield_recharge_delay = 3.0,
        },
    },
    icon = {
        kind = "module",
        color = { 0.45, 0.95, 1.0, 1.0 },
        accent = { 0.25, 0.75, 0.95, 1.0 },
        detail = { 0.15, 0.45, 0.8, 1.0 },
        layers = {
            {
                shape = "polygon",
                points = { -0.42, -0.32, 0.0, -0.54, 0.42, -0.32, 0.54, 0.06, 0.16, 0.52, -0.16, 0.52, -0.54, 0.06 },
                color = { 0.12, 0.38, 0.68, 0.88 },
            },
            {
                shape = "polygon",
                points = { -0.36, -0.26, 0.0, -0.46, 0.36, -0.26, 0.46, 0.08, 0.12, 0.44, -0.12, 0.44, -0.46, 0.08 },
                color = { 0.28, 0.78, 1.0, 0.95 },
            },
            {
                shape = "polygon",
                points = { -0.24, -0.18, 0.0, -0.32, 0.24, -0.18, 0.32, 0.08, 0.08, 0.32, -0.08, 0.32, -0.32, 0.08 },
                color = { 0.62, 0.96, 1.0, 0.88 },
            },
            {
                shape = "circle",
                radius = 0.08,
                color = { 0.88, 1.0, 1.0, 0.82 },
            },
            {
                shape = "ring",
                radius = 0.52,
                thickness = 0.06,
                color = { 0.42, 0.88, 1.0, 0.32 },
            },
        },
    },
    item = {
        name = "Aegis Micro-Shield",
        description = "Compact defensive module adding +35 shield capacity and gentle regen.",
        value = 750,
        volume = 4,
    },
}

return blueprint
