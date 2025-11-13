-- Engine Trail Effect Module
local math_util = require("src.util.math")

local EngineTrail = {}
EngineTrail.__index = EngineTrail

local unpack = (table and table.unpack) or unpack

local DEFAULT_TEXTURE_SIZE = 24
local DEFAULT_TEXTURE_LAYERS = {
    { radius = 12, color = { 0.1, 0.4, 1.0, 0.05 } },
    { radius = 10, color = { 0.15, 0.5, 1.0, 0.1 } },
    { radius = 8,  color = { 0.2, 0.6, 1.0, 0.15 } },
    { radius = 6,  color = { 0.3, 0.7, 1.0, 0.3 } },
    { radius = 4.5, color = { 0.4, 0.8, 1.0, 0.5 } },
    { radius = 3,  color = { 0.5, 0.85, 1.0, 0.7 } },
    { radius = 2,  color = { 0.7, 0.9, 1.0, 0.9 } },
    { radius = 1.2, color = { 0.85, 0.95, 1.0, 0.95 } },
    { radius = 0.8, color = { 1.0, 1.0, 1.0, 1.0 } },
}

local DEFAULT_PARTICLE_COLORS = {
    0.7, 0.9, 1.0, 1.0,
    0.5, 0.8, 1.0, 0.9,
    0.3, 0.65, 1.0, 0.7,
    0.2, 0.5, 0.95, 0.4,
    0.1, 0.35, 0.85, 0.15,
    0.05, 0.2, 0.6, 0,
}

local DEFAULT_DRAW_COLOR = { 0.95, 1.0, 1.0, 1.0 }
local DEFAULT_BLEND_MODE = "add"

-- Utility function to safely set a graphics canvas
local function withCanvas(canvas, drawFunc)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    drawFunc()
    love.graphics.setCanvas()
    love.graphics.pop()
end

local function normalize_layers(layers)
    if type(layers) ~= "table" or #layers == 0 then
        return DEFAULT_TEXTURE_LAYERS
    end
    return layers
end

local function createTrailTexture(textureSize, layers)
    textureSize = textureSize or DEFAULT_TEXTURE_SIZE
    local radiusCache = normalize_layers(layers)
    local canvas = love.graphics.newCanvas(textureSize, textureSize)
    withCanvas(canvas, function()
        local cx, cy = textureSize * 0.5, textureSize * 0.5
        for i = 1, #radiusCache do
            local layer = radiusCache[i]
            local color = layer.color or DEFAULT_DRAW_COLOR
            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            love.graphics.circle("fill", cx, cy, layer.radius or textureSize * 0.5)
        end
    end)
    local imageData = canvas:newImageData()
    local image = love.graphics.newImage(imageData)
    image:setFilter("linear", "linear")
    canvas:release()
    return image
end

local function unpack_range(range, defaultA, defaultB)
    if type(range) == "table" then
        return range[1] or defaultA, range[2] or range[1] or defaultB
    end
    return defaultA, defaultB
end

local function unpack_quad(range, d1, d2, d3, d4)
    if type(range) == "table" then
        return range[1] or d1, range[2] or d2, range[3] or d3, range[4] or d4
    end
    return d1, d2, d3, d4
end

-- Configure particle system with cinematic behavior
local function createParticleSystem(options)
    options = options or {}
    if not (love and love.graphics and love.graphics.newParticleSystem) then
        return nil
    end
    local texture = createTrailTexture(options.textureSize, options.textureLayers)
    local maxParticles = options.maxParticles or 600
    local ps = love.graphics.newParticleSystem(texture, maxParticles)

    local lifeMin, lifeMax = unpack_range(options.particleLifetime, 0.5, 1.2)
    ps:setParticleLifetime(lifeMin, lifeMax)

    local speedMin, speedMax = unpack_range(options.speed, 80, 180)
    ps:setSpeed(speedMin, speedMax)

    local lax, lay, ubx, uby = unpack_quad(options.linearAcceleration, -30, -80, 30, 60)
    ps:setLinearAcceleration(lax, lay, ubx, uby)

    ps:setLinearDamping(options.linearDamping or 0.8)

    local sizes = options.sizes or { 0.9, 0.6, 0.3, 0.08, 0 }
    ps:setSizes(unpack(sizes))
    ps:setSizeVariation(options.sizeVariation or 0.6)

    local spinMin, spinMax, spinVariation = unpack_quad(options.spin, -3.0, 3.0, 0.5, 0)
    ps:setSpin(spinMin, spinMax)
    if spinVariation and spinVariation ~= 0 then
        ps:setSpinVariation(spinVariation)
    end

    ps:setSpread(options.spread or math.rad(30))
    ps:setRelativeRotation(options.relativeRotation ~= false)
    local rotMin, rotMax = unpack_range(options.rotation, 0, math_util.TAU)
    ps:setRotation(rotMin, rotMax)

    local radialMin, radialMax = unpack_range(options.radialAcceleration, -25, 25)
    ps:setRadialAcceleration(radialMin, radialMax)

    local tangentialMin, tangentialMax = unpack_range(options.tangentialAcceleration, -45, 45)
    ps:setTangentialAcceleration(tangentialMin, tangentialMax)

    ps:setEmissionRate(0)

    local particleColors = options.particleColors or DEFAULT_PARTICLE_COLORS
    if particleColors then
        ps:setColors(unpack(particleColors))
    end

    ps:start()
    return ps
end

-- Instantiate a new engine trail object
function EngineTrail.new(options)
    local self = setmetatable({}, EngineTrail)
    self.options = options or {}
    self.system = createParticleSystem(self.options)
    self.active = false
    self.position = { x = 0, y = 0 }
    self.direction = 0
    self.thrustStrength = 0
    self.player = nil
    self.fadeTime = 0
    self.lastEmissionRate = 0
    self.stopTimer = 0
    self.drawColor = self.options.drawColor or DEFAULT_DRAW_COLOR
    self.blendMode = self.options.blendMode or DEFAULT_BLEND_MODE
    return self
end

function EngineTrail:attachPlayer(player)
    self.player = player
end

function EngineTrail:setActive(active)
    self.active = not not active
    if self.system and not self.active then
        self.fadeTime = 0.15
        self.stopTimer = 0
        self.system:setEmissionRate(0)
        self.lastEmissionRate = 0
    end
end

function EngineTrail:clear()
    if self.system then
        self.system:reset()
        self.system:setEmissionRate(0)
        self.lastEmissionRate = 0
        self.fadeTime = 0
        self.stopTimer = 0
    end
end

-- Align the particle system with the ship's rear and read thrust state
function EngineTrail:updateFromPlayer()
    if not (self.player and self.system) then return end

    local pos = self.player.position
    local rot = self.player.rotation or 0

    local thrustVectorX = self.player.engineTrailThrustVectorX or 0
    local thrustVectorY = self.player.engineTrailThrustVectorY or 0
    local thrustVectorMagnitudeSq = thrustVectorX * thrustVectorX + thrustVectorY * thrustVectorY

    -- Use thrust vector direction if available, otherwise use ship rotation
    if thrustVectorMagnitudeSq > 1e-6 then
        local thrustAngle = math.atan2(thrustVectorY, thrustVectorX)
        self.direction = thrustAngle + math.pi
    else
        self.direction = rot + math.pi
    end

    -- Calculate the position - always at ship center for enemies, offset for player
    local anchor = self.player.engineTrailAnchor
    if anchor and (anchor.x ~= 0 or anchor.y ~= 0) then
        -- Player with offset
        local offsetX = anchor.x or 0
        local offsetY = anchor.y or 0
        local sinR, cosR = math.sin(rot), math.cos(rot)
        self.position.x = pos.x + cosR * offsetX - sinR * offsetY
        self.position.y = pos.y + sinR * offsetX + cosR * offsetY
    elseif not anchor and self.player.thrusterOffset then
        -- Player without anchor but with thrusterOffset
        local offsetX = 0
        local offsetY = self.player.thrusterOffset or 24
        if self.player.hullSize then
            offsetY = self.player.hullSize.y or offsetY
        end
        local sinR, cosR = math.sin(rot), math.cos(rot)
        self.position.x = pos.x + cosR * offsetX - sinR * offsetY
        self.position.y = pos.y + sinR * offsetX + cosR * offsetY
    else
        -- Enemy ships - emit from center
        self.position.x = pos.x
        self.position.y = pos.y
    end

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

    -- Engine trail always points backward from ship rotation
    -- (direction was already set to rot + math.pi at the start of this function)

    self.thrustStrength = strength
end

-- Update the trail's emission and sync with ship state
function EngineTrail:update(dt)
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
function EngineTrail:emitBurst(count, sizeMultiplier)
    if not (self.system and count and count > 0) then return end

    if sizeMultiplier and sizeMultiplier > 1 then
        self.system:setSizes(1.0 * sizeMultiplier, 0.7 * sizeMultiplier, 0.35 * sizeMultiplier, 0.1)
        self.system:emit(count)
        self.system:setSizes(0.9, 0.6, 0.3, 0.08, 0)
    else
        self.system:emit(count)
    end
end

function EngineTrail:draw()
    if not self.system then return end

    love.graphics.push("all")
    love.graphics.setBlendMode(self.blendMode)

    -- Enhanced color modulation with brightness boost
    local baseColor = self.drawColor
    local brightness = 0.9 + 0.1 * self.thrustStrength
    local shimmer = 0.95 + 0.05 * math.sin(love.timer.getTime() * 8)
    local multiplier = brightness * shimmer
    local r = math.min(1, (baseColor[1] or 1) * multiplier)
    local g = math.min(1, (baseColor[2] or 1) * multiplier)
    local b = math.min(1, (baseColor[3] or 1) * multiplier)
    local a = baseColor[4] or 1
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(self.system)

    love.graphics.pop()
end

return EngineTrail
