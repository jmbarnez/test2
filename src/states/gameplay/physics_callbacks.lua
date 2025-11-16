--- Physics Callback Router
-- Manages Box2D physics callback routing for gameplay state
-- Supports multiple callback handlers per phase (beginContact, endContact, preSolve, postSolve)

local VALID_PHASES = {
    beginContact = true,
    endContact = true,
    preSolve = true,
    postSolve = true,
}

local PhysicsCallbacks = {}

--- Ensures physics callback router is set up on the gameplay state
---@param state table Gameplay state
function PhysicsCallbacks.ensureRouter(state)
    local physicsWorld = state.physicsWorld
    if not physicsWorld then
        return
    end

    if not state.physicsCallbackLists then
        state.physicsCallbackLists = {
            beginContact = {},
            endContact = {},
            preSolve = {},
            postSolve = {},
        }
    end

    if not state._physicsCallbackRouter then
        local function forward(phase)
            return function(...)
                local lists = state.physicsCallbackLists
                if not lists then
                    return
                end

                local handlers = lists[phase]
                if not handlers then
                    return
                end

                for i = 1, #handlers do
                    local handler = handlers[i]
                    if handler then
                        handler(...)
                    end
                end
            end
        end

        state._physicsCallbackRouter = {
            beginContact = forward("beginContact"),
            endContact = forward("endContact"),
            preSolve = forward("preSolve"),
            postSolve = forward("postSolve"),
        }
    end

    physicsWorld:setCallbacks(
        state._physicsCallbackRouter.beginContact,
        state._physicsCallbackRouter.endContact,
        state._physicsCallbackRouter.preSolve,
        state._physicsCallbackRouter.postSolve
    )
end

--- Register a physics callback handler
---@param state table Gameplay state
---@param phase string Callback phase (beginContact, endContact, preSolve, postSolve)
---@param handler function Callback function
---@return function Unregister function
function PhysicsCallbacks.register(state, phase, handler)
    if not VALID_PHASES[phase] then
        error(string.format("Invalid physics callback phase '%s'", tostring(phase)))
    end

    if type(handler) ~= "function" then
        error("Physics callback handler must be a function")
    end

    if not state.physicsWorld then
        return function() end
    end

    PhysicsCallbacks.ensureRouter(state)

    local list = state.physicsCallbackLists[phase]
    list[#list + 1] = handler

    return function()
        PhysicsCallbacks.unregister(state, phase, handler)
    end
end

--- Unregister a physics callback handler
---@param state table Gameplay state
---@param phase string Callback phase
---@param handler function Callback function to remove
function PhysicsCallbacks.unregister(state, phase, handler)
    local lists = state.physicsCallbackLists
    if not (lists and VALID_PHASES[phase]) then
        return
    end

    local handlers = lists[phase]
    if not handlers then
        return
    end

    for i = #handlers, 1, -1 do
        if handlers[i] == handler then
            table.remove(handlers, i)
            break
        end
    end
end

--- Clear all physics callbacks
---@param state table Gameplay state
function PhysicsCallbacks.clear(state)
    if state.physicsWorld then
        state.physicsWorld:setCallbacks()
    end

    state.physicsCallbackLists = nil
    state._physicsCallbackRouter = nil
end

return PhysicsCallbacks
