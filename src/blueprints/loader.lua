local table_util = require("src.util.table")
local Blueprint = require("src.blueprints.blueprint")

local loader = {}

local registry = {}
local factories = {}
local validation_cache = {} -- Cache validated blueprints to avoid expensive re-validation

local function module_key(category, id)
    return string.format("%s:%s", category, id)
end

local function resolve_module_path(category, id)
    return string.format("src.blueprints.%s.%s", category, id)
end

local function load_blueprint_chunk(module_path)
    if package and package.loaded then
        package.loaded[module_path] = nil
    end

    if package and package.searchpath then
        local file_path = package.searchpath(module_path, package.path)
        if file_path then
            local chunk, err = loadfile(file_path)
            if not chunk then
                return nil, err
            end
            return chunk
        end
    end

    if love and love.filesystem and love.filesystem.load then
        local fs_path = module_path:gsub("%.", "/") .. ".lua"
        local chunk, err = love.filesystem.load(fs_path)
        if not chunk then
            return nil, err
        end
        return chunk
    end

    return nil, string.format("Unable to locate module '%s'", module_path)
end

local function fetch_entry(category, id)
    local key = module_key(category, id)
    local entry = registry[key]
    if entry then
        return entry
    end

    local module_path = resolve_module_path(category, id)
    local chunk, load_err = load_blueprint_chunk(module_path)
    if not chunk then
        error(string.format("Failed to load blueprint '%s/%s': %s", category, id, load_err), 3)
    end

    local ok, mod = pcall(chunk, module_path)
    if not ok then
        error(string.format("Failed to load blueprint '%s/%s': %s", category, id, mod), 3)
    end

    local kind = type(mod)
    if kind ~= "table" and kind ~= "function" then
        error(string.format("Blueprint module '%s/%s' must return a table or function, got %s", category, id, kind), 3)
    end

    entry = { kind = kind, value = mod, module_path = module_path }
    registry[key] = entry
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
function loader.clear_module_cache()
    for key, entry in pairs(registry) do
        if entry.module_path and package and package.loaded then
            package.loaded[entry.module_path] = nil
        end
        registry[key] = nil
    end
end

--- Get cache statistics for debugging
function loader.get_cache_stats()
    local module_count = 0
    local validation_count = 0
    
    for _ in pairs(registry) do
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
