local love = love

local PlayerEngineTrail = {}
PlayerEngineTrail.__index = PlayerEngineTrail

local function createParticleSystem()
    if not (love and love.graphics and love.graphics.newParticleSystem) then
        return nil
    end

    local texture = love.graphics.newCanvas(8, 8)
    love.graphics.push("all")
    love.graphics.setCanvas(texture)
    love.graphics.clear(0, 0, 0, 0)
    local function drawCircle(radius, r, g, b, a)
        love.graphics.setColor(r, g, b, a or 1)
        love.graphics.circle("fill", 4, 4, radius)
    end
    drawCircle(4, 0.4, 0.7, 1.0, 0.55)
    drawCircle(3, 0.5, 0.8, 1.0, 0.5)
    drawCircle(2, 0.6, 0.9, 1.0, 0.45)
    drawCircle(1, 0.7, 0.95, 1.0, 0.4)
    love.graphics.pop()
    love.graphics.setCanvas()

    local system = love.graphics.newParticleSystem(texture, 256)
    system:setParticleLifetime(0.45, 0.85)
    system:setSpeed(40, 85)
    system:setLinearAcceleration(-15, -40, 15, 30)
    system:setLinearDamping(0.3)
    system:setSizes(0.9, 0.55, 0.1)
    system:setSizeVariation(0.35)
    system:setSpin(-1.2, 1.2, 0.25)
    system:setSpread(math.rad(28))
    system:setRelativeRotation(true)
    system:setRotation(0, math.pi * 2)
    system:setRadialAcceleration(-10, 10)
    system:setTangentialAcceleration(-20, 20)
    system:setEmissionRate(0)
    system:setColors(
        0.45, 0.75, 1.0, 0.78,
        0.25, 0.55, 1.0, 0.48,
        0.1, 0.32, 0.9, 0.24,
        0.05, 0.18, 0.6, 0
    )
    system:start()
    return system
end

function PlayerEngineTrail.new()
    local self = setmetatable({}, PlayerEngineTrail)
    self.system = createParticleSystem()
    self.active = false
    self.position = { x = 0, y = 0 }
    self.direction = 0
    self.thrustStrength = 0
    self.player = nil
    return self
end

function PlayerEngineTrail:attachPlayer(player)
    self.player = player
end

function PlayerEngineTrail:setActive(active)
    self.active = active and true or false
    if not self.system then
        return
    end
    if not self.active then
        self.system:setEmissionRate(0)
    end
end

function PlayerEngineTrail:clear()
    if self.system then
        self.system:reset()
        self.system:setEmissionRate(0)
    end
end

function PlayerEngineTrail:updateFromPlayer()
    if not (self.player and self.system) then
        return
    end

    local position = self.player.position
    local rotation = self.player.rotation or 0

    self.direction = rotation + math.pi

    local anchor = self.player.engineTrailAnchor
    local offsetX, offsetY
    if anchor then
        offsetX = anchor.x or 0
        offsetY = anchor.y or 0
    else
        offsetX = 0
        offsetY = self.player.thrusterOffset or 24
        if self.player.hullSize then
            offsetY = (self.player.hullSize.y or offsetY)
        end
    end

    local sinR = math.sin(rotation)
    local cosR = math.cos(rotation)
    local rearX = position.x + cosR * offsetX - sinR * offsetY
    local rearY = position.y + sinR * offsetX + cosR * offsetY

    self.position = self.position or { x = 0, y = 0 }
    self.position.x = rearX
    self.position.y = rearY

    local thrusting = self.player.isThrusting
    local thrustForce = self.player.currentThrust or 0
    local maxThrust = self.player.maxThrust or thrustForce
    local strength = 0

    if thrusting then
        if maxThrust and maxThrust > 0 then
            strength = math.min(thrustForce / maxThrust, 1)
        else
            strength = thrustForce > 0 and 1 or 0.6
        end
    end

    self.thrustStrength = strength
end

function PlayerEngineTrail:update(dt)
    if not self.system then
        return
    end

    if self.player then
        self:updateFromPlayer()
    end

    local emissionRate = 0
    if self.active then
        emissionRate = 110 * (0.35 + 0.65 * self.thrustStrength)
        self.system:setDirection(self.direction)
        self.system:setPosition(self.position.x, self.position.y)
    end

    self.system:setEmissionRate(emissionRate)
    self.system:update(dt)
end

function PlayerEngineTrail:emitBurst(count)
    if not (self.system and count and count > 0) then
        return
    end
    self.system:emit(count)
end

function PlayerEngineTrail:draw()
    if not self.system then
        return
    end

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.draw(self.system)
    love.graphics.pop()
end

return PlayerEngineTrail
