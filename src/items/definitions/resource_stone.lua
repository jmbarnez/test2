local definition = {
    id = "resource:stone",
    type = "resource",
    name = "Stone",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.01,
    value = 2,
    description = "Common asteroid stone fragments with minimal industrial use.",
    icon = {
        layers = {
            {
                shape = "polygon",
                points = { -0.58, -0.26, -0.14, -0.5, 0.28, -0.46, 0.56, -0.08, 0.42, 0.44, -0.12, 0.52, -0.5, 0.18 },
                color = { 0.18, 0.19, 0.21, 0.82 },
                offsetX = 0.04,
                offsetY = 0.06,
            },
            {
                shape = "polygon",
                points = { -0.58, -0.26, -0.14, -0.5, 0.28, -0.46, 0.56, -0.08, 0.42, 0.44, -0.12, 0.52, -0.5, 0.18 },
                color = { 0.36, 0.37, 0.40, 1.0 },
            },
            {
                shape = "circle",
                radius = 0.06,
                color = { 0.52, 0.54, 0.58, 0.7 },
                offsetX = -0.14,
                offsetY = -0.08,
            },
        },
    },
}

return definition
