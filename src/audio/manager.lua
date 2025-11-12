---@diagnostic disable: undefined-global

local love = love

local DEFAULT_MASTER_VOLUME = 0.1

local AudioManager = {
    _initialized = false,
    _sfx = {},
    _music = {},
    _currentMusic = nil,
    _currentMusicName = nil,
    _currentMusicVolume = DEFAULT_MASTER_VOLUME,
    masterVolume = DEFAULT_MASTER_VOLUME,
    musicVolume = 1,
    sfxVolume = 1,
}

AudioManager.DEFAULT_MASTER_VOLUME = DEFAULT_MASTER_VOLUME

function AudioManager.get_default_master_volume()
    return DEFAULT_MASTER_VOLUME
end

local SOUND_EXTENSIONS = {
    ogg = true,
    wav = true,
    mp3 = true,
    flac = true,
}

local function clamp01(value)
    if value == nil then
        return 1
    end
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function normalize_id(id)
    if type(id) ~= "string" then
        return nil
    end
    id = id:gsub("%s+", "_")
    id = id:gsub("::", ":")
    id = id:lower()
    return id
end

local function ensure_forward_slashes(path)
    return (path or ""):gsub("\\", "/")
end

local function build_identifier(basePath, filePath, prefix)
    filePath = ensure_forward_slashes(filePath)
    basePath = ensure_forward_slashes(basePath or "")

    local relative = filePath
    if basePath ~= "" and filePath:sub(1, #basePath) == basePath then
        relative = filePath:sub(#basePath + 1)
        if relative:sub(1, 1) == "/" then
            relative = relative:sub(2)
        end
    end

    relative = relative:gsub("%.[%w]+$", "")
    relative = relative:gsub("/", ":")

    if prefix and prefix ~= "" then
        if relative ~= "" then
            relative = prefix .. ":" .. relative
        else
            relative = prefix
        end
    end

    return normalize_id(relative)
end

local function new_source(path, sourceType)
    if not love or not love.audio or not love.audio.newSource then
        return nil, "Audio module unavailable"
    end

    local ok, source = pcall(love.audio.newSource, path, sourceType)
    if not ok then
        return nil, source
    end

    return source, nil
end

local function compute_sfx_volume(entryVolume, overrideVolume)
    entryVolume = entryVolume or 1
    overrideVolume = overrideVolume or 1
    return clamp01(entryVolume * overrideVolume * AudioManager.sfxVolume * AudioManager.masterVolume)
end

local function compute_music_volume(entryVolume, overrideVolume)
    entryVolume = entryVolume or 1
    overrideVolume = overrideVolume or 1
    return clamp01(entryVolume * overrideVolume * AudioManager.musicVolume * AudioManager.masterVolume)
end

local function update_current_music_volume()
    if not AudioManager._currentMusic or not AudioManager._currentMusic:isPlaying() then
        return
    end

    local entry = AudioManager._music[AudioManager._currentMusicName]
    if not entry then
        return
    end

    local totalVolume = compute_music_volume(entry.volume, entry._lastOverrideVolume)
    AudioManager._currentMusic:setVolume(totalVolume)
    AudioManager._currentMusicVolume = totalVolume
end

local function scan_directory(basePath, onFile)
    if not (love and love.filesystem and love.filesystem.getInfo) then
        return
    end

    basePath = ensure_forward_slashes(basePath)

    local info = love.filesystem.getInfo(basePath)
    if not info or info.type ~= "directory" then
        return
    end

    local function recurse(path)
        local items = love.filesystem.getDirectoryItems(path)
        for _, item in ipairs(items) do
            local fullPath = path .. "/" .. item
            local itemInfo = love.filesystem.getInfo(fullPath)
            if itemInfo then
                if itemInfo.type == "directory" then
                    recurse(fullPath)
                elseif itemInfo.type == "file" then
                    onFile(fullPath)
                end
            end
        end
    end

    recurse(basePath)
end

function AudioManager.is_initialized()
    return AudioManager._initialized
end

function AudioManager.ensure_initialized()
    if not AudioManager._initialized then
        AudioManager.initialize()
    end
end

function AudioManager.initialize(options)
    options = options or {}

    AudioManager.masterVolume = clamp01(options.masterVolume or AudioManager.masterVolume)
    AudioManager.musicVolume = clamp01(options.musicVolume or AudioManager.musicVolume)
    AudioManager.sfxVolume = clamp01(options.sfxVolume or AudioManager.sfxVolume)

    if AudioManager._initialized then
        update_current_music_volume()
        return
    end

    if options.autoScan ~= false then
        local sfxOptions = {}
        for key, value in pairs(options.sfx or {}) do
            sfxOptions[key] = value
        end
        if sfxOptions.prefix == nil then
            sfxOptions.prefix = "sfx"
        end

        local musicOptions = {}
        for key, value in pairs(options.music or {}) do
            musicOptions[key] = value
        end
        if musicOptions.prefix == nil then
            musicOptions.prefix = "music"
        end

        AudioManager.import_sfx_directory(options.sfxPath or "assets/sounds", sfxOptions)
        AudioManager.import_music_directory(options.musicPath or "assets/music", musicOptions)
    end

    AudioManager._initialized = true
    if love and love.audio and love.audio.setVolume then
        love.audio.setVolume(AudioManager.masterVolume)
    end
    update_current_music_volume()
end

function AudioManager.import_sfx(id, path, options)
    options = options or {}
    local identifier = normalize_id(id) or build_identifier("", path, options.prefix)
    if not identifier or identifier == "" then
        return nil, "Invalid sound identifier"
    end

    path = ensure_forward_slashes(path)
    local source, err = new_source(path, options.sourceType or "static")
    if not source then
        return nil, err
    end

    source:setLooping(false)

    AudioManager._sfx[identifier] = {
        id = identifier,
        path = path,
        source = source,
        volume = clamp01(options.volume or 1),
    }

    return identifier, source
end

function AudioManager.import_music(id, path, options)
    options = options or {}
    local identifier = normalize_id(id) or build_identifier("", path, options.prefix)
    if not identifier or identifier == "" then
        return nil, "Invalid music identifier"
    end

    path = ensure_forward_slashes(path)
    local sourceType = options.sourceType or "stream"
    local source, err = new_source(path, sourceType)
    if not source then
        return nil, err
    end

    local loop = options.loop
    if loop == nil then
        loop = true
    end

    source:setLooping(loop)

    AudioManager._music[identifier] = {
        id = identifier,
        path = path,
        source = source,
        volume = clamp01(options.volume or 1),
        loop = loop,
        _lastOverrideVolume = options.volumeOverride,
    }

    return identifier, source
end

function AudioManager.import_sfx_directory(basePath, options)
    options = options or {}
    scan_directory(basePath, function(filePath)
        local extension = filePath:match("%.([%w]+)$")
        if extension and SOUND_EXTENSIONS[extension:lower()] then
            local identifier = build_identifier(basePath, filePath, options.prefix)
            if identifier then
                AudioManager.import_sfx(identifier, filePath, {
                    volume = options.volume,
                    sourceType = options.sourceType,
                })
            end
        end
    end)
end

function AudioManager.import_music_directory(basePath, options)
    options = options or {}
    scan_directory(basePath, function(filePath)
        local extension = filePath:match("%.([%w]+)$")
        if extension and SOUND_EXTENSIONS[extension:lower()] then
            local identifier = build_identifier(basePath, filePath, options.prefix)
            if identifier then
                AudioManager.import_music(identifier, filePath, {
                    volume = options.volume,
                    loop = options.loop,
                    sourceType = options.sourceType,
                })
            end
        end
    end)
end

function AudioManager.play_sfx(id, options)
    AudioManager.ensure_initialized()

    if not (love and love.audio) then
        return nil, "Audio module unavailable"
    end

    options = options or {}
    local identifier = normalize_id(id)
    local entry = identifier and AudioManager._sfx[identifier]
    if not entry then
        return nil, "Unknown sound effect: " .. tostring(id)
    end

    local instance
    if entry.source.clone then
        instance = entry.source:clone()
    end

    if not instance then
        local source, err = new_source(entry.path, "static")
        if not source then
            return nil, err
        end
        instance = source
    end

    local pitch = options.pitch or 1
    if instance.setPitch then
        instance:setPitch(pitch)
    end

    local volume = compute_sfx_volume(entry.volume, options.volume)
    instance:setVolume(volume)

    instance:setLooping(false)
    instance:play()

    return instance
end

function AudioManager.play_music(id, options)
    AudioManager.ensure_initialized()

    if not (love and love.audio) then
        return nil, "Audio module unavailable"
    end

    options = options or {}
    local identifier = normalize_id(id)
    local entry = identifier and AudioManager._music[identifier]
    if not entry then
        return nil, "Unknown music track: " .. tostring(id)
    end

    local source = entry.source

    if AudioManager._currentMusic and AudioManager._currentMusic ~= source then
        AudioManager._currentMusic:stop()
    end

    if options.restart then
        source:stop()
    elseif AudioManager._currentMusicName == identifier and source:isPlaying() and not options.force then
        entry._lastOverrideVolume = options.volume or entry._lastOverrideVolume
        update_current_music_volume()
        return source
    end

    local loop = options.loop
    if loop == nil then
        loop = entry.loop
    end
    source:setLooping(loop)

    entry._lastOverrideVolume = options.volume or entry._lastOverrideVolume
    local totalVolume = compute_music_volume(entry.volume, entry._lastOverrideVolume)
    source:setVolume(totalVolume)

    source:play()

    AudioManager._currentMusic = source
    AudioManager._currentMusicName = identifier
    AudioManager._currentMusicVolume = totalVolume

    return source
end

function AudioManager.stop_music()
    if AudioManager._currentMusic then
        AudioManager._currentMusic:stop()
    end
    AudioManager._currentMusic = nil
    AudioManager._currentMusicName = nil
    AudioManager._currentMusicVolume = 0
end

function AudioManager.pause_music()
    if AudioManager._currentMusic then
        AudioManager._currentMusic:pause()
    end
end

function AudioManager.resume_music()
    if AudioManager._currentMusic then
        AudioManager._currentMusic:play()
        update_current_music_volume()
    end
end

function AudioManager.set_master_volume(value)
    AudioManager.masterVolume = clamp01(value or 1)
    if love and love.audio and love.audio.setVolume then
        love.audio.setVolume(AudioManager.masterVolume)
    end
    update_current_music_volume()
end

function AudioManager.set_music_volume(value)
    AudioManager.musicVolume = clamp01(value or 1)
    update_current_music_volume()
end

function AudioManager.set_sfx_volume(value)
    AudioManager.sfxVolume = clamp01(value or 1)
end

function AudioManager.get_master_volume()
    return AudioManager.masterVolume
end

function AudioManager.get_music_volume()
    return AudioManager.musicVolume
end

function AudioManager.get_sfx_volume()
    return AudioManager.sfxVolume
end

function AudioManager.get_loaded_sfx()
    return AudioManager._sfx
end

function AudioManager.get_loaded_music()
    return AudioManager._music
end

return AudioManager
