local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local UIStateManager = require("src.ui.state_manager")
local UIButton = require("src.ui.components.button")
local PlayerManager = require("src.player.manager")
local math_util = require("src.util.math")
local Universe = require("src.states.gameplay.universe")

---@diagnostic disable-next-line: undefined-global
local love = love

local map_window = {}

local function point_in_rect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.width
        and py >= rect.y and py <= rect.y + rect.height
end

local function get_world_bounds(context)
    if context and context.worldBounds then
        return context.worldBounds
    end
    if context and context.world and context.world.bounds then
        return context.world.bounds
    end
    return nil
end

local function reset_view(state, context, bounds)
    bounds = bounds or get_world_bounds(context)
    if not bounds then
        return
    end

	local mode = state and state.mode or "sector"

	if mode == "sector" then
		local player = PlayerManager.resolveLocalPlayer(context)
		if player and player.position then
			state.centerX = player.position.x
			state.centerY = player.position.y
		else
			state.centerX = bounds.x + bounds.width * 0.5
			state.centerY = bounds.y + bounds.height * 0.5
		end
	else
		state.centerX = bounds.x + bounds.width * 0.5
		state.centerY = bounds.y + bounds.height * 0.5
	end

	state.zoom = 1
end

local function world_to_screen(wx, wy, rect, scale, centerX, centerY)
    local half_width = rect.width * 0.5
    local half_height = rect.height * 0.5

    local dx = (wx - centerX) * scale
    local dy = (wy - centerY) * scale

    return rect.x + half_width + dx, rect.y + half_height + dy
end

local function clamp_center(state, bounds, rect, scale)
    if not (state and bounds and rect and scale) then
        return
    end

    local half_view_world_width = (rect.width * 0.5) / scale
    local half_view_world_height = (rect.height * 0.5) / scale

    half_view_world_width = math.min(half_view_world_width, bounds.width * 0.5)
    half_view_world_height = math.min(half_view_world_height, bounds.height * 0.5)

    state.centerX = math_util.clamp(state.centerX, bounds.x + half_view_world_width, bounds.x + bounds.width - half_view_world_width)
    state.centerY = math_util.clamp(state.centerY, bounds.y + half_view_world_height, bounds.y + bounds.height - half_view_world_height)
end

local function resolve_universe(context)
	if not context then
		return nil
	end

	local universe = context.universe
	if type(universe) == "table" then
		return universe
	end

	if type(context.state) == "table" and type(context.state.universe) == "table" then
		return context.state.universe
	end

	return nil
end

local function get_mode_bounds(context, state)
	local mode = state and state.mode or "sector"
	if mode == "galaxy" then
		local universe = resolve_universe(context)
		if universe then
			return Universe.getGalaxyBounds(universe, universe.currentGalaxyId)
		end
	elseif mode == "universe" then
		local universe = resolve_universe(context)
		if universe then
			return Universe.getUniverseBounds(universe)
		end
	end

	return get_world_bounds(context)
end

local function get_window_rect(screen_width, screen_height)
    local spacing = theme.get_spacing()
    local margin = spacing and spacing.window_margin or 48

    local rect_width = math.max(420, screen_width - margin * 2)
    local rect_height = math.max(320, screen_height - margin * 2)

    return {
        x = math.max(0, (screen_width - rect_width) * 0.5),
        y = math.max(0, (screen_height - rect_height) * 0.5),
        width = rect_width,
        height = rect_height,
    }
end

local function get_map_rect(content)
    if not content then
        return nil
    end

    return {
        x = content.x,
        y = content.y,
        width = math.max(1, content.width),
        height = math.max(1, content.height),
    }
end

local function draw_legend(rect, fonts, colors)
    local legendItems = {
        { label = "You", color = colors.player },
        { label = "Allies", color = colors.teammate },
        { label = "Stations", color = colors.station },
        { label = "Enemies", color = colors.enemy },
        { label = "Asteroids", color = colors.asteroid },
    }

    local controls = {
        "Drag to pan",
        "Scroll to zoom",
    }

    local spacing = theme.get_spacing() or {}
    local panelMargin = spacing.window_padding or 24

    local padding = 18
    local swatchSize = 12
    local swatchSpacing = 12
    local rowSpacing = 6
    local headingSpacing = 8
    local sectionSpacing = 14
    local controlSpacing = 4

    local labelFont = fonts.small or fonts.body
    local headingFont = fonts.body or labelFont
    local hintFont = fonts.tiny or labelFont

    local headingText = "MAP LEGEND"

    local headingHeight = headingFont:getHeight()
    local labelHeight = labelFont:getHeight()
    local hintHeight = hintFont:getHeight()

    local maxLabelWidth = 0
    for _, item in ipairs(legendItems) do
        maxLabelWidth = math.max(maxLabelWidth, labelFont:getWidth(item.label))
    end

    local maxControlWidth = 0
    for _, text in ipairs(controls) do
        maxControlWidth = math.max(maxControlWidth, hintFont:getWidth(text))
    end

    local contentWidth = math.max(
        headingFont:getWidth(headingText),
        swatchSize + swatchSpacing + maxLabelWidth,
        maxControlWidth
    )

    local panelWidth = padding * 2 + contentWidth
    local maxPanelWidth = rect.width - panelMargin * 2
    if maxPanelWidth <= 0 then
        maxPanelWidth = rect.width * 0.5
    end
    panelWidth = math.min(panelWidth, maxPanelWidth)

    local legendSectionHeight = (#legendItems > 0) and (#legendItems * labelHeight + (#legendItems - 1) * rowSpacing) or 0
    local controlsHeight = (#controls > 0) and (#controls * hintHeight + (#controls - 1) * controlSpacing) or 0

    local panelHeight = padding + headingHeight
    if legendSectionHeight > 0 then
        panelHeight = panelHeight + headingSpacing + legendSectionHeight
    end
    if controlsHeight > 0 then
        panelHeight = panelHeight + sectionSpacing + controlsHeight
    end
    panelHeight = panelHeight + padding

    local panelX = rect.x + panelMargin
    local panelY = rect.y + panelMargin

    local palette = theme.palette or {}
    local panelColor = colors.legend_panel or palette.surface_subtle or colors.background or { 0.08, 0.09, 0.12, 0.94 }
    local borderColor = colors.legend_border or colors.border or palette.border or { 0.22, 0.28, 0.36, 1 }
    local textColor = colors.legend_text or { 0.8, 0.82, 0.86, 1 }
    local mutedColor = colors.legend_muted or { 0.6, 0.65, 0.7, 1 }
    local headingColor = colors.legend_heading or textColor

    love.graphics.setColor(panelColor)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)

    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 0.5, panelY + 0.5, panelWidth - 1, panelHeight - 1)

    local textX = panelX + padding
    local currentY = panelY + padding

    love.graphics.setFont(headingFont)
    love.graphics.setColor(headingColor)
    love.graphics.print(headingText, textX, currentY)
    currentY = currentY + headingHeight

    if legendSectionHeight > 0 then
        currentY = currentY + headingSpacing
        love.graphics.setFont(labelFont)

        for index, item in ipairs(legendItems) do
            local swatchY = currentY + (labelHeight - swatchSize) * 0.5

            love.graphics.setColor(item.color or textColor)
            love.graphics.rectangle("fill", textX, swatchY, swatchSize, swatchSize)

            love.graphics.setColor(textColor)
            love.graphics.print(item.label, textX + swatchSize + swatchSpacing, currentY)

            currentY = currentY + labelHeight
            if index < #legendItems then
                currentY = currentY + rowSpacing
            end
        end
    end

    if controlsHeight > 0 then
        currentY = currentY + sectionSpacing * 0.5

        local dividerY = currentY
        love.graphics.setColor(colors.legend_divider or borderColor)
        love.graphics.setLineWidth(1)
        love.graphics.line(textX, dividerY, panelX + panelWidth - padding, dividerY)

        currentY = currentY + sectionSpacing * 0.5

        love.graphics.setFont(hintFont)
        love.graphics.setColor(mutedColor)
        for index, text in ipairs(controls) do
            love.graphics.print(text, textX, currentY)
            currentY = currentY + hintHeight
            if index < #controls then
                currentY = currentY + controlSpacing
            end
        end
    end
end

local function draw_galaxy_view(context, rect, bounds, colors, scale, centerX, centerY)
	local universe = resolve_universe(context)
	if not universe then
		return
	end

	local galaxy = Universe.getActiveGalaxy(universe, universe.currentGalaxyId)
	if not galaxy then
		return
	end

	local sectors = galaxy.sectors or {}
	if #sectors == 0 then
		return
	end

	local sectorLinkColor = colors.bounds or { 0.46, 0.64, 0.72, 0.8 }
	love.graphics.setLineWidth(1)
	love.graphics.setColor(sectorLinkColor)

	for i = 1, #sectors do
		local sector = sectors[i]
		local sx, sy = world_to_screen(sector.x, sector.y, rect, scale, centerX, centerY)
		local links = sector.links or {}
		for li = 1, #links do
			local link = links[li]
			if link and link.targetId then
				local target = universe.sectorsById and universe.sectorsById[link.targetId]
				if target and target.galaxyId == galaxy.id then
					local tx, ty = world_to_screen(target.x, target.y, rect, scale, centerX, centerY)
					love.graphics.line(sx, sy, tx, ty)
				end
			end
		end
	end

	local homeSectorId = universe.homeSectorId
	local currentSectorId = universe.currentSectorId or homeSectorId

	for i = 1, #sectors do
		local sector = sectors[i]
		local sx, sy = world_to_screen(sector.x, sector.y, rect, scale, centerX, centerY)
		local radius = 6
		local color = colors.station or { 0.32, 0.52, 0.92, 1 }

		if sector.id == currentSectorId then
			color = colors.player or color
			radius = 7
		elseif sector.id == homeSectorId then
			color = colors.teammate or color
			radius = 7
		elseif sector.isGalaxyGate then
			color = colors.enemy or color
			radius = 7
		end

		love.graphics.setColor(color)
		love.graphics.circle("fill", sx, sy, radius)
		love.graphics.setColor(colors.border or { 0.22, 0.28, 0.36, 0.9 })
		love.graphics.setLineWidth(1)
		love.graphics.circle("line", sx, sy, radius)
	end
end

local function draw_universe_view(context, rect, bounds, colors, scale, centerX, centerY)
	local universe = resolve_universe(context)
	if not universe then
		return
	end

	local galaxies = universe.galaxies or {}
	if #galaxies == 0 then
		return
	end

	love.graphics.setLineWidth(1)
	love.graphics.setColor(colors.bounds or { 0.46, 0.64, 0.72, 0.8 })

	local byId = universe.galaxiesById or {}
	for i = 1, #galaxies do
		local galaxy = galaxies[i]
		local gx, gy = world_to_screen(galaxy.universeX or 0, galaxy.universeY or 0, rect, scale, centerX, centerY)
		local links = galaxy.links or {}
		for li = 1, #links do
			local link = links[li]
			local targetId = link and link.galaxyId
			if targetId then
				local target = byId[targetId]
				if target then
					local tx, ty = world_to_screen(target.universeX or 0, target.universeY or 0, rect, scale, centerX, centerY)
					love.graphics.line(gx, gy, tx, ty)
				end
			end
		end
	end

	local homeGalaxyId = universe.homeGalaxyId
	local currentGalaxyId = universe.currentGalaxyId or homeGalaxyId

	for i = 1, #galaxies do
		local galaxy = galaxies[i]
		local gx, gy = world_to_screen(galaxy.universeX or 0, galaxy.universeY or 0, rect, scale, centerX, centerY)
		local radius = 10
		local color = colors.station or { 0.32, 0.52, 0.92, 1 }

		if galaxy.id == currentGalaxyId then
			color = colors.player or color
			radius = 12
		elseif galaxy.id == homeGalaxyId then
			color = colors.teammate or color
			radius = 11
		end

		love.graphics.setColor(color)
		love.graphics.circle("fill", gx, gy, radius)
		love.graphics.setColor(colors.border or { 0.22, 0.28, 0.36, 0.9 })
		love.graphics.setLineWidth(1)
		love.graphics.circle("line", gx, gy, radius)
	end
end

local function draw_entities(context, player, rect, bounds, colors, scale, centerX, centerY)
    if not (context and context.world) then
        return
    end

    local entities = context.world.entities or {}

    for i = 1, #entities do
        local entity = entities[i]
        if entity and entity.position then
            local color
            local radius = 3

            if entity == player then
                color = colors.player
                radius = 5
            elseif entity.player then
                color = colors.teammate
                radius = 4
            elseif entity.station or (entity.blueprint and entity.blueprint.category == "stations") then
                color = colors.station
                radius = 4
            elseif entity.blueprint and entity.blueprint.category == "asteroids" then
                color = colors.asteroid
                radius = 3
            elseif entity.blueprint and entity.blueprint.category == "ships" then
                color = colors.enemy
                radius = 4
            end

            if color then
                local screenX, screenY = world_to_screen(entity.position.x, entity.position.y, rect, scale, centerX, centerY)
                if screenX >= rect.x and screenX <= rect.x + rect.width and screenY >= rect.y and screenY <= rect.y + rect.height then
                    love.graphics.setColor(color)
                    love.graphics.circle("fill", screenX, screenY, radius)
                end
            end
        end
    end

    if player and player.position then
        love.graphics.setColor(colors.player)
        local px, py = world_to_screen(player.position.x, player.position.y, rect, scale, centerX, centerY)
        love.graphics.circle("line", px, py, 9)
    end
end

function map_window.draw(context)
    local state = context and context.mapUI
    if not (state and state.visible) then
        return false
    end

    local bounds = get_mode_bounds(context, state)
    if not bounds then
        return false
    end

    local fonts = theme.get_fonts()
    local colors = theme.colors.map or {}

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local windowRect = get_window_rect(screenWidth, screenHeight)

    state.zoom = math_util.clamp(state.zoom or 1, state.min_zoom or 0.35, state.max_zoom or 6)

    if state._just_opened or not (state.centerX and state.centerY) then
		reset_view(state, context, bounds)
        state._just_opened = false
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local isMouseDown = love.mouse.isDown(1)
    local justPressed = isMouseDown and not state._was_mouse_down

    love.graphics.push("all")
    love.graphics.origin()

    love.graphics.setColor(colors.overlay or { 0, 0, 0, 0.78 })
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local frame = window.draw_frame {
        x = windowRect.x,
        y = windowRect.y,
        width = windowRect.width,
        height = windowRect.height,
        title = state.title or "Sector Map",
        fonts = fonts,
        state = state,
        input = {
            x = mouseX,
            y = mouseY,
            is_down = isMouseDown,
            just_pressed = justPressed,
        },
        show_close = true,
    }

    local bottomBar = frame and frame.bottom_bar
    local contentFrame = frame and (frame.content_full or frame.content)
    local rect = get_map_rect(contentFrame)
    if not rect then
        love.graphics.pop()
        return false
    end

    if context and context.uiInput then
        if frame.dragging or state.mapDragging then
            context.uiInput.mouseCaptured = true
        end
        context.uiInput.keyboardCaptured = true
    end

    local baseScale = math.min(rect.width / bounds.width, rect.height / bounds.height)
    local scale = baseScale * state.zoom

    clamp_center(state, bounds, rect, scale)

    if justPressed and point_in_rect(mouseX, mouseY, rect) then
        state.mapDragging = true
        state.mapDragStartMouseX = mouseX
        state.mapDragStartMouseY = mouseY
        state.mapDragStartCenterX = state.centerX
        state.mapDragStartCenterY = state.centerY
    elseif not isMouseDown then
        state.mapDragging = false
    end

    if state.mapDragging and isMouseDown then
        local dx = (mouseX - (state.mapDragStartMouseX or mouseX)) / scale
        local dy = (mouseY - (state.mapDragStartMouseY or mouseY)) / scale

        state.centerX = (state.mapDragStartCenterX or state.centerX) - dx
        state.centerY = (state.mapDragStartCenterY or state.centerY) - dy
        clamp_center(state, bounds, rect, scale)
    end

    state._was_mouse_down = isMouseDown

    love.graphics.setColor(colors.background or theme.palette.surface_subtle or { 0.05, 0.06, 0.08, 0.95 })
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)

    if colors.border then
        love.graphics.setColor(colors.border)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1)
    end

    love.graphics.push()
    love.graphics.setScissor(rect.x, rect.y, rect.width, rect.height)

    if colors.grid and (state.mode == "sector") then
        love.graphics.setColor(colors.grid)
        love.graphics.setLineWidth(1)
        local gridStep = 500
        local startX = math.floor(bounds.x / gridStep) * gridStep
        local endX = bounds.x + bounds.width
        local startY = math.floor(bounds.y / gridStep) * gridStep
        local endY = bounds.y + bounds.height

        for gx = startX, endX, gridStep do
            local x1, y1 = world_to_screen(gx, bounds.y, rect, scale, state.centerX, state.centerY)
            local x2, y2 = world_to_screen(gx, bounds.y + bounds.height, rect, scale, state.centerX, state.centerY)
            love.graphics.line(x1, y1, x2, y2)
        end

        for gy = startY, endY, gridStep do
            local x1, y1 = world_to_screen(bounds.x, gy, rect, scale, state.centerX, state.centerY)
            local x2, y2 = world_to_screen(bounds.x + bounds.width, gy, rect, scale, state.centerX, state.centerY)
            love.graphics.line(x1, y1, x2, y2)
        end
    end

    local boundsX1, boundsY1 = world_to_screen(bounds.x, bounds.y, rect, scale, state.centerX, state.centerY)
    local boundsX2, boundsY2 = world_to_screen(bounds.x + bounds.width, bounds.y + bounds.height, rect, scale, state.centerX, state.centerY)

	local mode = state.mode or "sector"
	if mode == "sector" then
		love.graphics.setColor(colors.bounds or { 0.46, 0.64, 0.72, 0.8 })
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", boundsX1, boundsY1, boundsX2 - boundsX1, boundsY2 - boundsY1)

		local player = PlayerManager.resolveLocalPlayer(context)
		draw_entities(context, player, rect, bounds, colors, scale, state.centerX, state.centerY)
	elseif mode == "galaxy" then
		love.graphics.setColor(colors.bounds or { 0.46, 0.64, 0.72, 0.8 })
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", boundsX1, boundsY1, boundsX2 - boundsX1, boundsY2 - boundsY1)
		draw_galaxy_view(context, rect, bounds, colors, scale, state.centerX, state.centerY)
	elseif mode == "universe" then
		love.graphics.setColor(colors.bounds or { 0.46, 0.64, 0.72, 0.8 })
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", boundsX1, boundsY1, boundsX2 - boundsX1, boundsY2 - boundsY1)
		draw_universe_view(context, rect, bounds, colors, scale, state.centerX, state.centerY)
	end

    love.graphics.setScissor()
    love.graphics.pop()

    draw_legend(rect, fonts, colors)

    if bottomBar and bottomBar.inner then
        local bar = bottomBar.inner
        local buttonWidth = math.max(120, math.min(160, bar.width * 0.3))
        local buttonHeight = math.min(36, math.max(28, bar.height - 8))
        local buttonRect = {
            x = bar.x + bar.width - buttonWidth,
            y = bar.y + (bar.height - buttonHeight) * 0.5,
            width = buttonWidth,
            height = buttonHeight,
        }

        local buttonResult = UIButton.render {
            rect = buttonRect,
            label = "Reset View",
            fonts = fonts,
            font = fonts.body,
            input = {
                x = mouseX,
                y = mouseY,
                is_down = isMouseDown,
                just_pressed = justPressed,
            },
        }

        if buttonResult.clicked then
            reset_view(state, context, bounds)
            clamp_center(state, bounds, rect, baseScale * state.zoom)
        end
    end

    local shouldClose = frame and frame.close_clicked

    love.graphics.pop()

    if shouldClose then
        UIStateManager.hideMapUI(context)
        return true
    end

    return true
end

function map_window.keypressed(context, key)
    if key == nil then
        return false
    end

    local state = context and context.mapUI
    if not (state and state.visible) then
        return false
    end

    if key == "escape" or key == "m" then
        UIStateManager.hideMapUI(context)
        return true
    end

	if key == "1" then
		state.mode = "sector"
		state.title = "Sector Map"
		state._just_opened = true
		return true
	elseif key == "2" then
		local universe = resolve_universe(context)
		if universe then
			state.mode = "galaxy"
			state.title = "Galaxy Map"
			state._just_opened = true
		end
		return true
	elseif key == "3" then
		local universe = resolve_universe(context)
		if universe then
			state.mode = "universe"
			state.title = "Universe Map"
			state._just_opened = true
		end
		return true
	end

    return true
end

function map_window.wheelmoved(context, x, y)
    local state = context and context.mapUI
    if not (state and state.visible) then
        return false
    end

    y = tonumber(y)
    if not y or y == 0 then
        return false
    end

    local zoomStep = 0.15
    local newZoom
    if y > 0 then
        newZoom = state.zoom * (1 + zoomStep)
    else
        newZoom = state.zoom / (1 + zoomStep)
    end

    local clamped = math_util.clamp(newZoom, state.min_zoom or 0.35, state.max_zoom or 6)
    if math.abs(clamped - state.zoom) < 1e-4 then
        return false
    end

    state.zoom = clamped
    return true
end

return map_window
