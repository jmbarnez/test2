-- Simple test for procedural ship generator
package.path = package.path .. ";./?.lua;./?/init.lua"

-- Mock love.math
love = love or {}
love.math = love.math or {}
love.math.random = math.random
love.math.setRandomSeed = math.randomseed

-- Load the generator
local generator = require("src.util.procedural_ship_generator")

print("=== Procedural Ship Generator Test ===\n")

-- Test 1: Generate a small ship
print("Test 1: Generating a small ship...")
local small_ship = generator.generate({
    size_class = "small",
    difficulty = "normal",
    seed = 12345,
})
print("✓ Small ship generated: " .. small_ship.name)
print("  ID: " .. small_ship.id)
print("  Components: " .. (small_ship.components and "Yes" or "No"))
print("  Weapons: " .. (small_ship.weapons and #small_ship.weapons or 0))
print()

-- Test 2: Generate a medium ship
print("Test 2: Generating a medium ship...")
local medium_ship = generator.generate({
    size_class = "medium",
    difficulty = "hard",
    seed = 67890,
})
print("✓ Medium ship generated: " .. medium_ship.name)
print("  Max Speed: " .. (medium_ship.components.stats.max_speed or "N/A"))
print("  Health: " .. (medium_ship.components.health.max or "N/A"))
print()

-- Test 3: Generate a large ship
print("Test 3: Generating a large ship...")
local large_ship = generator.generate({
    size_class = "large",
    difficulty = "extreme",
    seed = 99999,
})
print("✓ Large ship generated: " .. large_ship.name)
print("  Hull: " .. (large_ship.components.hull.max or "N/A"))
print("  Drawable parts: " .. (large_ship.components.drawable.parts and #large_ship.components.drawable.parts or 0))
print()

-- Test 4: Generate a batch
print("Test 4: Generating a batch of 5 ships...")
local batch = generator.generate_batch(5, {
    difficulty = "normal",
})
print("✓ Batch generated: " .. #batch .. " ships")
for i, ship in ipairs(batch) do
    print(string.format("  %d. %s (%s)", i, ship.name, ship._size_class))
end
print()

print("=== All tests passed! ===")
