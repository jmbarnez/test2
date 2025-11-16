local math = math

local definition = {
    id = "resource:rare_crystal",
    type = "resource",
    name = "Rare Crystal",
    stackable = true,
    defaultQuantity = 1,
    volume = 0.01,
    value = 40,
    icon = {
        layers = {
            {
                shape = "polygon",
                points = { -0.2, -0.56, 0.0, -0.62, 0.2, -0.56, 0.48, -0.16, 0.34, 0.44, 0.0, 0.6, -0.34, 0.44, -0.48, -0.16 },
                color = { 0.22, 0.08, 0.32, 0.85 },
                offsetX = 0.02,
                offsetY = 0.04,
            },
            {
                shape = "polygon",
                points = { -0.2, -0.56, 0.0, -0.62, 0.2, -0.56, 0.48, -0.16, 0.34, 0.44, 0.0, 0.6, -0.34, 0.44, -0.48, -0.16 },
                color = { 0.58, 0.28, 0.88, 1.0 },
            },
            {
                shape = "polygon",
                points = { -0.12, -0.32, 0.12, -0.36, 0.28, -0.08, 0.18, 0.28, 0.0, 0.36, -0.18, 0.28, -0.28, -0.08 },
                color = { 0.82, 0.52, 1.0, 0.92 },
            },
            {
                shape = "polygon",
                points = { -0.06, -0.18, 0.06, -0.2, 0.14, 0.0, 0.08, 0.16, 0.0, 0.2, -0.08, 0.16, -0.14, 0.0 },
                color = { 0.96, 0.78, 1.0, 0.88 },
                offsetY = -0.02,
            },
            {
                shape = "ring",
                radius = 0.54,
                thickness = 0.06,
                color = { 0.72, 0.42, 0.98, 0.25 },
            },
        },
    },
}

return definition
