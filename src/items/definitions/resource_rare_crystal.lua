local math = math

local definition = {
    id = "resource:rare_crystal",
    type = "resource",
    name = "Rare Crystal",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.05,
    icon = {
        layers = {
            {
                shape = "circle",
                radius = 0.46,
                color = { 0.35, 0.12, 0.52 },
            },
            {
                shape = "triangle",
                width = 0.42,
                height = 0.48,
                direction = "up",
                color = { 0.64, 0.26, 0.92 },
                rotation = math.rad(15),
            },
            {
                shape = "triangle",
                width = 0.32,
                height = 0.36,
                direction = "up",
                color = { 0.84, 0.54, 1.0 },
                rotation = math.rad(-18),
                offsetX = 0.08,
                offsetY = -0.04,
            },
            {
                shape = "circle",
                radius = 0.12,
                color = { 1.0, 0.82, 1.0 },
                offsetX = -0.1,
                offsetY = 0.12,
            },
        },
    },
}

return definition
