local definition = {
    id = "resource:ferrosite_ore",
    type = "resource",
    name = "Ferrosite Ore",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.01,
    value = 14,
    description = "Common ferrous ore with a high refinement yield, often found in dense asteroid fragments.",
    icon = {
        layers = {
            {
                shape = "circle",
                radius = 0.58,
                color = { 0.06, 0.08, 0.12, 0.8 },
                offsetY = 0.12,
            },
            {
                shape = "circle",
                radius = 0.5,
                color = { 0.32, 0.38, 0.48, 1.0 },
            },
            {
                shape = "polygon",
                points = { -0.42, -0.12, 0.18, -0.38, 0.46, 0.06, 0.08, 0.42, -0.44, 0.18 },
                color = { 0.58, 0.7, 0.86, 0.95 },
            },
            {
                shape = "rectangle",
                width = 0.32,
                height = 0.16,
                color = { 0.9, 0.96, 1.0, 0.9 },
                rotation = -0.35,
                offsetX = 0.14,
                offsetY = -0.18,
            },
            {
                shape = "ring",
                radius = 0.54,
                thickness = 0.08,
                color = { 0.7, 0.82, 0.98, 0.18 },
            },
        },
    },
}

return definition
