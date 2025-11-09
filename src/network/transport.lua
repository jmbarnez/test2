local Transport = {}

-- Set to true to enable network debug logging
local DEBUG_NETWORK = false

local function debug_print(...)
    if DEBUG_NETWORK then
        print(...)
    end
end

local function extend_cpath()
    local path_sep = package.config:sub(1, 1)
    local patterns = {
        table.concat({ "libs", "enet", "?.dll" }, path_sep),
        table.concat({ "libs", "enet", "?", "?.dll" }, path_sep),
    }

    for _, pattern in ipairs(patterns) do
        if not package.cpath:find(pattern, 1, true) then
            package.cpath = package.cpath .. ";" .. pattern
        end
    end
end

local function load_enet()
    local ok, enet = pcall(require, "enet")
    if ok then
        return enet
    end

    extend_cpath()
    ok, enet = pcall(require, "enet")
    if not ok then
        error("Failed to load lua-enet module: " .. tostring(enet))
    end
    return enet
end

local function format_address(config)
    local host = config.host or config.address or "127.0.0.1"
    local port = config.port or 22122
    local channel_limit = config.channels and (":" .. tostring(config.channels)) or ""
    return string.format("%s:%d%s", host, port, channel_limit)
end

local function wrap_callbacks(instance, config)
    instance.onConnect = config.onConnect
    instance.onDisconnect = config.onDisconnect
    instance.onReceive = config.onReceive
    instance.onTimeout = config.onTimeout
end

local function safe_callback(callback, ...)
    if not callback then
        return true
    end
    local success, err = pcall(callback, ...)
    if not success then
        debug_print("Callback error:", err)
    end
    return success
end

function Transport.createServer(config)
    config = config or {}
    local enet = load_enet()

    local address = format_address(config)
    local max_clients = config.maxClients or 32

    local ok, host = pcall(function() 
        return enet.host_create(address, max_clients, config.channels or 2, config.bandwidthIn or 0, config.bandwidthOut or 0)
    end)
    if not ok then
        error("Failed to create ENet server host on " .. address .. ": " .. tostring(host))
    end
    if not host then
        error("Failed to create ENet server host on " .. address .. ": host_create returned nil")
    end

    local server = {
        enet = enet,
        host = host,
        peers = {},
    }

    wrap_callbacks(server, config)

    function server:broadcast(data, channel, reliable)
        local flags = reliable and "reliable" or "unreliable"
        local ok, err = pcall(function() self.host:broadcast(data, channel or 0, flags) end)
        if not ok then
            debug_print("Server broadcast error:", err)
            return false
        end
        return true
    end

    function server:send(peer, data, channel, reliable)
        if not peer then
            return false
        end
        local flags = reliable and "reliable" or "unreliable"
        local ok, err = pcall(function() peer:send(data, channel or 0, flags) end)
        if not ok then
            debug_print("Server send error:", err)
            return false
        end
        return true
    end

    function server:update(timeout)
        timeout = timeout or 0
        local ok, event = pcall(function() return self.host:service(timeout) end)
        if not ok then
            debug_print("ENet server service error:", event)
            return
        end
        
        while event do
            if event.type == "connect" then
                self.peers[event.peer:index()] = event.peer
                safe_callback(self.onConnect, event.peer)
            elseif event.type == "disconnect" then
                self.peers[event.peer:index()] = nil
                safe_callback(self.onDisconnect, event.peer, event.data)
            elseif event.type == "receive" then
                safe_callback(self.onReceive, event.peer, event.data, event.channel)
                if event.packet then
                    event.packet:destroy()
                end
            elseif event.type == "timeout" then
                self.peers[event.peer:index()] = nil
                safe_callback(self.onTimeout, event.peer)
            end
            
            ok, event = pcall(function() return self.host:service(0) end)
            if not ok then
                debug_print("ENet server service error during event loop:", event)
                break
            end
        end
    end

    function server:shutdown(code)
        for _, peer in pairs(self.peers) do
            pcall(function() peer:disconnect_later(code or 0) end)
        end
        pcall(function() self.host:flush() end)
        self.peers = {}
    end

    return server
end

function Transport.createClient(config)
    config = config or {}
    local enet = load_enet()

    local ok, host = pcall(function() return enet.host_create(nil, config.channels or 2) end)
    if not ok then
        error("Failed to create ENet client host: " .. tostring(host))
    end
    if not host then
        error("Failed to create ENet client host: host_create returned nil")
    end

    local client = {
        enet = enet,
        host = host,
        peer = nil,
        address = format_address(config),
    }

    wrap_callbacks(client, config)

    function client:connect()
        if self.peer then
            pcall(function() self.peer:disconnect_now() end)
            self.peer = nil
        end
        
        local ok, result = pcall(function() return self.host:connect(self.address) end)
        if not ok then
            error("Failed to initiate connection to " .. self.address .. ": " .. tostring(result))
        end
        
        self.peer = result
        if not self.peer then
            error("Failed to initiate connection to " .. self.address)
        end
        return self.peer
    end

    function client:send(data, channel, reliable)
        if not self.peer then
            return false
        end
        local flags = reliable and "reliable" or "unreliable"
        local ok, err = pcall(function() self.peer:send(data, channel or 0, flags) end)
        if not ok then
            debug_print("Client send error:", err)
            return false
        end
        return true
    end

    function client:update(timeout)
        timeout = timeout or 0
        local ok, event = pcall(function() return self.host:service(timeout) end)
        if not ok then
            debug_print("ENet client service error:", event)
            return
        end
        
        while event do
            if event.type == "connect" then
                safe_callback(self.onConnect, event.peer)
            elseif event.type == "disconnect" then
                safe_callback(self.onDisconnect, event.peer, event.data)
                self.peer = nil
            elseif event.type == "receive" then
                safe_callback(self.onReceive, event.data, event.channel)
                if event.packet then
                    event.packet:destroy()
                end
            elseif event.type == "timeout" then
                safe_callback(self.onTimeout, event.peer)
                self.peer = nil
            end
            
            ok, event = pcall(function() return self.host:service(0) end)
            if not ok then
                debug_print("ENet client service error during event loop:", event)
                break
            end
        end
    end

    function client:disconnect(code)
        if self.peer then
            pcall(function() self.peer:disconnect(code or 0) end)
            self.peer = nil
        end
    end

    return client
end

return Transport
