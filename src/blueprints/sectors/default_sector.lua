return {
    category = "sectors",
    id = "default_sector",
    name = "Default Sector",
    asteroids = {
        count = { min = 30, max = 50 },
    },
    enemies = {
        count = { min = 15, max = 25 },
        ship_id = "enemy_scout",
        ship_ids = {
            { id = "enemy_drone", weight = 3 },
            { id = "enemy_scout", weight = 2 },
        },
        spawn_radius = 1500,
        spawn_safe_radius = 900,
        wander_radius = 1500,
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
}
