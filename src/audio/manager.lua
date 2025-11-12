---@diagnostic disable: undefined-global

local love = love

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local DEFAULT_MASTER_VOLUME = 0.1

local SOUND_EXTENSIONS = {
    ogg = true,
    wav = true,
    mp3 = true,
    flac = true,
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function clamp01(value)
    if value == nil then return 1 end
    return math.max(0, math.min(1, value))
end

local function normalize_id(id)
    if type(id) ~= "string" then return nil end
    
    id = id:gsub("%s+", "_")
    id = id:gsub("::", ":")
    id = id:lower()
    return id
end

local function ensure_forward_slashes(path)
    return (path or ""):gsub("\\", "/")
end

local function normalize_directory_key(path)
    path = ensure_forward_slashes(path or "")
    path = path:gsub("/+", "/")
    
    if #path > 1 and path:sub(-1) == "/" then
        path = path:sub(1, -2)
    end
    
    return path
end

local function build_identifier(basePath, filePath, prefix)
    filePath = ensure_forward_slashes(filePath)
    basePath = ensure_forward_slashes(basePath or "")

    -- Extract relative path
    local relative = filePath
    if basePath ~= "" and filePath:sub(1, #basePath) == basePath then
        relative = filePath:sub(#basePath + 1)
        if relative:sub(1, 1) == "/" then
            relative = relative:sub(2)
        end
    end

    -- Remove extension and convert path separators
    relative = relative:gsub("%.[%w]+$", "")
    relative = relative:gsub("/", ":")

    -- Add prefix if provided
    if prefix and prefix ~= "" then
        relative = (relative ~= "") and (prefix .. ":" .. relative) or prefix
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

local function scan_directory(basePath, onFile)
    if not (love and love.filesystem and love.filesystem.getInfo) then
        return
    end

    basePath = ensure_forward_slashes(basePath)

    local info = love.filesystem.getInfo(basePath)
    if not info or info.type ~= "directory" then
        return
    end

    local visited = {}

    local function recurse(path)
        local normalizedPath = normalize_directory_key(path)
        if visited[normalizedPath] then return end
        
        visited[normalizedPath] = true

        local ok, items = pcall(love.filesystem.getDirectoryItems, path)
        if not ok or not items then return end

        for _, item in ipairs(items) do
            if item ~= "." and item ~= ".." then
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
    end

    recurse(basePath)
end

-- ============================================================================
-- AUDIO MANAGER
-- ============================================================================

local AudioManager = {
    -- State
    _initialized = false,
    _sfx = {},
    _music = {},
    _currentMusic = nil,
    _currentMusicName = nil,
    _currentMusicVolume = DEFAULT_MASTER_VOLUME,
    
    -- Volume settings
    masterVolume = DEFAULT_MASTER_VOLUME,
    musicVolume = 1,
    sfxVolume = 1,
    
    -- Constants
    DEFAULT_MASTER_VOLUME = DEFAULT_MASTER_VOLUME,
}

-- ============================================================================
-- PRIVATE METHODS
-- ============================================================================

local function compute_sfx_volume(entryVolume, overrideVolume)
    return clamp01(
        (entryVolume or 1) * 
        (overrideVolume or 1) * 
        AudioManager.sfxVolume * 
        AudioManager.masterVolume
    )
end

local function compute_music_volume(entryVolume, overrideVolume)
    return clamp01(
        (entryVolume or 1) * 
        (overrideVolume or 1) * 
        AudioManager.musicVolume * 
        AudioManager.masterVolume
    )
end

local function update_current_music_volume()
    if not AudioManager._currentMusic or not AudioManager._currentMusic:isPlaying() then
        return
    end

    local entry = AudioManager._music[AudioManager._currentMusicName]
    if not entry then return end

    local totalVolume = compute_music_volume(entry.volume, entry._lastOverrideVolume)
    AudioManager._currentMusic:setVolume(totalVolume)
    AudioManager._currentMusicVolume = totalVolume
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

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

    -- Set volume levels
    AudioManager.masterVolume = clamp01(options.masterVolume or AudioManager.masterVolume)
    AudioManager.musicVolume = clamp01(options.musicVolume or AudioManager.musicVolume)
    AudioManager.sfxVolume = clamp01(options.sfxVolume or AudioManager.sfxVolume)

    if AudioManager._initialized then
        update_current_music_volume()
        return
    end

    -- Auto-scan directories if enabled
    if options.autoScan ~= false then
        local sfxOptions = options.sfx or {}
        sfxOptions.prefix = sfxOptions.prefix or "sfx"
        
        local musicOptions = options.music or {}
        musicOptions.prefix = musicOptions.prefix or "music"

        AudioManager.import_sfx_directory(options.sfxPath or "assets/sounds", sfxOptions)
        AudioManager.import_music_directory(options.musicPath or "assets/music", musicOptions)
    end

    AudioManager._initialized = true
    
    if love and love.audio and love.audio.setVolume then
        love.audio.setVolume(AudioManager.masterVolume)
    end
    
    update_current_music_volume()
end

function AudioManager.get_default_master_volume()
    return DEFAULT_MASTER_VOLUME
end

-- ============================================================================
-- IMPORTING AUDIO
-- ============================================================================

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

    local loop = (options.loop ~= nil) and options.loop or true
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

-- ============================================================================
-- PLAYBACK CONTROL
-- ============================================================================

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

    -- Create instance
    local instance = entry.source.clone and entry.source:clone()
    
    if not instance then
        local source, err = new_source(entry.path, "static")
        if not source then
            return nil, err
        end
        instance = source
    end

    -- Configure and play
    if instance.setPitch then
        instance:setPitch(options.pitch or 1)
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

    -- Stop current music if different
    if AudioManager._currentMusic and AudioManager._currentMusic ~= source then
        AudioManager._currentMusic:stop()
    end

    -- Handle restart and force options
    if options.restart then
        source:stop()
    elseif AudioManager._currentMusicName == identifier and 
           source:isPlaying() and 
           not options.force then
        entry._lastOverrideVolume = options.volume or entry._lastOverrideVolume
        update_current_music_volume()
        return source
    end

    -- Configure looping
    local loop = (options.loop ~= nil) and options.loop or entry.loop
    source:setLooping(loop)

    -- Set volume and play
    entry._lastOverrideVolume = options.volume or entry._lastOverrideVolume
    local totalVolume = compute_music_volume(entry.volume, entry._lastOverrideVolume)
    source:setVolume(totalVolume)
    source:play()

    -- Update state
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

-- ============================================================================
-- VOLUME CONTROL
-- ============================================================================

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

-- ============================================================================
-- GETTERS
-- ============================================================================

function AudioManager.get_loaded_sfx()
    return AudioManager._sfx
end

function AudioManager.get_loaded_music()
    return AudioManager._music
end

return AudioManager
