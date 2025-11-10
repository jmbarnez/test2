local definition = {
    id = "resource:ore_chunk",
    type = "resource",
    name = "Ore Chunk",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.2,
    icon = {
        layers = {
            {
                shape = "circle",
                radius = 0.58,
                color = { 0.1, 0.08, 0.06, 0.7 },
                offsetY = 0.14,
            },
            {
                shape = "circle",
                radius = 0.52,
                color = { 0.38, 0.32, 0.27 },
            },
            {
                shape = "circle",
                radius = 0.44,
                color = { 0.6, 0.5, 0.39 },
                offsetX = -0.06,
                offsetY = -0.06,
            },
            {
                shape = "rectangle",
                width = 0.46,
                height = 0.22,
                color = { 0.3, 0.24, 0.18, 0.82 },
                rotation = 0.28,
                offsetX = -0.06,
                offsetY = 0.1,
            },
            {
                shape = "rectangle",
                width = 0.34,
                height = 0.16,
                color = { 0.82, 0.72, 0.58, 0.75 },
                rotation = -0.32,
                offsetX = 0.14,
                offsetY = -0.2,
            },
            {
                shape = "rectangle",
                width = 0.26,
                height = 0.14,
                color = { 0.46, 0.37, 0.28 },
                rotation = 0.52,
                offsetX = 0.22,
                offsetY = 0.04,
            },
            {
                shape = "circle",
                radius = 0.14,
                color = { 0.95, 0.86, 0.74, 0.9 },
                offsetX = -0.18,
                offsetY = -0.16,
            },
            {
                shape = "circle",
                radius = 0.09,
                color = { 1.0, 0.95, 0.83 },
                offsetX = 0.18,
                offsetY = -0.04,
            },
            {
                shape = "ring",
                radius = 0.54,
                thickness = 0.08,
                color = { 0.96, 0.9, 0.75, 0.18 },
            },
        },
    },
}

return definition
