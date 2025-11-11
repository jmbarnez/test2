-- Player Engine Trail Effect Module
local math_util = require("src.util.math")
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

-- Create stunning particle texture with radial gradient and bright core
local function createTrailTexture()
    local canvas = love.graphics.newCanvas(24, 24)
    withCanvas(canvas, function()
        local cx, cy = 12, 12
        -- Outer soft glow layers
        love.graphics.setColor(0.1, 0.4, 1.0, 0.05)
        love.graphics.circle("fill", cx, cy, 12)
        love.graphics.setColor(0.15, 0.5, 1.0, 0.1)
        love.graphics.circle("fill", cx, cy, 10)
        love.graphics.setColor(0.2, 0.6, 1.0, 0.15)
        love.graphics.circle("fill", cx, cy, 8)
        -- Mid-tone energy rings
        love.graphics.setColor(0.3, 0.7, 1.0, 0.3)
        love.graphics.circle("fill", cx, cy, 6)
        love.graphics.setColor(0.4, 0.8, 1.0, 0.5)
        love.graphics.circle("fill", cx, cy, 4.5)
        love.graphics.setColor(0.5, 0.85, 1.0, 0.7)
        love.graphics.circle("fill", cx, cy, 3)
        -- Bright inner core
        love.graphics.setColor(0.7, 0.9, 1.0, 0.9)
        love.graphics.circle("fill", cx, cy, 2)
        love.graphics.setColor(0.85, 0.95, 1.0, 0.95)
        love.graphics.circle("fill", cx, cy, 1.2)
        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        love.graphics.circle("fill", cx, cy, 0.8)
    end)
    return canvas
end

-- Configure gorgeous particle system with cinematic behavior
local function createParticleSystem()
    if not (love and love.graphics and love.graphics.newParticleSystem) then
        return nil
    end
    local texture = createTrailTexture()
    local ps = love.graphics.newParticleSystem(texture, 600)
    ps:setParticleLifetime(0.5, 1.2)
    ps:setSpeed(80, 180)
    ps:setLinearAcceleration(-30, -80, 30, 60)
    ps:setLinearDamping(0.8)
    ps:setSizes(0.9, 0.6, 0.3, 0.08, 0)
    ps:setSizeVariation(0.6)
    ps:setSpin(-3.0, 3.0, 0.5)
    ps:setSpread(math.rad(30))
    ps:setRelativeRotation(true)
    ps:setRotation(0, math_util.TAU)
    ps:setRadialAcceleration(-25, 25)
    ps:setTangentialAcceleration(-45, 45)
    ps:setEmissionRate(0)
    -- Stunning color progression: bright cyan to deep blue with shimmer
    ps:setColors(
        0.7, 0.9, 1.0, 1.0,
        0.5, 0.8, 1.0, 0.9,
        0.3, 0.65, 1.0, 0.7,
        0.2, 0.5, 0.95, 0.4,
        0.1, 0.35, 0.85, 0.15,
        0.05, 0.2, 0.6, 0
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
    self.direction = 0
    self.thrustStrength = 0
    self.player = nil
    self.fadeTime = 0
    self.lastEmissionRate = 0
    self.stopTimer = 0
    return self
end

function PlayerEngineTrail:attachPlayer(player)
    self.player = player
end

function PlayerEngineTrail:setActive(active)
    self.active = not not active
    if self.system and not self.active then
        self.fadeTime = 0.15
        self.stopTimer = 0
        self.system:setEmissionRate(0)
        self.lastEmissionRate = 0
    end
end

function PlayerEngineTrail:clear()
    if self.system then
        self.system:reset()
        self.system:setEmissionRate(0)
        self.lastEmissionRate = 0
        self.fadeTime = 0
        self.stopTimer = 0
    end
end

-- Align the particle system with the player's rear and read thrust state
function PlayerEngineTrail:updateFromPlayer()
    if not (self.player and self.system) then return end

    local pos = self.player.position
    local rot = self.player.rotation or 0
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

    -- Enhanced thrust strength calculation with shimmer
    local thrusting = self.player.isThrusting
    local thrust = self.player.currentThrust or 0
    local maxThrust = self.player.maxThrust or thrust
    local strength = 0
    
    if thrusting then
        self.stopTimer = 0
        if maxThrust > 0 then
            strength = math.min(thrust / maxThrust, 1)
        else
            strength = thrust > 0 and 1 or 0.6
        end
        -- Add shimmer and pulse for gorgeous effect
        local time = love.timer.getTime()
        local shimmer = 0.92 + 0.08 * math.sin(time * 12)
        local pulse = 0.95 + 0.05 * math.sin(time * 6)
        strength = strength * shimmer * pulse
    end
    
    self.thrustStrength = strength
end

-- Update the trail's emission and sync with player
function PlayerEngineTrail:update(dt)
    if not self.system then return end
    if self.player then self:updateFromPlayer() end

    local targetEmissionRate = 0
    
    if self.active and self.thrustStrength > 0 then
        -- Dramatic emission rate for gorgeous trails
        local baseRate = 250
        local thrustMultiplier = 0.3 + 0.7 * (self.thrustStrength ^ 1.3)
        targetEmissionRate = baseRate * thrustMultiplier
        
        self.system:setDirection(self.direction)
        self.system:setPosition(self.position.x, self.position.y)
        
        -- Dynamic spread for visual interest
        local spread = math.rad(20 + 20 * (1 - self.thrustStrength))
        self.system:setSpread(spread)
        
        self.fadeTime = 0
        self.stopTimer = 0
    else
        targetEmissionRate = 0
        self.stopTimer = self.stopTimer + dt
    end
    
    -- Smooth emission rate transitions
    local lerpFactor = 1 - math.exp(-dt * 25)
    self.lastEmissionRate = self.lastEmissionRate + (targetEmissionRate - self.lastEmissionRate) * lerpFactor
    
    if self.stopTimer > 0.02 or not self.active then
        self.lastEmissionRate = 0
    end
    
    self.system:setEmissionRate(self.lastEmissionRate)
    self.system:update(dt)
end

-- Enhanced burst emission with size scaling
function PlayerEngineTrail:emitBurst(count, sizeMultiplier)
    if not (self.system and count and count > 0) then return end
    
    if sizeMultiplier and sizeMultiplier > 1 then
        self.system:setSizes(1.0 * sizeMultiplier, 0.7 * sizeMultiplier, 0.35 * sizeMultiplier, 0.1)
        self.system:emit(count)
        self.system:setSizes(0.9, 0.6, 0.3, 0.08, 0)
    else
        self.system:emit(count)
    end
end

function PlayerEngineTrail:draw()
    if not self.system then return end
    
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    
    -- Enhanced color modulation with brightness boost
    local intensity = 0.9 + 0.1 * self.thrustStrength
    local tint = 0.95 + 0.05 * math.sin(love.timer.getTime() * 8)
    love.graphics.setColor(intensity * tint, intensity, intensity, 1)
    love.graphics.draw(self.system)
    
    love.graphics.pop()
end

return PlayerEngineTrail
