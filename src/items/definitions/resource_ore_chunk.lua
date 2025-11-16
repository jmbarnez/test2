local definition = {
    id = "resource:ore_chunk",
    type = "resource",
    name = "Ore Chunk",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.01,
    value = 10,
    icon = {
        layers = {
            {
                shape = "polygon",
                points = { -0.56, -0.18, -0.22, -0.52, 0.24, -0.48, 0.58, -0.1, 0.46, 0.4, 0.04, 0.56, -0.42, 0.34 },
                color = { 0.12, 0.09, 0.06, 0.88 },
                offsetX = 0.04,
                offsetY = 0.08,
            },
            {
                shape = "polygon",
                points = { -0.56, -0.18, -0.22, -0.52, 0.24, -0.48, 0.58, -0.1, 0.46, 0.4, 0.04, 0.56, -0.42, 0.34 },
                color = { 0.42, 0.34, 0.26, 1.0 },
            },
            {
                shape = "polygon",
                points = { -0.24, -0.14, 0.16, -0.28, 0.36, 0.08, 0.08, 0.32, -0.28, 0.18 },
                color = { 0.64, 0.54, 0.42, 0.9 },
                offsetX = 0.02,
                offsetY = -0.04,
            },
            {
                shape = "rectangle",
                width = 0.22,
                height = 0.12,
                color = { 0.28, 0.22, 0.16, 0.85 },
                rotation = 0.35,
                offsetX = -0.14,
                offsetY = 0.16,
            },
            {
                shape = "circle",
                radius = 0.08,
                color = { 0.92, 0.84, 0.68, 0.85 },
                offsetX = -0.16,
                offsetY = -0.14,
            },
            {
                shape = "circle",
                radius = 0.06,
                color = { 0.98, 0.92, 0.78, 0.75 },
                offsetX = 0.18,
                offsetY = -0.06,
            },
            {
                shape = "ring",
                radius = 0.56,
                thickness = 0.04,
                color = { 0.84, 0.76, 0.62, 0.18 },
            },
        },
    },
}

return definition
