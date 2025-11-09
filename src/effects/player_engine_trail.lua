-- Player Engine Trail Effect Module
local PlayerEngineTrail = {}
PlayerEngineTrail.__index = PlayerEngineTrail

-- Utility function to safely set a graphics canvas
local function withCanvas(canvas, drawFunc)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    drawFunc()
    love.graphics.setCanvas()
    love.graphics.pop()
end

-- Create the particle system texture using a soft blue multi-circle gradient
local function createTrailTexture()
    local canvas = love.graphics.newCanvas(8, 8)
    withCanvas(canvas, function()
        local cx, cy = 4, 4
        -- Draw concentric circles for a glow effect
        love.graphics.setColor(0.4, 0.7, 1.0, 0.55)
        love.graphics.circle("fill", cx, cy, 4)
        love.graphics.setColor(0.5, 0.8, 1.0, 0.5)
        love.graphics.circle("fill", cx, cy, 3)
        love.graphics.setColor(0.6, 0.9, 1.0, 0.45)
        love.graphics.circle("fill", cx, cy, 2)
        love.graphics.setColor(0.7, 0.95, 1.0, 0.4)
        love.graphics.circle("fill", cx, cy, 1)
    end)
    return canvas
end

-- Configure the engine trail particleSystem for bluey "jet" look
local function createParticleSystem()
    if not (love and love.graphics and love.graphics.newParticleSystem) then
        return nil
    end
    local texture = createTrailTexture()
    local ps = love.graphics.newParticleSystem(texture, 256)
    ps:setParticleLifetime(0.45, 0.85)
    ps:setSpeed(40, 85)
    ps:setLinearAcceleration(-15, -40, 15, 30)
    ps:setLinearDamping(0.3)
    ps:setSizes(0.9, 0.55, 0.1)
    ps:setSizeVariation(0.35)
    ps:setSpin(-1.2, 1.2, 0.25)
    ps:setSpread(math.rad(28))
    ps:setRelativeRotation(true)
    ps:setRotation(0, math.pi * 2)
    ps:setRadialAcceleration(-10, 10)
    ps:setTangentialAcceleration(-20, 20)
    ps:setEmissionRate(0)
    ps:setColors(
        0.45, 0.75, 1.0, 0.78,
        0.25, 0.55, 1.0, 0.48,
        0.1, 0.32, 0.9, 0.24,
        0.05, 0.18, 0.6, 0
    )
    ps:start()
    return ps
end

-- Instantiate a new engine trail object
function PlayerEngineTrail.new()
    local self = setmetatable({}, PlayerEngineTrail)
    self.system = createParticleSystem()
    self.active = false
    self.position = { x = 0, y = 0 }
    self.direction = 0              -- radians
    self.thrustStrength = 0         -- 0..1
    self.player = nil               -- reference to player entity
    return self
end

function PlayerEngineTrail:attachPlayer(player)
    self.player = player
end

function PlayerEngineTrail:setActive(active)
    self.active = not not active
    if self.system and not self.active then
        self.system:setEmissionRate(0)
    end
end

function PlayerEngineTrail:clear()
    if self.system then
        self.system:reset()
        self.system:setEmissionRate(0)
    end
end

-- Align the particle system with the player's rear and read thrust state
function PlayerEngineTrail:updateFromPlayer()
    if not (self.player and self.system) then return end

    local pos, rot = self.player.position, self.player.rotation or 0
    self.direction = rot + math.pi

    -- Calculate the position for the rear jet
    local anchor = self.player.engineTrailAnchor
    local offsetX, offsetY
    if anchor then
        offsetX = anchor.x or 0
        offsetY = anchor.y or 0
    else
        offsetX = 0
        offsetY = self.player.thrusterOffset or 24
        if self.player.hullSize then
            offsetY = self.player.hullSize.y or offsetY
        end
    end
    local sinR, cosR = math.sin(rot), math.cos(rot)
    self.position.x = pos.x + cosR * offsetX - sinR * offsetY
    self.position.y = pos.y + sinR * offsetX + cosR * offsetY

    -- Thrust strength
    local thrusting = self.player.isThrusting
    local thrust = self.player.currentThrust or 0
    local maxThrust = self.player.maxThrust or thrust
    local strength = 0
    if thrusting then
        if maxThrust > 0 then
            strength = math.min(thrust / maxThrust, 1)
        else
            strength = thrust > 0 and 1 or 0.6
        end
    end
    self.thrustStrength = strength
end

-- Update the trail's emission and sync with player
function PlayerEngineTrail:update(dt)
    if not self.system then return end
    if self.player then self:updateFromPlayer() end

    local emissionRate = 0
    if self.active then
        emissionRate = 110 * (0.35 + 0.65 * self.thrustStrength)
        self.system:setDirection(self.direction)
        self.system:setPosition(self.position.x, self.position.y)
    end

    self.system:setEmissionRate(emissionRate)
    self.system:update(dt)
end

-- Burst-emission (eg for boost/jump)
function PlayerEngineTrail:emitBurst(count)
    if self.system and count and count > 0 then
        self.system:emit(count)
    end
end

function PlayerEngineTrail:draw()
    if not self.system then return end
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.draw(self.system)
    love.graphics.pop()
end

return PlayerEngineTrail
