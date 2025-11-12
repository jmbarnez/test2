---@diagnostic disable: undefined-global

local ship_renderer = require("src.renderers.ship")

local station_renderer = {}

---Draws a station entity using shared ship body rendering while allowing
---station-specific overlays in the future.
---@param entity table
---@param context table|nil
function station_renderer.draw(entity, context)
    if not ship_renderer.draw_body(entity, context) then
        return
    end

    -- Stations currently reuse ship geometry without extra overlays, but this
    -- renderer exists so station-specific UI can be added without affecting ships.
end

return station_renderer
