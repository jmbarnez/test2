local definition = {
    id = "resource:hull_scrap",
    type = "resource",
    name = "Hull Scrap",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.02,
    value = 6,
    description = "Salvaged plating fragments harvested from destroyed hulls.",
    icon = {
        layers = {
            {
                shape = "polygon",
                points = { -0.6, -0.14, -0.28, -0.46, 0.18, -0.42, 0.52, -0.06, 0.38, 0.36, -0.08, 0.52, -0.48, 0.24 },
                color = { 0.06, 0.07, 0.08, 0.9 },
                offsetX = 0.06,
                offsetY = 0.08,
            },
            {
                shape = "polygon",
                points = { -0.6, -0.14, -0.28, -0.46, 0.18, -0.42, 0.52, -0.06, 0.38, 0.36, -0.08, 0.52, -0.48, 0.24 },
                color = { 0.38, 0.44, 0.50, 1.0 },
            },
            {
                shape = "polygon",
                points = { -0.26, -0.12, 0.22, -0.18, 0.32, 0.14, -0.12, 0.28 },
                color = { 0.62, 0.70, 0.78, 0.85 },
                offsetX = 0.08,
                offsetY = -0.04,
            },
            {
                shape = "rectangle",
                width = 0.28,
                height = 0.06,
                color = { 0.18, 0.20, 0.24, 0.8 },
                rotation = 0.3,
                offsetX = -0.12,
                offsetY = 0.14,
            },
            {
                shape = "rectangle",
                width = 0.16,
                height = 0.04,
                color = { 0.82, 0.88, 0.92, 0.7 },
                rotation = -0.5,
                offsetX = 0.18,
                offsetY = -0.12,
            },
            {
                shape = "ring",
                radius = 0.58,
                thickness = 0.04,
                color = { 0.56, 0.62, 0.68, 0.22 },
            },
        },
    },
}

return definition
