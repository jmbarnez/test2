return {
    category = "sectors",
    id = "default_sector",
    name = "Default Sector",
    asteroids = {
        count = { min = 30, max = 500 },
    },
    proceduralShips = {
        count = { min = 20, max = 30 },
        difficulty = "normal", -- "easy", "normal", "hard", "extreme"
        level = { min = 1, max = 4 },
        spawn_safe_radius = 900,
        separation_radius = 700,
        wander_radius = 1500,
        size_distribution = {
            small = 0.5,   -- 50% small ships
            medium = 0.35, -- 35% medium ships
            large = 0.15,  -- 15% large ships
        },
    },
    worldBounds = {
        x = 0,
        y = 0,
        width = 20000,
        height = 20000,
    },
    stations = {
        {
            id = "hub_station",
            position = {
                x = 10000,
                y = 10000,
            },
        },
    },
    warpgates = {
        {
            id = "warpgate_alpha",
            position = {
                x = 10000 + 720,
                y = 10000 - 180,
            },
            rotation = math.pi * 0.15,
        },
    },
}
