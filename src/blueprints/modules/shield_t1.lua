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
            { shape = "circle", radius = 0.48, color = { 0.2, 0.85, 1.0 }, alpha = 0.65 },
            { shape = "ring", radius = 0.52, thickness = 0.08, color = { 0.35, 0.9, 1.0 }, alpha = 0.85 },
            { shape = "circle", radius = 0.32, color = { 0.6, 0.98, 1.0 }, alpha = 0.55 },
            { shape = "circle", radius = 0.18, color = { 1.0, 1.0, 1.0 }, alpha = 0.8 },
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
