local Transport = require("src.network.transport")
local Snapshot = require("src.network.snapshot")
local PlayerManager = require("src.player.manager")
local Intent = require("src.input.intent")

local love = love

local NetworkManager = {}
NetworkManager.__index = NetworkManager

local function encode_message(message)
    if not (love and love.data and love.data.encode) then
        return nil
    end
    return love.data.encode("string", "json", message)
end

local function decode_message(data)
    if not (love and love.data and love.data.decode) then
        return nil
    end
    local ok, decoded = pcall(love.data.decode, "string", "json", data)
    if ok then
        return decoded
    end
end

local function format_address(host, port)
    host = host or "127.0.0.1"
    if type(port) ~= "number" then
        port = tonumber(port) or 22122
    end
    return string.format("%s:%d", host, port)
end

function NetworkManager.new(config)
    config = config or {}

    local self = setmetatable({
        state = assert(config.state, "NetworkManager requires a gameplay state reference"),
        snapshotInterval = config.snapshotInterval or 0.1,
        intentInterval = config.intentInterval or 0.05,
        snapshotTimer = 0,
        intentTimer = 0,
        connected = false,
        host = config.host or "127.0.0.1",
        port = tonumber(config.port) or 22122,
    }, NetworkManager)

    self.client = Transport.createClient({
        host = self.host,
        port = self.port,
        channels = config.channels,
        onConnect = function(peer)
            self.connected = true
            if config.onConnect then
                config.onConnect(peer)
            end
        end,
        onDisconnect = function(peer, code)
            self.connected = false
            if config.onDisconnect then
                config.onDisconnect(peer, code)
            end
        end,
        onReceive = function(data, channel)
            self:handleMessage(data, channel)
        end,
        onTimeout = function(peer)
            self.connected = false
            if config.onTimeout then
                config.onTimeout(peer)
            end
        end,
    })

    self.client.address = format_address(self.host, self.port)

    if config.autoConnect ~= false then
        self:connect()
    end

    return self
end

function NetworkManager:connect()
    if self.client then
        self.client.address = format_address(self.host, self.port)
        self.client:connect()
    end
end

function NetworkManager:disconnect(code)
    if self.client then
        self.client:disconnect(code)
    end
    self.connected = false
end

function NetworkManager:shutdown()
    if self.client then
        self.client:disconnect()
    end
    self.connected = false
end

function NetworkManager:handleMessage(data, _channel)
    local message = decode_message(data)
    if type(message) ~= "table" then
        return
    end

    if message.type == "snapshot" and message.payload then
        Snapshot.apply(self.state, message.payload)
    elseif message.type == "intent" and message.playerId and message.payload then
        self:applyRemoteIntent(message.playerId, message.payload)
    end
end

function NetworkManager:applyRemoteIntent(playerId, payload)
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
    intent.firePrimary = payload.firePrimary or false
    intent.fireSecondary = payload.fireSecondary or false
end

function NetworkManager:sendSnapshot()
    if not self.connected then
        return
    end

    local snapshot = Snapshot.capture(self.state)
    if not snapshot then
        return
    end

    local payload = encode_message({
        type = "snapshot",
        payload = snapshot,
    })

    if payload then
        self.client:send(payload, 0, true)
    end
end

function NetworkManager:sendLocalIntent()
    if not self.connected then
        return
    end

    local ship = PlayerManager.getCurrentShip(self.state)
    if not ship then
        return
    end

    local intents = self.state.playerIntents
    local intent = intents and intents[ship.playerId]
    if not intent then
        return
    end

    local payload = encode_message({
        type = "intent",
        playerId = ship.playerId,
        payload = {
            moveX = intent.moveX,
            moveY = intent.moveY,
            moveMagnitude = intent.moveMagnitude,
            aimX = intent.aimX,
            aimY = intent.aimY,
            hasAim = intent.hasAim,
            firePrimary = intent.firePrimary,
            fireSecondary = intent.fireSecondary,
        },
    })

    if payload then
        self.client:send(payload, 0, false)
    end
end

function NetworkManager:update(dt)
    if not self.client then
        return
    end

    self.client:update(0)

    if not self.connected then
        return
    end

    self.snapshotTimer = self.snapshotTimer + dt
    self.intentTimer = self.intentTimer + dt

    if self.intentTimer >= self.intentInterval then
        self.intentTimer = self.intentTimer - self.intentInterval
        self:sendLocalIntent()
    end

    if self.snapshotTimer >= self.snapshotInterval then
        self.snapshotTimer = self.snapshotTimer - self.snapshotInterval
        self:sendSnapshot()
    end
end

function NetworkManager:setAddress(host, port)
    if host then
        self.host = host
    end
    if port then
        self.port = tonumber(port) or self.port
    end

    if self.client then
        self.client.address = format_address(self.host, self.port)
    end
end

function NetworkManager:getAddress()
    return self.host, self.port
end

return NetworkManager
