local definition = {
    id = "resource:gold",
    type = "resource",
    name = "Gold",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.01,
    value = 40,
    description = "Rare gold deposits occasionally found within asteroid rock.",
    icon = {
        layers = {
            {
                shape = "circle",
                radius = 0.58,
                color = { 0.18, 0.12, 0.02, 0.85 },
                offsetY = 0.12,
            },
            {
                shape = "circle",
                radius = 0.5,
                color = { 0.7, 0.56, 0.18, 1.0 },
            },
            {
                shape = "polygon",
                points = { -0.42, -0.1, 0.2, -0.34, 0.46, 0.02, 0.1, 0.42, -0.38, 0.22 },
                color = { 0.98, 0.88, 0.42, 0.98 },
            },
            {
                shape = "rectangle",
                width = 0.32,
                height = 0.16,
                color = { 1.0, 0.96, 0.8, 0.9 },
                rotation = -0.3,
                offsetX = 0.14,
                offsetY = -0.18,
            },
            {
                shape = "ring",
                radius = 0.54,
                thickness = 0.08,
                color = { 1.0, 0.9, 0.5, 0.2 },
            },
        },
    },
}

return definition
