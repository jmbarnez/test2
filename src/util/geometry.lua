local geometry = {}

---Resolves a rectangle table into numeric coordinates and dimensions.
---Accepts {x, y, width, height}, {x, y, w, h}, or array-style {x, y, width, height}.
---@param rect table|nil
---@return number x
---@return number y
---@return number width
---@return number height
function geometry.resolve_rect(rect)
    if rect == nil then
        return 0, 0, 0, 0
    end

    local x = rect.x or rect[1] or 0
    local y = rect.y or rect[2] or 0
    local width = rect.width or rect.w or rect[3] or 0
    local height = rect.height or rect.h or rect[4] or 0

    return x, y, width, height
end

---Determines whether a point lies within a rectangle.
---@param px number
---@param py number
---@param rect table|nil
---@return boolean
function geometry.point_in_rect(px, py, rect)
    if rect == nil then
        return false
    end

    local x, y, width, height = geometry.resolve_rect(rect)
    return px >= x and px <= x + width and py >= y and py <= y + height
end

return geometry
