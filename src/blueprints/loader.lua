local table_util = require("src.util.table")
local Blueprint = require("src.blueprints.blueprint")

local loader = {}

local blueprint_cache = {}
local factories = {}
local validation_cache = {} -- Cache validated blueprints to avoid expensive re-validation

local function module_key(category, id)
    return string.format("%s:%s", category, id)
end

local function resolve_module_path(category, id)
    return string.format("src.blueprints.%s.%s", category, id)
end

local function resolve_filesystem_path(category, id)
    return string.format("src/blueprints/%s/%s.lua", category, id)
end

local function read_file(path)
    local file, err = io.open(path, "rb")
    if not file then
        return nil, err
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function read_blueprint_source(category, id)
    local fs_path = resolve_filesystem_path(category, id)
    local last_err

    if love and love.filesystem and love.filesystem.read then
        local contents, read_err = love.filesystem.read(fs_path)
        if contents then
            return contents, fs_path
        end
        last_err = read_err or string.format("Unable to read blueprint file '%s'", fs_path)
    end

    if love and love.filesystem and love.filesystem.read then
        local module_path = resolve_module_path(category, id)
        local lua_path = string.gsub(module_path, "%.", "/") .. ".lua"
        local contents, read_err = love.filesystem.read(lua_path)
        if contents then
            return contents, lua_path
        end
        last_err = last_err or read_err
    end

    if package and package.searchpath then
        local module_path = resolve_module_path(category, id)
        local file_path = package.searchpath(module_path, package.path)
        if file_path then
            local contents, io_err = read_file(file_path)
            if contents then
                return contents, file_path
            end
            last_err = last_err or io_err or string.format("Failed to read '%s'", file_path)
        end
    end

    return nil, last_err or string.format("Unable to locate blueprint '%s/%s'", category, id)
end

local function create_blueprint_environment(category, id, chunk_name)
    local env = {
        __BLUEPRINT_CATEGORY__ = category,
        __BLUEPRINT_ID__ = id,
        __BLUEPRINT_CHUNKNAME__ = chunk_name,
    }

    env._G = env

    return setmetatable(env, {
        __index = _G,
    })
end

local function fetch_entry(category, id)
    local key = module_key(category, id)
    local entry = blueprint_cache[key]
    if entry then
        return entry
    end

    local source, origin_or_err = read_blueprint_source(category, id)
    if not source then
        error(string.format("Failed to load blueprint '%s/%s': %s", category, id, origin_or_err), 3)
    end

    local source_path = origin_or_err
    local chunk_name = string.format("@%s", source_path)
    local chunk, syntax_err = loadstring(source, chunk_name)
    if not chunk then
        error(string.format("Failed to parse blueprint '%s/%s': %s", category, id, syntax_err), 3)
    end

    local env = create_blueprint_environment(category, id, chunk_name)
    setfenv(chunk, env)

    local ok, mod = pcall(chunk)
    if not ok then
        error(string.format("Failed to execute blueprint '%s/%s': %s", category, id, mod), 3)
    end

    local kind = type(mod)
    if kind ~= "table" and kind ~= "function" then
        error(string.format("Blueprint '%s/%s' must return a table or function, got %s", category, id, kind), 3)
    end

    entry = { kind = kind, value = mod, path = source_path }
    blueprint_cache[key] = entry

    return entry
end

local function materialize_blueprint(entry, params)
    if entry.kind == "table" then
        return table_util.deep_copy(entry.value)
    end

    local blueprint = entry.value(params)
    if type(blueprint) ~= "table" then
        error("Blueprint factory functions must return a table", 3)
    end
    return blueprint
end

function loader.register_factory(category, factory)
    assert(type(category) == "string" and category ~= "", "category must be a non-empty string")
    assert(type(factory) == "table", "factory must be a table")
    assert(type(factory.instantiate) == "function", "factory must expose an instantiate(context, params) function")
    factories[category] = factory
end

function loader.load(category, id, params)
    assert(type(category) == "string" and category ~= "", "category must be a non-empty string")
    assert(type(id) == "string" and id ~= "", "id must be a non-empty string")

    local entry = fetch_entry(category, id)
    local blueprint = materialize_blueprint(entry, params)
    blueprint.category = blueprint.category or category
    blueprint.id = blueprint.id or id

    -- Check validation cache first (only for static blueprints without params)
    local cache_key = params and nil or module_key(category, id)
    local is_cached = cache_key and validation_cache[cache_key]

    if not is_cached then
        local ok, errors = Blueprint.validate(category, blueprint)
        if not ok then
            local header = string.format("Blueprint '%s/%s'", category, id)
            local formatted
            if type(errors) == "table" then
                formatted = Blueprint.format_errors(errors)
            else
                formatted = tostring(errors)
            end
            if formatted and #formatted > 0 then
                error(string.format("%s failed validation:\n - %s", header, formatted), 3)
            else
                error(string.format("%s failed validation", header), 3)
            end
        end

        -- Cache validation result for static blueprints
        if cache_key then
            validation_cache[cache_key] = true
        end
    end

    return blueprint
end

function loader.instantiate(category, id, context, params)
    local factory = factories[category]
    if not factory then
        error(string.format("No factory registered for category '%s'", tostring(category)), 2)
    end

    local blueprint = loader.load(category, id, params)
    return factory.instantiate(blueprint, context or {})
end

--- Clear validation cache (useful for development/hot-reloading)
function loader.clear_validation_cache()
    for key in pairs(validation_cache) do
        validation_cache[key] = nil
    end
end

--- Clear module registry (forces re-require on next load)
function loader.clear_cache()
    for key in pairs(blueprint_cache) do
        blueprint_cache[key] = nil
    end
    loader.clear_validation_cache()
end

function loader.clear_module_cache()
    loader.clear_cache()
end

--- Get cache statistics for debugging
function loader.get_cache_stats()
    local module_count = 0
    local validation_count = 0

    for _ in pairs(blueprint_cache) do
        module_count = module_count + 1
    end

    for _ in pairs(validation_cache) do
        validation_count = validation_count + 1
    end
    
    return {
        modules_cached = module_count,
        validations_cached = validation_count,
    }
end

return loader
