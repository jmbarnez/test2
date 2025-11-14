local math_util = require("src.util.math")

---@diagnostic disable-next-line: undefined-global
local love = love

local Universe = {}

local function connect_sector_nodes(a, b, linkType)
    linkType = linkType or "sector"
    a.links = a.links or {}
    b.links = b.links or {}
    a.links[#a.links + 1] = {
        targetId = b.id,
        type = linkType,
    }
    b.links[#b.links + 1] = {
        targetId = a.id,
        type = linkType,
    }
end

local function connect_galaxies(a, b)
    if not (a and b) then
        return
    end

    a.links = a.links or {}
    b.links = b.links or {}

    local existingA = {}
    for i = 1, #a.links do
        local link = a.links[i]
        if link and link.galaxyId then
            existingA[link.galaxyId] = true
        end
    end

    if not existingA[b.id] then
        a.links[#a.links + 1] = {
            galaxyId = b.id,
        }
    end

    local existingB = {}
    for i = 1, #b.links do
        local link = b.links[i]
        if link and link.galaxyId then
            existingB[link.galaxyId] = true
        end
    end

    if not existingB[a.id] then
        b.links[#b.links + 1] = {
            galaxyId = a.id,
        }
    end

    local sectorsA = a.sectors or {}
    local sectorsB = b.sectors or {}
    if #sectorsA == 0 or #sectorsB == 0 then
        return
    end

    local sectorA = sectorsA[love.math.random(1, #sectorsA)]
    local sectorB = sectorsB[love.math.random(1, #sectorsB)]

    if not (sectorA and sectorB) then
        return
    end

    sectorA.isGalaxyGate = true
    sectorB.isGalaxyGate = true

    connect_sector_nodes(sectorA, sectorB, "galaxy")
end

function Universe.generate(config)
    config = config or {}

    local galaxyCount = config.galaxy_count or 3
    if galaxyCount < 1 then
        galaxyCount = 1
    end

    local sectorRange = config.sectors_per_galaxy or { min = 10, max = 18 }

    local galaxies = {}
    local galaxiesById = {}
    local sectorsById = {}

    for gi = 1, galaxyCount do
        local galaxyId = "galaxy_" .. gi
        local galaxy = {
            id = galaxyId,
            name = "Galaxy " .. gi,
            index = gi,
            sectors = {},
            links = {},
        }

        local sectorCount = math_util.random_int_range(sectorRange, 12)
        if sectorCount < 1 then
            sectorCount = 1
        end

        local minX, maxX, minY, maxY

        local angleOffset = love.math.random() * math_util.TAU
        local baseRadius = 900 + love.math.random() * 600

        for si = 1, sectorCount do
            local sectorId = galaxyId .. ":sector_" .. si
            local angle = angleOffset + (si / sectorCount) * math_util.TAU + (love.math.random() - 0.5) * 0.5
            local radius = baseRadius * (0.35 + love.math.random() * 0.7)
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius

            if not minX or x < minX then
                minX = x
            end
            if not maxX or x > maxX then
                maxX = x
            end
            if not minY or y < minY then
                minY = y
            end
            if not maxY or y > maxY then
                maxY = y
            end

            local sector = {
                id = sectorId,
                name = "Sector " .. si,
                galaxyId = galaxyId,
                index = si,
                x = x,
                y = y,
                links = {},
            }

            galaxy.sectors[#galaxy.sectors + 1] = sector
            sectorsById[sectorId] = sector
        end

        minX = minX or 0
        minY = minY or 0
        maxX = maxX or 0
        maxY = maxY or 0

        galaxy.bounds = {
            x = minX - 400,
            y = minY - 400,
            width = (maxX - minX) + 800,
            height = (maxY - minY) + 800,
        }

        galaxies[#galaxies + 1] = galaxy
        galaxiesById[galaxyId] = galaxy
    end

    for gi = 1, #galaxies do
        local galaxy = galaxies[gi]
        local sectors = galaxy.sectors or {}

        for i = 2, #sectors do
            local j = love.math.random(1, i - 1)
            local a = sectors[i]
            local b = sectors[j]
            if a and b then
                connect_sector_nodes(a, b, "sector")
            end
        end

        local extra = math.floor(#sectors * 0.4)
        local attempts = 0
        while extra > 0 and attempts < #sectors * 8 do
            local ai = love.math.random(1, #sectors)
            local bi = love.math.random(1, #sectors)
            if ai ~= bi then
                local a = sectors[ai]
                local b = sectors[bi]
                local exists = false

                if a and b then
                    local links = a.links or {}
                    for li = 1, #links do
                        local link = links[li]
                        if link and link.targetId == b.id and link.type == "sector" then
                            exists = true
                            break
                        end
                    end

                    if not exists then
                        connect_sector_nodes(a, b, "sector")
                        extra = extra - 1
                    end
                end
            end

            attempts = attempts + 1
        end
    end

    local minGX, maxGX, minGY, maxGY
    local radius = 4000

    for i = 1, #galaxies do
        local angle = ((i - 1) / math.max(1, #galaxies)) * math_util.TAU
        local gr = radius * (0.35 + love.math.random() * 0.2)
        local gx = math.cos(angle) * gr
        local gy = math.sin(angle) * gr

        local galaxy = galaxies[i]
        galaxy.universeX = gx
        galaxy.universeY = gy

        if not minGX or gx < minGX then
            minGX = gx
        end
        if not maxGX or gx > maxGX then
            maxGX = gx
        end
        if not minGY or gy < minGY then
            minGY = gy
        end
        if not maxGY or gy > maxGY then
            maxGY = gy
        end
    end

    minGX = minGX or 0
    minGY = minGY or 0
    maxGX = maxGX or 0
    maxGY = maxGY or 0

    local universeBounds = {
        x = minGX - 1200,
        y = minGY - 1200,
        width = (maxGX - minGX) + 2400,
        height = (maxGY - minGY) + 2400,
    }

    if #galaxies >= 2 then
        for i = 1, #galaxies - 1 do
            connect_galaxies(galaxies[i], galaxies[i + 1])
        end
        if #galaxies >= 3 then
            connect_galaxies(galaxies[1], galaxies[#galaxies])
        end
    end

    local homeGalaxy = galaxies[1]
    local homeSector = homeGalaxy and homeGalaxy.sectors and homeGalaxy.sectors[1] or nil

    local universe = {
        galaxies = galaxies,
        galaxiesById = galaxiesById,
        sectorsById = sectorsById,
        bounds = universeBounds,
        homeGalaxyId = homeGalaxy and homeGalaxy.id or nil,
        homeSectorId = homeSector and homeSector.id or nil,
    }

    universe.currentGalaxyId = universe.homeGalaxyId
    universe.currentSectorId = universe.homeSectorId

    return universe
end

function Universe.getActiveGalaxy(universe, currentGalaxyId)
    if not universe then
        return nil
    end

    local id = currentGalaxyId or universe.currentGalaxyId or universe.homeGalaxyId
    local galaxy

    local byId = universe.galaxiesById
    if byId and id then
        galaxy = byId[id]
    end

    if not galaxy then
        local list = universe.galaxies
        if list and list[1] then
            galaxy = list[1]
        end
    end

    return galaxy
end

function Universe.getGalaxyBounds(universe, currentGalaxyId)
    local galaxy = Universe.getActiveGalaxy(universe, currentGalaxyId)
    if not galaxy then
        return nil
    end

    return galaxy.bounds
end

function Universe.getUniverseBounds(universe)
    if not universe then
        return nil
    end

    return universe.bounds
end

return Universe
