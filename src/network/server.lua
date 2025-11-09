local Transport = require("src.network.transport")
local Snapshot = require("src.network.snapshot")
local Intent = require("src.input.intent")
local Entities = require("src.states.gameplay.entities")
local PlayerManager = require("src.player.manager")
local UIStateManager = require("src.ui.state_manager")
local constants = require("src.constants.game")
local json = require("libs.json")

local love = love

local Server = {}
Server.__index = Server

local function sanitize_for_json(value, seen)
    local valueType = type(value)
    if valueType ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local numericKeys = {}
    local hasNonNumeric = false
    for key in pairs(value) do
        if type(key) == "number" and key > 0 and math.floor(key) == key then
            numericKeys[#numericKeys + 1] = key
        else
            hasNonNumeric = true
        end
    end

    table.sort(numericKeys)

    local isSequential = not hasNonNumeric and #numericKeys > 0
    if isSequential then
        for index = 1, #numericKeys do
            if numericKeys[index] ~= index then
                isSequential = false
                break
            end
        end
    end

    local sanitized = {}
    seen[value] = sanitized

    if isSequential then
        for index = 1, #numericKeys do
            sanitized[index] = sanitize_for_json(value[index], seen)
        end
    else
        for key, nested in pairs(value) do
            sanitized[tostring(key)] = sanitize_for_json(nested, seen)
        end
    end

    return sanitized
end

local function encode_message(message)
    local sanitized = sanitize_for_json(message)
    local ok, result = pcall(json.encode, sanitized)
    if ok then
        return result
    else
        print("[NETWORK] Failed to encode message:", result)
    end
    return nil
end

local function decode_message(data)
    local ok, decoded = pcall(json.decode, data)
    if ok then
        return decoded
    end
    return nil
end

function Server.new(config)
    config = config or {}
    local state = assert(config.state, "Server requires gameplay state")
    local host = config.host or "0.0.0.0"
    local port = config.port or constants.network.port

    local self = setmetatable({
        state = state,
        host = host,
        port = port,
        peers = {},
        peerPlayers = {},
        playerSeq = 0,
        usedPlayerIds = {},
        snapshotInterval = config.snapshotInterval or (1.0 / (constants.network.snapshot_rate or 10)),
        snapshotTimer = 0,
        onPlayerJoined = config.onPlayerJoined,
    }, Server)

    state.netTick = state.netTick or 0

    self.transport = Transport.createServer({
        host = host,
        port = port,
        channels = config.channels or 2,
        onConnect = function(peer)
            self:onConnect(peer)
        end,
        onDisconnect = function(peer, code)
            self:onDisconnect(peer, code)
        end,
        onReceive = function(peer, data, channel)
            self:onReceive(peer, data, channel)
        end,
        onTimeout = function(peer)
            self:onDisconnect(peer, "timeout")
        end,
    })
    
    return self
end

function Server:initializeHostPlayer()
    local currentShip = PlayerManager.getCurrentShip(self.state)
    if not currentShip then
        return
    end

    local existingId = currentShip.playerId
    local needsNewId = not existingId or existingId == "player"

    local hostPlayerId = needsNewId and self:generateUniquePlayerId() or existingId
    if not needsNewId then
        self.usedPlayerIds[hostPlayerId] = true
    end

    currentShip.playerId = hostPlayerId
    self.state.localPlayerId = hostPlayerId

    PlayerManager.attachShip(self.state, currentShip, nil, hostPlayerId)
    Intent.ensure(self.state, hostPlayerId)
end

function Server:shutdown()
    if self.transport then
        self.transport:shutdown(0)
    end
    self.peers = {}
    self.peerPlayers = {}
    self.usedPlayerIds = {}
end

function Server:generateUniquePlayerId()
    local playerId
    repeat
        self.playerSeq = self.playerSeq + 1
        playerId = string.format("player_%03d", self.playerSeq)
    until not self.usedPlayerIds[playerId]
    
    self.usedPlayerIds[playerId] = true
    return playerId
end

function Server:onConnect(peer)
    local playerId = self:generateUniquePlayerId()
    local peerIndex = peer:index()
    
    self.peers[peerIndex] = peer
    self.peerPlayers[peerIndex] = playerId

    self:spawnPlayerForPeer(peer, playerId)

    local playerAssignedPayload = encode_message({ 
        type = "player_assigned", 
        playerId = playerId 
    })
    if playerAssignedPayload then
        self.transport:send(peer, playerAssignedPayload, 0, true)
    end

    local snapshot = Snapshot.capture(self.state)
    if snapshot then
        local payload = encode_message({ type = "snapshot", payload = snapshot })
        if payload then
            self.transport:send(peer, payload, 0, true)
        end
    end
    
    self:broadcastSnapshot()
end

function Server:onDisconnect(peer, _code)
    local index = peer:index()
    local playerId = self.peerPlayers[index]
    
    self.peers[index] = nil
    self.peerPlayers[index] = nil

    if not playerId then
        return
    end

    self.usedPlayerIds[playerId] = nil
    
    if self.state and self.state.players then
        local entity = self.state.players[playerId]
        if entity then
            if self.state.world then
                self.state.world:remove(entity)
            end
            if entity.body and not entity.body:isDestroyed() then
                entity.body:destroy()
            end
            self.state.players[playerId] = nil
        end
    end
    
    self:broadcastSnapshot()
end

function Server:onReceive(peer, data, _channel)
    local message = decode_message(data)
    if type(message) ~= "table" or not message.type then
        return
    end

    if message.type == "intent" and message.playerId and message.payload then
        self:applyIntent(message.playerId, message.payload)
    elseif message.type == "chat" and message.payload then
        local text = message.payload.text
        if type(text) == "string" and text ~= "" then
            local playerId = self.peerPlayers[peer:index()] or message.playerId
            self:handleChatMessage(playerId, text)
        end
    end
end

function Server:applyIntent(playerId, payload)
    local container = Intent.ensureContainer(self.state)
    if not container then
        return
    end

    local intent = container[playerId]
    if not intent then
        intent = {}
        container[playerId] = intent
    end

    intent.moveX = payload.moveX or 0
    intent.moveY = payload.moveY or 0
    intent.moveMagnitude = payload.moveMagnitude or 0
    intent.aimX = payload.aimX or intent.aimX
    intent.aimY = payload.aimY or intent.aimY
    intent.hasAim = payload.hasAim ~= nil and payload.hasAim or intent.hasAim
    intent.firePrimary = not not payload.firePrimary
    intent.fireSecondary = not not payload.fireSecondary
end

function Server:spawnPlayerForPeer(peer, playerId)
    self.state.players = self.state.players or {}

    local entity = Entities.spawnPlayer(self.state, { playerId = playerId })
    if entity then
        self.state.players[playerId] = entity
    end

    Intent.ensure(self.state, playerId)
    
    if self.onPlayerJoined then
        self.onPlayerJoined(peer, entity, playerId)
    end
end

function Server:handleChatMessage(playerId, text)
    if type(text) ~= "string" then
        return
    end

    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return
    end

    local resolvedId = playerId or self.state.localPlayerId or "server"
    UIStateManager.addChatMessage(self.state, resolvedId, trimmed)

    local payload = encode_message({
        type = "chat",
        playerId = resolvedId,
        payload = {
            text = trimmed,
        },
    })

    if payload then
        self.transport:broadcast(payload, 0, true)
    end
end

function Server:broadcastSnapshot()
    local snapshot = Snapshot.capture(self.state)
    if not snapshot then
        return
    end

    self.state.netTick = (self.state.netTick or 0) + 1
    snapshot.tick = self.state.netTick

    local payload = encode_message({ type = "snapshot", payload = snapshot })
    if not payload then
        return
    end

    for _, peer in pairs(self.peers) do
        self.transport:send(peer, payload, 0, true)
    end
end

function Server:update(dt)
    if not self.transport then
        return
    end

    self.transport:update(dt)

    -- Add a small delay before starting snapshots to let spawners run
    self.startupTimer = (self.startupTimer or 0) + dt
    if self.startupTimer < 1.0 then  -- Wait 1 second before starting snapshots
        return
    end

    self.snapshotTimer = self.snapshotTimer + dt
    if self.snapshotTimer >= self.snapshotInterval then
        self.snapshotTimer = 0
        self:broadcastSnapshot()
    end
end

return Server
