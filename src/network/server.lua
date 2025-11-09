local Transport = require("src.network.transport")
local Snapshot = require("src.network.snapshot")
local Intent = require("src.input.intent")
local Entities = require("src.states.gameplay.entities")
local PlayerManager = require("src.player.manager")

local love = love

local Server = {}
Server.__index = Server

local function encode_message(message)
    if love and love.data and love.data.encode then
        return love.data.encode("string", "json", message)
    end
end

local function decode_message(data)
    if love and love.data and love.data.decode then
        local ok, decoded = pcall(love.data.decode, "string", "json", data)
        if ok then
            return decoded
        end
    end
end

function Server.new(config)
    config = config or {}
    local state = assert(config.state, "Server requires gameplay state")
    local host = config.host or "0.0.0.0"
    local port = config.port or 22122

    local self = setmetatable({
        state = state,
        host = host,
        port = port,
        peers = {},
        peerPlayers = {},
        playerSeq = 0,
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

    return self
end

function Server:shutdown()
    if self.transport then
        self.transport:shutdown(0)
    end
    self.peers = {}
    self.peerPlayers = {}
end

function Server:onConnect(peer)
    self.playerSeq = self.playerSeq + 1
    local playerId = string.format("player_%03d", self.playerSeq)
    self.peers[peer:index()] = peer
    self.peerPlayers[peer:index()] = playerId

    self:spawnPlayerForPeer(peer, playerId)

    local snapshot = Snapshot.capture(self.state)
    if snapshot then
        local payload = encode_message({ type = "snapshot", payload = snapshot })
        if payload then
            self.transport:send(peer, payload, 0, true)
        end
    end
end

function Server:onDisconnect(peer, _code)
    local index = peer:index()
    local playerId = self.peerPlayers[index]
    self.peers[index] = nil
    self.peerPlayers[index] = nil

    if playerId and self.state and self.state.players then
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

    local entity
    local currentShip = PlayerManager.getCurrentShip(self.state)
    if not next(self.state.players) and currentShip then
        -- Reuse local player for first peer (host)
        entity = currentShip
        entity.playerId = playerId
        self.state.players[playerId] = entity
        self.state.localPlayerId = playerId
    else
        entity = Entities.spawnPlayer(self.state, { playerId = playerId })
        if entity then
            self.state.players[playerId] = entity
        end
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
