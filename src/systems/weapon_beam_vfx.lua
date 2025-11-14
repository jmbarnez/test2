---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local vector = require("src.util.vector")

local love = love
local graphics = love and love.graphics
local timer = love and love.timer

local SPARK_VELOCITY_DAMPING = 0.88

---@class WeaponBeamVFXContext
---@field state table|nil

return function(context)
    context = context or {}

    return tiny.processingSystem {
        filter = tiny.requireAll("weapon"),

        init = function(self)
            self.active_beams = {}
            self.beamImpacts = {}
        end,

        update = function(self, dt)
            local beams = self.active_beams
            for i = #beams, 1, -1 do
                beams[i] = nil
            end

            local beamImpacts = self.beamImpacts
            for index = #beamImpacts, 1, -1 do
                local spark = beamImpacts[index]
                spark.lifetime = (spark.lifetime or 0) - dt
                if spark.lifetime <= 0 then
                    beamImpacts[index] = beamImpacts[#beamImpacts]
                    beamImpacts[#beamImpacts] = nil
                else
                    spark.x = (spark.x or 0) + (spark.vx or 0) * dt
                    spark.y = (spark.y or 0) + (spark.vy or 0) * dt
                    spark.vx = (spark.vx or 0) * SPARK_VELOCITY_DAMPING
                    spark.vy = (spark.vy or 0) * SPARK_VELOCITY_DAMPING
                    if spark.maxLifetime and spark.maxLifetime > 0 then
                        local ratio = math.max(0, spark.lifetime / spark.maxLifetime)
                        if spark.baseSize then
                            spark.size = spark.baseSize * ratio
                        end
                        if spark.color then
                            spark.color[4] = ratio
                        end
                    end
                end
            end
        end,

        process = function(self, entity, _)
            local weapon = entity.weapon
            if not weapon then
                return
            end

            if weapon._beamSegments and #weapon._beamSegments > 0 then
                local beams = self.active_beams
                for i = 1, #weapon._beamSegments do
                    beams[#beams + 1] = weapon._beamSegments[i]
                end
                weapon._beamSegments = nil
            end

            if weapon._beamImpactEvents and #weapon._beamImpactEvents > 0 then
                local impacts = self.beamImpacts
                for i = 1, #weapon._beamImpactEvents do
                    local impact = weapon._beamImpactEvents[i]
                    local color = impact.color or { 1, 1, 1, 1 }
                    local spark = {
                        x = impact.x or 0,
                        y = impact.y or 0,
                        vx = impact.vx or (impact.dirX or 0) * (impact.speed or 0),
                        vy = impact.vy or (impact.dirY or 0) * (impact.speed or 0),
                        color = { color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 },
                        baseSize = impact.baseSize or impact.size or 4,
                        size = impact.size or impact.baseSize or 4,
                        lifetime = impact.lifetime or 0.18,
                        maxLifetime = impact.lifetime or impact.maxLifetime or 0.18,
                    }
                    impacts[#impacts + 1] = spark
                end
                weapon._beamImpactEvents = nil
            end
        end,

        draw = function(self)
            if not graphics then
                return
            end
            local beams = self.active_beams
            if not beams or #beams == 0 then
                return
            end

            graphics.push("all")
            graphics.setBlendMode("add")

            for i = 1, #beams do
                local beam = beams[i]
                local dx = beam.x2 - beam.x1
                local dy = beam.y2 - beam.y1
                local length = vector.length(dx, dy)
                local angle = math.atan2(dy, dx)

                graphics.push()
                graphics.translate(beam.x1, beam.y1)
                graphics.rotate(angle)

                local baseWidth = beam.width or 3
                local glow = beam.glow or { 1.0, 0.8, 0.6 }
                local color = beam.color or { 0.6, 0.85, 1.0 }
                local beamStyle = beam.style or "straight"

                if beamStyle == "lightning" then
                    local segments = math.max(18, math.floor(length / 10))
                    local points = {}

                    local t = timer and timer.getTime and timer.getTime() or 0

                    points[1] = { x = 0, y = 0 }

                    for j = 1, segments - 1 do
                        local progress = j / segments
                        local centralFactor = 1 - math.min(1, math.abs(progress - 0.5) * 1.4)
                        local baseDev = baseWidth * (4.0 + math.random() * 3.0)
                        local timeWobble = math.sin(t * 18 + j * 1.9) * baseWidth * 1.4
                        local maxDeviation = (baseDev + math.abs(timeWobble)) * centralFactor

                        local xJitter = (math.random() - 0.5) * baseWidth * 1.3
                        local x = progress * length + xJitter
                        local y = (math.random() - 0.5) * maxDeviation

                        points[j + 1] = { x = x, y = y }
                    end

                    points[segments + 1] = { x = length, y = 0 }

                    local glowWidth = math.max(baseWidth * 2.8, baseWidth + 3.2)
                    graphics.setLineWidth(glowWidth)
                    graphics.setColor(glow[1], glow[2], glow[3], 0.24)
                    for j = 1, #points - 1 do
                        graphics.line(points[j].x, points[j].y, points[j + 1].x, points[j + 1].y)
                    end

                    local coreWidth = math.max(baseWidth * 1.0, 1.4)
                    graphics.setLineWidth(coreWidth)
                    graphics.setColor(color[1], color[2], color[3], 0.95)
                    for j = 1, #points - 1 do
                        graphics.line(points[j].x, points[j].y, points[j + 1].x, points[j + 1].y)
                    end

                    local highlightWidth = math.max(coreWidth * 0.5, 0.7)
                    graphics.setLineWidth(highlightWidth)
                    graphics.setColor(1.0, 1.0, 1.0, 0.8)
                    for j = 1, #points - 1 do
                        graphics.line(points[j].x, points[j].y, points[j + 1].x, points[j + 1].y)
                    end

                    if length > 60 then
                        local maxBranches = (length > 160) and 2 or 1
                        for _ = 1, maxBranches do
                            if math.random() < 0.9 then
                                local branchPoint = math.random(2, #points - 1)
                                local branch = points[branchPoint]

                                local branchLength = baseWidth * (4.0 + math.random() * 7)
                                local branchAngle = (math.random() - 0.5) * math.pi * 1.1
                                local branchEndX = branch.x + math.cos(branchAngle) * branchLength
                                local branchEndY = branch.y + math.sin(branchAngle) * branchLength

                                graphics.setLineWidth(coreWidth * 0.7)
                                graphics.setColor(color[1], color[2], color[3], 0.7)
                                graphics.line(branch.x, branch.y, branchEndX, branchEndY)

                                graphics.setLineWidth(highlightWidth * 0.55)
                                graphics.setColor(1.0, 1.0, 1.0, 0.5)
                                graphics.line(branch.x, branch.y, branchEndX, branchEndY)
                            end
                        end
                    end
                else
                    local glowWidth = math.max(baseWidth * 1.5, baseWidth + 1.2)
                    local coreWidth = math.max(baseWidth * 0.55, 0.45)
                    local highlightWidth = math.max(coreWidth * 0.45, 0.22)

                    local halfGlow = glowWidth * 0.5
                    local halfCore = coreWidth * 0.5
                    local halfHighlight = highlightWidth * 0.5

                    graphics.setColor(glow[1], glow[2], glow[3], 0.28)
                    graphics.rectangle("fill", 0, -halfGlow, length, glowWidth)

                    graphics.setColor(color[1], color[2], color[3], 0.95)
                    graphics.rectangle("fill", 0, -halfCore, length, coreWidth)

                    graphics.setColor(1.0, 1.0, 1.0, 0.6)
                    graphics.rectangle("fill", 0, -halfHighlight, length, highlightWidth)
                end

                graphics.pop()
            end

            graphics.pop()
        end,
    }
end
