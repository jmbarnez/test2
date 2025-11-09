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

-- Create enhanced particle system texture with more detailed glow
local function createTrailTexture()
    local canvas = love.graphics.newCanvas(16, 16)
    withCanvas(canvas, function()
        local cx, cy = 8, 8
        -- Enhanced concentric circles for better glow effect
        love.graphics.setColor(0.2, 0.5, 1.0, 0.1)
        love.graphics.circle("fill", cx, cy, 8)
        love.graphics.setColor(0.3, 0.6, 1.0, 0.3)
        love.graphics.circle("fill", cx, cy, 6)
        love.graphics.setColor(0.4, 0.7, 1.0, 0.6)
        love.graphics.circle("fill", cx, cy, 4)
        love.graphics.setColor(0.5, 0.8, 1.0, 0.8)
        love.graphics.circle("fill", cx, cy, 3)
        love.graphics.setColor(0.7, 0.9, 1.0, 0.95)
        love.graphics.circle("fill", cx, cy, 2)
        love.graphics.setColor(0.9, 0.95, 1.0, 1.0)
        love.graphics.circle("fill", cx, cy, 1)
    end)
    return canvas
end

-- Configure enhanced particle system with more dynamic behavior
local function createParticleSystem()
    if not (love and love.graphics and love.graphics.newParticleSystem) then
        return nil
    end
    local texture = createTrailTexture()
    local ps = love.graphics.newParticleSystem(texture, 400)
    ps:setParticleLifetime(0.4, 0.8)
    ps:setSpeed(60, 120)
    ps:setLinearAcceleration(-20, -60, 20, 40)
    ps:setLinearDamping(0.6)
    ps:setSizes(1.2, 0.8, 0.3, 0.05)
    ps:setSizeVariation(0.5)
    ps:setSpin(-2.0, 2.0, 0.4)
    ps:setSpread(math.rad(35))
    ps:setRelativeRotation(true)
    ps:setRotation(0, math_util.TAU)
    ps:setRadialAcceleration(-15, 15)
    ps:setTangentialAcceleration(-30, 30)
    ps:setEmissionRate(0)
    -- Enhanced color progression with more vibrant blues
    ps:setColors(
        0.6, 0.85, 1.0, 0.9,
        0.4, 0.7, 1.0, 0.7,
        0.2, 0.5, 0.95, 0.4,
        0.1, 0.3, 0.8, 0.1,
        0.05, 0.15, 0.5, 0
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

    -- Enhanced thrust strength calculation
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
        -- Add variation for more dynamic feel
        strength = strength * (0.9 + 0.1 * math.sin(love.timer.getTime() * 8))
    end
    
    self.thrustStrength = strength
end

-- Update the trail's emission and sync with player
function PlayerEngineTrail:update(dt)
    if not self.system then return end
    if self.player then self:updateFromPlayer() end

    local targetEmissionRate = 0
    
    if self.active and self.thrustStrength > 0 then
        -- Enhanced emission rate with more dramatic scaling
        local baseRate = 150
        local thrustMultiplier = 0.2 + 0.8 * (self.thrustStrength ^ 1.5)
        targetEmissionRate = baseRate * thrustMultiplier
        
        self.system:setDirection(self.direction)
        self.system:setPosition(self.position.x, self.position.y)
        
        -- Dynamic spread based on thrust
        local spread = math.rad(25 + 15 * (1 - self.thrustStrength))
        self.system:setSpread(spread)
        
        self.fadeTime = 0
        self.stopTimer = 0
    else
        -- Immediately stop emission when not thrusting
        targetEmissionRate = 0
        self.stopTimer = self.stopTimer + dt
    end
    
    -- Smooth emission rate transitions
    local lerpFactor = 1 - math.exp(-dt * 20)
    self.lastEmissionRate = self.lastEmissionRate + (targetEmissionRate - self.lastEmissionRate) * lerpFactor
    
    -- Force emission to zero if not actively thrusting
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
        -- Temporarily increase particle sizes for burst
        self.system:setSizes(1.5 * sizeMultiplier, 1.0 * sizeMultiplier, 0.4 * sizeMultiplier, 0.1)
        self.system:emit(count)
        -- Restore normal sizes
        self.system:setSizes(1.2, 0.8, 0.3, 0.05)
    else
        self.system:emit(count)
    end
end

function PlayerEngineTrail:draw()
    if not self.system then return end
    
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    
    -- Add slight color modulation based on thrust strength
    local intensity = 0.8 + 0.2 * self.thrustStrength
    love.graphics.setColor(intensity, intensity, intensity, 1)
    love.graphics.draw(self.system)
    
    love.graphics.pop()
end

return PlayerEngineTrail
