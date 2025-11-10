---@diagnostic disable: undefined-global

local Starfield = require("src.states.gameplay.starfield")

local love = love

local View = {}

function View.initialize(state)
    state.viewport = {
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight(),
    }

    local constants = require("src.constants.game")
    local viewConfig = constants.view or {}

    state.camera = {
        x = 0,
        y = 0,
        width = state.viewport.width,
        height = state.viewport.height,
        zoom = viewConfig.default_zoom or 1,
    }

    Starfield.initialize(state)
end

local PlayerManager = require("src.player.manager")

local function get_local_player(state)
    return PlayerManager.getCurrentShip(state)
end

function View.updateCamera(state)
    local player = get_local_player(state)
    if not (player and state.camera and state.viewport and state.worldBounds) then
        return
    end

    local cam = state.camera
    local zoom = cam.zoom or 1
    cam.width = state.viewport.width / zoom
    cam.height = state.viewport.height / zoom

    local px = player.position.x
    local py = player.position.y
    cam.x = px - cam.width * 0.5
    cam.y = py - cam.height * 0.5

    local bounds = state.worldBounds
    local minX = bounds.x
    local minY = bounds.y
    local maxX = bounds.x + bounds.width - cam.width
    local maxY = bounds.y + bounds.height - cam.height

    if bounds.width <= cam.width then
        cam.x = bounds.x + (bounds.width - cam.width) / 2
    else
        cam.x = math.max(minX, math.min(maxX, cam.x))
    end

    if bounds.height <= cam.height then
        cam.y = bounds.y + (bounds.height - cam.height) / 2
    else
        cam.y = math.max(minY, math.min(maxY, cam.y))
    end
end

function View.resize(state, w, h)
    state.viewport = state.viewport or {}
    state.viewport.width = w
    state.viewport.height = h

    if state.camera then
        state.camera.width = w
        state.camera.height = h
    end

    View.updateCamera(state)
end

function View.drawBackground(state)
    Starfield.draw(state)
end

function View.getStarfield()
    return Starfield
end

function View.teardown(state)
    state.camera = nil
    state.viewport = nil
    state.starLayers = nil
end

return View
