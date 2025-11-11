local definition = {
    id = "resource:hull_scrap",
    type = "resource",
    name = "Hull Scrap",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.02,
    description = "Salvaged plating fragments harvested from destroyed hulls.",
    icon = {
        layers = {
            {
                shape = "circle",
                radius = 0.56,
                color = { 0.08, 0.09, 0.1, 0.82 },
            },
            {
                shape = "polygon",
                points = { -0.52, -0.18, -0.12, -0.42, 0.4, -0.26, 0.28, 0.32, -0.34, 0.44 },
                color = { 0.36, 0.42, 0.48, 0.95 },
            },
            {
                shape = "polygon",
                points = { -0.28, -0.1, 0.46, -0.02, 0.24, 0.38, -0.44, 0.22 },
                color = { 0.58, 0.66, 0.72, 0.9 },
            },
            {
                shape = "rectangle",
                width = 0.32,
                height = 0.14,
                color = { 0.82, 0.88, 0.92, 0.78 },
                rotation = 0.35,
                offsetX = 0.02,
                offsetY = -0.08,
            },
            {
                shape = "triangle",
                width = 0.22,
                height = 0.2,
                direction = "up",
                color = { 0.24, 0.28, 0.32, 0.85 },
                offsetX = -0.22,
                offsetY = 0.14,
            },
            {
                shape = "ring",
                radius = 0.6,
                thickness = 0.08,
                color = { 0.68, 0.72, 0.78, 0.18 },
            },
        },
    },
}

return definition
