local definition = {
    id = "resource:ore_chunk",
    type = "resource",
    name = "Ore Chunk",
    stackable = true,
    defaultQuantity = 1,
    volume = 1,
    icon = {
        layers = {
            {
                shape = "circle",
                radius = 0.48,
                color = { 0.46, 0.39, 0.32 },
            },
            {
                shape = "circle",
                radius = 0.36,
                color = { 0.62, 0.52, 0.41 },
                offsetX = -0.08,
                offsetY = -0.05,
            },
            {
                shape = "triangle",
                radius = 0.2,
                width = 0.35,
                height = 0.3,
                direction = "up",
                color = { 0.78, 0.68, 0.55 },
                offsetX = 0.12,
                offsetY = 0.08,
            },
        },
    },
}

return definition
