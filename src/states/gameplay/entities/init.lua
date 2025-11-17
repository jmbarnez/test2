-- Main entry point for entities module
-- Re-exports all functionality from submodules for backward compatibility

local Combat = require("src.states.gameplay.entities.combat")
local Lifecycle = require("src.states.gameplay.entities.lifecycle")
local Spawning = require("src.states.gameplay.entities.spawning")

local Entities = {}

-- Combat functions
Entities.hasActiveShield = Combat.hasActiveShield
Entities.heal = Combat.heal
Entities.damage = Combat.damage
Entities.pushCollisionImpact = Combat.pushCollisionImpact

-- Lifecycle functions
Entities.updateHealthTimers = Lifecycle.updateHealthTimers
Entities.destroyWorldEntities = Lifecycle.destroyWorldEntities
Entities.clearNonLocalEntities = Lifecycle.clearNonLocalEntities

-- Spawning functions
Entities.createShip = Spawning.createShip
Entities.spawnStation = Spawning.spawnStation
Entities.spawnStations = Spawning.spawnStations
Entities.spawnWarpgate = Spawning.spawnWarpgate
Entities.spawnWarpgates = Spawning.spawnWarpgates
Entities.spawnPlayer = Spawning.spawnPlayer
Entities.spawnLootPickup = Spawning.spawnLootPickup

return Entities
