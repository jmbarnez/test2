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
                shape = "polygon",
                points = { -0.52, -0.2, -0.18, -0.52, 0.28, -0.48, 0.58, -0.06, 0.44, 0.42, -0.04, 0.56, -0.46, 0.28 },
                color = { 0.58, 0.42, 0.08, 0.95 },
            },
            {
                shape = "polygon",
                points = { -0.26, -0.18, 0.18, -0.34, 0.42, 0.0, 0.16, 0.42, -0.32, 0.28 },
                color = { 0.95, 0.82, 0.32, 0.98 },
                offsetX = 0.06,
                offsetY = -0.04,
            },
            {
                shape = "ring",
                radius = 0.52,
                thickness = 0.06,
                color = { 1.0, 0.92, 0.5, 0.28 },
            },
        },
    },
}

return definition
