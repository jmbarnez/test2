local blueprint = {
    category = "modules",
    id = "ability_dash",
    name = "Vector Surge Dash",
    slot = "ability",
    rarity = "uncommon",
    description = "Ability module that propels the ship forward in a burst of speed.",
    components = {
        module = {
            ability = {
                id = "dash",
                type = "dash",
                displayName = "Dash",
                cooldown = 2.2,
                energyCost = 18,
                impulse = 1100,
                speed = 900,
                useMass = true,
                duration = 0.28,
                dashDamping = 0.12,
                hotkeyLabel = "SPACE",
                intentIndex = 1,
            },
        },
    },
    icon = {
        kind = "module",
        color = { 0.45, 0.85, 1.0, 1.0 },
        accent = { 0.2, 0.6, 1.0, 1.0 },
        detail = { 0.7, 0.95, 1.0, 1.0 },
        layers = {
            { shape = "rounded_rect", width = 0.8, height = 0.36, color = { 0.08, 0.12, 0.2 }, alpha = 0.95, radius = 0.1 },
            { shape = "triangle", width = 0.4, height = 0.7, color = { 0.4, 0.8, 1.0 }, alpha = 0.9, direction = "up" },
            { shape = "triangle", width = 0.28, height = 0.52, color = { 0.85, 0.98, 1.0 }, alpha = 0.75, direction = "up" },
            { shape = "ring", radius = 0.46, thickness = 0.06, color = { 0.2, 0.6, 1.0 }, alpha = 0.7 },
        },
    },
    item = {
        name = "Vector Surge Dash",
        description = "Trigger with Space to surge forward, consuming energy but instantly accelerating.",
        value = 1450,
        volume = 5,
    },
}

return blueprint
