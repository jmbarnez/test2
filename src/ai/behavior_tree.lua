local BehaviorTree = {}
BehaviorTree.__index = BehaviorTree

BehaviorTree.Status = {
    success = "success",
    failure = "failure",
    running = "running",
}

local nodeIdCounter = 0

local function nextNodeId()
    nodeIdCounter = nodeIdCounter + 1
    return nodeIdCounter
end

local function ensureNodeId(node)
    if not node.__id then
        node.__id = nextNodeId()
    end
    return node.__id
end

local function getNodeMemory(blackboard, node)
    local memory = blackboard.__nodeMemory
    if not memory then
        memory = {}
        blackboard.__nodeMemory = memory
    end

    local id = ensureNodeId(node)
    local nodeMemory = memory[id]
    if not nodeMemory then
        nodeMemory = {}
        memory[id] = nodeMemory
    end

    return nodeMemory
end

function BehaviorTree.createBlackboard(initial)
    local blackboard = initial or {}
    blackboard.__nodeMemory = blackboard.__nodeMemory or {}
    return blackboard
end

function BehaviorTree.resetBlackboard(blackboard)
    if blackboard then
        blackboard.__nodeMemory = {}
    end
end

function BehaviorTree.new(root)
    return setmetatable({
        root = root,
    }, BehaviorTree)
end

function BehaviorTree:tick(entity, blackboard, dt)
    if not self.root then
        return BehaviorTree.Status.failure
    end

    blackboard = blackboard or BehaviorTree.createBlackboard()
    return self.root:tick(entity, blackboard, dt)
end

local function wrapNode(node)
    ensureNodeId(node)
    return node
end

function BehaviorTree.Action(fn)
    return wrapNode({
        type = "action",
        tick = function(self, entity, blackboard, dt)
            return fn(entity, blackboard, dt) or BehaviorTree.Status.success
        end,
    })
end

function BehaviorTree.Condition(fn)
    return wrapNode({
        type = "condition",
        tick = function(self, entity, blackboard, dt)
            if fn(entity, blackboard, dt) then
                return BehaviorTree.Status.success
            end
            return BehaviorTree.Status.failure
        end,
    })
end

function BehaviorTree.Sequence(children)
    return wrapNode({
        type = "sequence",
        children = children or {},
        tick = function(self, entity, blackboard, dt)
            local memory = getNodeMemory(blackboard, self)
            local index = memory.runningIndex or 1

            for i = index, #self.children do
                local child = self.children[i]
                local status = child:tick(entity, blackboard, dt)

                if status == BehaviorTree.Status.running then
                    memory.runningIndex = i
                    return status
                elseif status == BehaviorTree.Status.failure then
                    memory.runningIndex = nil
                    return status
                end
            end

            memory.runningIndex = nil
            return BehaviorTree.Status.success
        end,
    })
end

function BehaviorTree.Selector(children)
    return wrapNode({
        type = "selector",
        children = children or {},
        tick = function(self, entity, blackboard, dt)
            local memory = getNodeMemory(blackboard, self)
            local index = memory.runningIndex or 1

            for i = index, #self.children do
                local child = self.children[i]
                local status = child:tick(entity, blackboard, dt)

                if status == BehaviorTree.Status.running then
                    memory.runningIndex = i
                    return status
                elseif status == BehaviorTree.Status.success then
                    memory.runningIndex = nil
                    return status
                end
            end

            memory.runningIndex = nil
            return BehaviorTree.Status.failure
        end,
    })
end

function BehaviorTree.Inverter(child)
    return wrapNode({
        type = "decorator_inverter",
        child = child,
        tick = function(self, entity, blackboard, dt)
            local status = self.child:tick(entity, blackboard, dt)

            if status == BehaviorTree.Status.success then
                return BehaviorTree.Status.failure
            elseif status == BehaviorTree.Status.failure then
                return BehaviorTree.Status.success
            end

            return status
        end,
    })
end

function BehaviorTree.Succeeder(child)
    return wrapNode({
        type = "decorator_succeeder",
        child = child,
        tick = function(self, entity, blackboard, dt)
            self.child:tick(entity, blackboard, dt)
            return BehaviorTree.Status.success
        end,
    })
end

return BehaviorTree
