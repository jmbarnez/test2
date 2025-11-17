local math = math
local table_insert = table.insert

local PI = math.pi
local cos = math.cos
local sin = math.sin

local function clone_part(part)
    local copy = {}
    for key, value in pairs(part) do
        copy[key] = value
    end
    return copy
end

local function regular_polygon(sides, radius, offset_angle)
    local points = {}
    local step = (PI * 2) / sides
    local offset = offset_angle or 0

    for i = 0, sides - 1 do
        local angle = offset + step * i
        points[#points + 1] = cos(angle) * radius
        points[#points + 1] = sin(angle) * radius
    end

    return points
end

local function build_ring(sides, outer_radius, inner_radius, offset_angle)
    local outer = regular_polygon(sides, outer_radius, offset_angle)
    local inner = regular_polygon(sides, inner_radius, offset_angle)
    local points = {}

    for i = 1, #outer do
        points[#points + 1] = outer[i]
    end

    for i = #inner, 2, -2 do
        points[#points + 1] = inner[i - 1]
        points[#points + 1] = inner[i]
    end

    return points
end

local frame_outer = 230
local frame_inner = 184
local trim_outer = 176
local trim_inner = 154
local channel_outer = 168
local channel_inner = 146
local portal_radius = 140

local anchor_distance = (trim_inner + portal_radius) * 0.5

local parts = {}

table_insert(parts, {
    name = "outer_glow",
    type = "ellipse",
    mode = "fill",
    radius = frame_outer * 1.12,
    fill = "glow",
    alpha = 0.1,
    stroke = false,
    blend = "add",
})

table_insert(parts, {
    name = "frame_shell",
    type = "polygon",
    points = build_ring(48, frame_outer, frame_inner, PI / 48),
    fill = "frame",
    stroke = "trim",
    strokeWidth = 5,
})

table_insert(parts, {
    name = "frame_trim",
    type = "polygon",
    points = build_ring(48, trim_outer, trim_inner, 0),
    fill = "trim",
    alpha = 0.9,
    stroke = "accent",
    strokeWidth = 3,
})

table_insert(parts, {
    name = "energy_channel",
    type = "polygon",
    points = build_ring(48, channel_outer, channel_inner, PI / 48),
    fill = "conduit",
    stroke = "accent",
    strokeWidth = 2,
    alpha = 0.85,
    blend = "add",
})

local strut_shape = {
    -20, -frame_inner,
    20, -frame_inner,
    36, -channel_outer,
    16, -portal_radius * 0.98,
    -16, -portal_radius * 0.98,
    -36, -channel_outer,
}

for i = 0, 5 do
    local angle = i * (PI / 3)
    local strut = clone_part({
        name = "support_strut_" .. tostring(i + 1),
        type = "polygon",
        points = strut_shape,
        rotation = angle,
        fill = "frame",
        stroke = "trim",
        strokeWidth = 3,
    })

    table_insert(parts, strut)
end

local conduit_shape = {
    -10, -channel_outer,
    10, -channel_outer,
    24, -channel_inner,
    -24, -channel_inner,
}

for i = 0, 5 do
    local angle = (i * (PI / 3)) + (PI / 6)
    local conduit = clone_part({
        name = "conduit_arc_" .. tostring(i + 1),
        type = "polygon",
        points = conduit_shape,
        rotation = angle,
        fill = "conduit",
        stroke = "accent",
        strokeWidth = 2,
        alpha = 0.8,
        blend = "add",
    })

    table_insert(parts, conduit)
end

for i = 0, 5 do
    local angle = i * (PI / 3)
    local anchor_x = cos(angle) * anchor_distance
    local anchor_y = sin(angle) * anchor_distance

    table_insert(parts, {
        name = "anchor_glow_" .. tostring(i + 1),
        type = "ellipse",
        radiusX = 16,
        radiusY = 34,
        offset = { x = anchor_x, y = anchor_y },
        rotation = angle,
        fill = "accent",
        alpha = 0.78,
        stroke = "trim",
        strokeWidth = 2,
        blend = "add",
    })
end

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
            online = true,
            status = "online",
            energy = 1,
            energyMax = 1,
        },
        health = false,
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        mountRadius = frame_outer,
        hoverRadius = frame_outer,
        targetRadius = frame_outer,
        portalRadius = portal_radius,
        drawable = {
            type = "warpgate",
            defaultStrokeWidth = 3,
            colors = {
                frame = { 0.06, 0.08, 0.13, 1 },
                trim = { 0.28, 0.5, 0.92, 1 },
                glow = { 0.34, 0.8, 1.0, 0.82 },
                conduit = { 0.18, 0.62, 0.98, 1 },
                spine = { 0.09, 0.14, 0.2, 1 },
            accent = { 0.6, 0.92, 1.0, 0.9 },
                portal = { 0.26, 0.72, 1.0, 0.85 },
                portalRim = { 0.76, 0.98, 1.0, 1.0 },
                portalOffline = { 0.16, 0.24, 0.38, 0.88 },
                portalCore = { 0.44, 0.86, 1.0, 0.96 },
            },
            parts = parts,
        },
    },
}
