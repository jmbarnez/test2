---@diagnostic disable: undefined-global
-- Minimal embedded copy of HUMP gamestate (MIT License)

local Gamestate = {
    current = nil,
    stack = {},
}

local function assert_state(state)
    assert(type(state) == "table", "Gamestate: state must be a table")
    return state
end

local function call_if(state, func, ...)
    if state and state[func] then
        return state[func](state, ...)
    end
end

function Gamestate.switch(to, ...)
    to = assert_state(to)
    local from = Gamestate.current
    if from == to then
        return
    end
    call_if(from, "leave")
    Gamestate.current = to
    call_if(to, "enter", from, ...)
end

function Gamestate.push(to, ...)
    to = assert_state(to)
    local current = Gamestate.current
    if current then
        table.insert(Gamestate.stack, current)
        call_if(current, "pause")
    end
    Gamestate.current = to
    call_if(to, "enter", current, ...)
end

function Gamestate.pop(...)
    local current = Gamestate.current
    if not current then
        return
    end
    call_if(current, "leave")
    Gamestate.current = table.remove(Gamestate.stack)
    call_if(Gamestate.current, "resume", current, ...)
end

function Gamestate.registerEvents()
    local callbacks = {
        "draw",
        "update",
        "keypressed",
        "keyreleased",
        "mousepressed",
        "mousereleased",
        "mousemoved",
        "wheelmoved",
        "textinput",
        "textedited",
        "gamepadpressed",
        "gamepadreleased",
        "gamepadaxis",
        "focus",
        "resize",
    }

    for _, callback in ipairs(callbacks) do
        local old = love[callback]
        love[callback] = function(...)
            if old then
                old(...)
            end
            local state = Gamestate.current
            if state and state[callback] then
                state[callback](state, ...)
            end
        end
    end
end

function Gamestate.update(dt)
    if Gamestate.current and Gamestate.current.update then
        Gamestate.current:update(dt)
    end
end

function Gamestate.draw()
    if Gamestate.current and Gamestate.current.draw then
        Gamestate.current:draw()
    end
end

return Gamestate
