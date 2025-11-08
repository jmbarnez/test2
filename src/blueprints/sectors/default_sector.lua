return {
    category = "sectors",
    id = "default_sector",
    name = "Default Sector",
    bounds = {
        x = 0,
        y = 0,
        width = 4000,
        height = 4000,
    },
    asteroids = {
        count = { min = 30, max = 50 },
    },
    enemies = {
        count = { min = 3, max = 3 },
        ship_id = "enemy_scout",
        spawn_radius = 1500,
        spawn_safe_radius = 900,
        wander_radius = 1500,
    },
    worldBounds = {
        x = 0,
        y = 0,
        width = 4000,
        height = 4000,
    },
}
