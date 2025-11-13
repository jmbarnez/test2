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
                shape = "circle",
                radius = 0.58,
                color = { 0.06, 0.06, 0.06, 0.8 },
                offsetY = 0.12,
            },
            {
                shape = "circle",
                radius = 0.5,
                color = { 0.32, 0.32, 0.34, 1.0 },
            },
            {
                shape = "polygon",
                points = { -0.42, -0.1, 0.16, -0.36, 0.44, 0.02, 0.1, 0.4, -0.4, 0.2 },
                color = { 0.5, 0.5, 0.54, 0.95 },
            },
            {
                shape = "rectangle",
                width = 0.3,
                height = 0.16,
                color = { 0.8, 0.82, 0.86, 0.7 },
                rotation = -0.3,
                offsetX = 0.12,
                offsetY = -0.18,
            },
            {
                shape = "ring",
                radius = 0.54,
                thickness = 0.08,
                color = { 0.7, 0.7, 0.74, 0.14 },
            },
        },
    },
}

return definition
