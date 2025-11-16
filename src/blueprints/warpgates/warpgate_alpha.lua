local math = math

local function regular_polygon(sides, radius, offset_angle)
    local points = {}
    local step = (math.pi * 2) / sides
    local offset = offset_angle or 0

    for i = 0, sides - 1 do
        local angle = offset + step * i
        points[#points + 1] = math.cos(angle) * radius
        points[#points + 1] = math.sin(angle) * radius
    end

    return points
end

local SCALE = 0.58

local outer_radius = 340 * SCALE
local mid_radius = 260 * SCALE
local inner_radius = 190 * SCALE
local spine_radius = 420 * SCALE
local core_radius = 150 * SCALE

local outer_ring = regular_polygon(48, outer_radius)
local mid_ring = regular_polygon(24, mid_radius, math.pi / 24)
local inner_ring = regular_polygon(12, inner_radius)
local spine_points = regular_polygon(6, spine_radius, math.pi / 6)

local spoke = {
    -28, -spine_radius,
    28, -spine_radius,
    42, -inner_radius,
    -42, -inner_radius,
}

local conduit = {
    -18, -inner_radius,
    18, -inner_radius,
    36, -core_radius * 0.65,
    -36, -core_radius * 0.65,
}

return {
    category = "warpgates",
    id = "warpgate_alpha",
    name = "Asterion Warpgate",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        warpgate = {
            gateId = "alpha",
            online = false,
            energy = 0,
            status = "offline",
        },
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        mountRadius = spine_radius,
        portalRadius = core_radius * 0.9,
        drawable = {
            type = "warpgate",
            defaultStrokeWidth = 3,
            colors = {
                frame = { 0.08, 0.13, 0.2, 1 },
                trim = { 0.28, 0.42, 0.78, 1 },
                glow = { 0.36, 0.86, 1.0, 0.9 },
                conduit = { 0.18, 0.6, 0.92, 1 },
                spine = { 0.12, 0.16, 0.24, 1 },
                accent = { 0.62, 0.92, 1.0, 0.85 },
                portal = { 0.3, 0.86, 1.0, 0.9 },
                portalRim = { 0.78, 0.98, 1.0, 1.0 },
                portalOffline = { 0.12, 0.18, 0.3, 0.92 },
                portalCore = { 0.42, 0.74, 1.0, 0.95 },
            },
            parts = {
                {
                    name = "support_spine",
                    type = "polygon",
                    points = spine_points,
                    fill = "spine",
                    stroke = "trim",
                    strokeWidth = 6,
                },
                {
                    name = "outer_ring",
                    type = "polygon",
                    points = outer_ring,
                    fill = "frame",
                    stroke = "trim",
                    strokeWidth = 6,
                },
                {
                    name = "mid_ring",
                    type = "polygon",
                    points = mid_ring,
                    fill = "frame",
                    stroke = "trim",
                    strokeWidth = 4,
                },
                {
                    name = "inner_ring",
                    type = "polygon",
                    points = inner_ring,
                    fill = "conduit",
                    stroke = "accent",
                    strokeWidth = 3,
                    blend = "add",
                },
                {
                    name = "spokes",
                    type = "polygon",
                    points = spoke,
                    mirror = true,
                    rotations = 3,
                    fill = "frame",
                    stroke = "trim",
                    strokeWidth = 3,
                },
                {
                    name = "conduits",
                    type = "polygon",
                    points = conduit,
                    mirror = true,
                    rotations = 6,
                    fill = "conduit",
                    stroke = "accent",
                    strokeWidth = 2,
                    blend = "add",
                },
            },
        },
    },
}
