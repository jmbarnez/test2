local constants = require("src.constants.game")

local asteroid_constants = constants.asteroids or {}
local color = asteroid_constants.color or { 0.7, 0.65, 0.6 }
local health_bar = asteroid_constants.health_bar or {}

return {
    category = "asteroids",
    id = "default",
    name = "Procedural Asteroid",
    components = {
        asteroid = true,
        type = "asteroid",
        position = { x = 0, y = 0 },
        rotation = 0,
        velocity = { x = 0, y = 0 },
        drawable = {
            type = "asteroid",
            color = color,
        },
        health = {
            current = 0,
            max = 0,
            showTimer = 0,
        },
        healthBar = {
            showDuration = health_bar.show_duration or health_bar.showDuration or 1.5,
            height = health_bar.height or 4,
            padding = health_bar.padding or 6,
            width = health_bar.width,
            offset = health_bar.offset,
        },
    },
    physics = {
        body = {
            type = "dynamic",
        },
        fixture = {
            friction = 0.85,
            restitution = 0.05,
        },
    },
}
