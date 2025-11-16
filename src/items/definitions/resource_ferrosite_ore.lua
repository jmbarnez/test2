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
                shape = "polygon",
                points = { -0.54, -0.16, -0.2, -0.5, 0.26, -0.46, 0.56, -0.08, 0.42, 0.38, 0.02, 0.52, -0.44, 0.32 },
                color = { 0.08, 0.1, 0.14, 0.85 },
                offsetX = 0.04,
                offsetY = 0.08,
            },
            {
                shape = "polygon",
                points = { -0.54, -0.16, -0.2, -0.5, 0.26, -0.46, 0.56, -0.08, 0.42, 0.38, 0.02, 0.52, -0.44, 0.32 },
                color = { 0.32, 0.42, 0.56, 1.0 },
            },
            {
                shape = "polygon",
                points = { -0.18, -0.24, 0.22, -0.32, 0.38, 0.02, 0.14, 0.36, -0.26, 0.22 },
                color = { 0.62, 0.76, 0.92, 0.88 },
                offsetX = 0.04,
                offsetY = -0.06,
            },
            {
                shape = "rectangle",
                width = 0.18,
                height = 0.08,
                color = { 0.88, 0.95, 1.0, 0.75 },
                rotation = -0.4,
                offsetX = 0.18,
                offsetY = -0.16,
            },
            {
                shape = "ring",
                radius = 0.54,
                thickness = 0.05,
                color = { 0.52, 0.68, 0.88, 0.2 },
            },
        },
    },
}

return definition
