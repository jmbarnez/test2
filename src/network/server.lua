local Transport = require("src.network.transport")
local Snapshot = require("src.network.snapshot")
local Intent = require("src.input.intent")
local Entities = require("src.states.gameplay.entities")
local PlayerManager = require("src.player.manager")
local constants = require("src.constants.game")
local json = require("libs.json")

local love = love

local Server = {}
Server.__index = Server

local function encode_message(message)
    local ok, result = pcall(json.encode, message)
    if ok then
        return result
    end
end

local function decode_message(data)
    local ok, decoded = pcall(json.decode, data)
    if ok then
        return decoded
    end
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
        snapshotInterval = config.snapshotInterval or 0.1,
        snapshotTimer = 0,
    }, Server)

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

    -- Ensure host player has a proper ID if they already exist
    self:initializeHostPlayer()
    
    return self
end

function Server:initializeHostPlayer()
    local currentShip = PlayerManager.getCurrentShip(self.state)
    if currentShip and not currentShip.playerId then
        local hostPlayerId = self:generateUniquePlayerId()
        currentShip.playerId = hostPlayerId
        self.state.localPlayerId = hostPlayerId
        self.state.players = self.state.players or {}
        self.state.players[hostPlayerId] = currentShip
        Intent.ensure(self.state, hostPlayerId)
    end
end

function Server:shutdown()
    if self.transport then
        self.transport:shutdown(0)
    end
    self.peers = {}
    self.peerPlayers = {}
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
    self.peers[peer:index()] = peer
    self.peerPlayers[peer:index()] = playerId

    self:spawnPlayerForPeer(peer, playerId)

    -- Send the client their assigned player ID
    local playerAssignedPayload = encode_message({ 
        type = "player_assigned", 
        playerId = playerId 
    })
    if playerAssignedPayload then
        self.transport:send(peer, playerAssignedPayload, 0, true)
    end

    -- Send full snapshot to new player so they can see all existing players
    local snapshot = Snapshot.capture(self.state)
    if snapshot then
        local payload = encode_message({ type = "snapshot", payload = snapshot })
        if payload then
            self.transport:send(peer, payload, 0, true)
        end
    end
    
    -- Broadcast updated snapshot to all players so they can see the new player
    self:broadcastSnapshot()
end

function Server:onDisconnect(peer, _code)
    local index = peer:index()
    local playerId = self.peerPlayers[index]
    self.peers[index] = nil
    self.peerPlayers[index] = nil

    if playerId then
        -- Mark player ID as available for reuse
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
        
        -- Broadcast updated snapshot to all remaining players
        self:broadcastSnapshot()
    end
end

function Server:onReceive(peer, data, _channel)
    local message = decode_message(data)
    if type(message) ~= "table" then
        return
    end

    if message.type == "intent" and message.playerId and message.payload then
        self:applyIntent(message.playerId, message.payload)
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

    -- Always spawn a new player entity for connecting clients
    -- The host player is already initialized and doesn't connect as a client
    local entity = Entities.spawnPlayer(self.state, { playerId = playerId })
    if entity then
        self.state.players[playerId] = entity
    end

    Intent.ensure(self.state, playerId)
    
    if self.onPlayerJoined then
        self.onPlayerJoined(peer, entity, playerId)
    end
end

function Server:broadcastSnapshot()
    local snapshot = Snapshot.capture(self.state)
    if not snapshot then
        return
    end

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

    self.transport:update(0)

    self.snapshotTimer = self.snapshotTimer + dt
    if self.snapshotTimer >= self.snapshotInterval then
        self.snapshotTimer = self.snapshotTimer - self.snapshotInterval
        self:broadcastSnapshot()
    end
end

return Server
