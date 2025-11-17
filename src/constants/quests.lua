-- ============================================================================
-- QUEST / CONTRACT CONFIGURATION
-- ============================================================================

return {
    default_offer_count = 3,
    default_contracts = {
        {
            id = "mining_operation",
            title = "Mining Operation",
            objective = "Destroy asteroids to clear the sector.",
            summary = "The station needs raw materials. Destroy asteroids in the area to extract ore and minerals.",
            credits = 500,
            type = "mining",
            target = 5,
        },
        {
            id = "heavy_mining",
            title = "Heavy Mining Contract",
            objective = "Destroy a large number of asteroids.",
            summary = "A major construction project requires substantial mineral resources. Clear out asteroid fields.",
            credits = 1200,
            type = "mining",
            target = 12,
        },
        {
            id = "hostile_elimination",
            title = "Hostile Elimination",
            objective = "Destroy enemy ships threatening the station.",
            summary = "Raiders have been spotted in the sector. Eliminate hostile vessels to secure the area.",
            credits = 800,
            type = "hunting",
            target = 3,
        },
        {
            id = "sector_defense",
            title = "Sector Defense",
            objective = "Eliminate multiple enemy threats.",
            summary = "A large enemy force is approaching. Destroy hostile ships to defend the station perimeter.",
            credits = 1500,
            type = "hunting",
            target = 6,
        },
    },
}
