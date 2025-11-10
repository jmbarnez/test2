local theme = require("src.ui.theme")

---@diagnostic disable-next-line: undefined-global
local love = love

local tooltip = {}

local set_color = theme.utils.set_color

local current_request = nil
local MAX_APPEND_DEPTH = 8

local function wrap_text(font, text, max_width)
    if not (font and text) then
        return {}
    end

    local words = {}
    for word in tostring(text):gmatch("%S+") do
        words[#words + 1] = word
    end

    if #words == 0 then
        return { tostring(text) }
    end

    local lines = {}
    local current_line = ""

    for _, word in ipairs(words) do
        local test_line = current_line == "" and word or (current_line .. " " .. word)
        if font:getWidth(test_line) <= max_width or current_line == "" then
            current_line = test_line
        else
            lines[#lines + 1] = current_line
            current_line = word
        end
    end

    if current_line ~= "" then
        lines[#lines + 1] = current_line
    end

    if #lines == 0 then
        lines[1] = tostring(text)
    end

    return lines
end

function tooltip.begin_frame()
    current_request = nil
end

function tooltip.request(data)
    if type(data) ~= "table" then
        return
    end

    if not current_request then
        current_request = data
    end
end

function tooltip.draw(mouse_x, mouse_y, fonts)
    if not current_request then
        return
    end

    fonts = fonts or theme.get_fonts()
    local colors = theme.colors.tooltip or {}
    local spacing = theme.spacing or {}

    local padding = spacing.tooltip_padding or 8
    local max_width = spacing.tooltip_max_width or 240
    local offset_x = spacing.tooltip_offset_x or 18
    local offset_y = spacing.tooltip_offset_y or 16
    local shadow_offset = spacing.tooltip_shadow_offset or 4
    local line_spacing = spacing.tooltip_line_spacing or 2
    local corner_radius = spacing.window_corner_radius or 2

    local heading_font = fonts.body or love.graphics.getFont()
    local body_font = fonts.small or heading_font
    local content_width_limit = max_width - padding * 2

    local entries = {}

    local function append_wrapped(text, font, color, visited, depth)
        if not text or not font then
            return
        end

        visited = visited or {}
        depth = (depth or 0) + 1
        if depth > MAX_APPEND_DEPTH then
            return
        end

        local text_type = type(text)
        if text_type == "table" then
            if visited[text] then
                return
            end
            visited[text] = true

            local had_entry = false
            for _, part in ipairs(text) do
                had_entry = true
                append_wrapped(part, font, color, visited, depth)
            end

            if not had_entry then
                local fallback = text.text or text.label or text.name or text.description
                if fallback then
                    append_wrapped(fallback, font, color, visited, depth)
                else
                    append_wrapped(tostring(text), font, color, visited, depth)
                end
            end
            return
        end

        local str = tostring(text)
        if str == "" then
            return
        end

        local wrapped = wrap_text(font, str, content_width_limit)
        for _, line in ipairs(wrapped) do
            if type(line) == "string" and line:match("%S") then
                entries[#entries + 1] = {
                    text = line,
                    font = font,
                    color = color,
                }
            end
        end
    end

    if current_request.heading then
        append_wrapped(current_request.heading, heading_font, colors.heading or colors.text or { 1, 1, 1, 1 })
        if (current_request.body and #current_request.body > 0) or (current_request.description and current_request.description ~= "") then
            entries[#entries + 1] = { spacer = true }
        end
    end

    if type(current_request.body) == "table" then
        for index, line in ipairs(current_request.body) do
            append_wrapped(line, body_font, colors.text or { 0.85, 0.85, 0.9, 1 })
            if index < #current_request.body then
                entries[#entries + 1] = { spacer = true }
            end
        end
    end

    if current_request.description and current_request.description ~= "" then
        if #entries > 0 then
            entries[#entries + 1] = { spacer = true }
        end
        append_wrapped(current_request.description, body_font, colors.text or { 0.78, 0.78, 0.82, 1 })
    end

    if #entries == 0 then
        current_request = nil
        return
    end

    local total_height = padding * 2
    local max_line_width = 0
    local line_count = 0

    for _, entry in ipairs(entries) do
        if entry.spacer then
            total_height = total_height + line_spacing
        else
            if line_count > 0 then
                total_height = total_height + line_spacing
            end
            local font = entry.font
            total_height = total_height + font:getHeight()
            local line_width = font:getWidth(entry.text)
            if line_width > max_line_width then
                max_line_width = line_width
            end
            line_count = line_count + 1
        end
    end

    local measured_width = padding * 2 + max_line_width
    if measured_width > max_width then
        measured_width = max_width
    end
    local total_width = math.max(measured_width, padding * 2 + 10)

    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight()

    local x = (mouse_x or 0) + offset_x
    local y = (mouse_y or 0) + offset_y

    if x + total_width > screen_w then
        x = math.max(offset_x, (mouse_x or screen_w) - total_width - offset_x)
    end
    if y + total_height > screen_h then
        y = math.max(offset_y, (mouse_y or screen_h) - total_height - offset_y)
    end

    love.graphics.push("all")
    love.graphics.origin()

    set_color(colors.shadow or { 0, 0, 0, 0.4 })
    love.graphics.rectangle("fill", x + shadow_offset, y + shadow_offset, total_width, total_height, corner_radius + 2, corner_radius + 2)

    set_color(colors.background or { 0.1, 0.1, 0.1, 0.95 })
    love.graphics.rectangle("fill", x, y, total_width, total_height, corner_radius, corner_radius)

    set_color(colors.border or { 0.2, 0.5, 0.7, 0.9 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, total_width - 1, total_height - 1, corner_radius, corner_radius)

    local text_x = x + padding
    local text_y = y + padding
    local first_line = true

    for _, entry in ipairs(entries) do
        if entry.spacer then
            text_y = text_y + line_spacing
        else
            if not first_line then
                text_y = text_y + line_spacing
            end
            love.graphics.setFont(entry.font)
            set_color(entry.color or colors.text or { 1, 1, 1, 1 })
            love.graphics.print(entry.text, text_x, text_y)
            text_y = text_y + entry.font:getHeight()
            first_line = false
        end
    end

    love.graphics.pop()

    current_request = nil
end

return tooltip
