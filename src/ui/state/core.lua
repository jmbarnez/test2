local core = {}

local function resolve_state_pair(state)
    if not state then
        return nil, nil
    end

    if type(state.resolveState) == "function" then
        local ok, resolved = pcall(state.resolveState, state)
        if ok and type(resolved) == "table" and resolved ~= state then
            return resolved, state
        end
    end

    if type(state.state) == "table" and state.state ~= state then
        return state.state, state
    end

    return state, nil
end

local function set_state_field(primary, secondary, key, value)
    if primary then
        primary[key] = value
    end

    if secondary and secondary ~= primary then
        secondary[key] = value
    end
end

local function any_modal_visible(state)
    local resolved = resolve_state_pair(state)
    if not resolved then
        return false
    end

    return (resolved.pauseUI and resolved.pauseUI.visible)
        or (resolved.deathUI and resolved.deathUI.visible)
        or (resolved.cargoUI and resolved.cargoUI.visible)
        or (resolved.optionsUI and resolved.optionsUI.visible)
        or (resolved.mapUI and resolved.mapUI.visible)
        or (resolved.skillsUI and resolved.skillsUI.visible)
        or (resolved.stationUI and resolved.stationUI.visible)
end

local function capture_input(state)
    local resolved = resolve_state_pair(state)
    if resolved and resolved.uiInput then
        resolved.uiInput.mouseCaptured = true
        resolved.uiInput.keyboardCaptured = true
    end
end

local function release_input(state, respect_modals)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.uiInput) then
        return
    end

    if respect_modals then
        local keepCaptured = any_modal_visible(resolved)
        resolved.uiInput.mouseCaptured = not not keepCaptured
        resolved.uiInput.keyboardCaptured = not not keepCaptured
    else
        resolved.uiInput.mouseCaptured = false
        resolved.uiInput.keyboardCaptured = false
    end
end

local function create_visibility_handlers(windowKey, config)
    config = config or {}

    local function set_visibility(state, visible)
        local resolved, proxy = resolve_state_pair(state)
        if not resolved then
            return
        end

        state = resolved
        if not (state and state[windowKey]) then
            return
        end

        local window_state = state[windowKey]

        if config.beforeSet and config.beforeSet(state, window_state, visible, proxy) == false then
            return
        end

        if window_state.visible == visible then
            if config.onUnchanged then
                config.onUnchanged(state, window_state, visible, proxy)
            end
            return
        end

        window_state.visible = visible

        if config.afterSet then
            config.afterSet(state, window_state, visible, proxy)
        end
    end

    return {
        set = set_visibility,
        show = function(state)
            set_visibility(state, true)
        end,
        hide = function(state)
            set_visibility(state, false)
        end,
        toggle = function(state)
            if not (state and state[windowKey]) then
                return
            end

            set_visibility(state, not state[windowKey].visible)
        end,
    }
end

core.resolve_state_pair = resolve_state_pair
core.set_state_field = set_state_field
core.any_modal_visible = any_modal_visible
core.capture_input = capture_input
core.release_input = release_input
core.create_visibility_handlers = create_visibility_handlers

return core
