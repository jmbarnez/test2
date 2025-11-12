local table_util = require("src.util.table")
local Blueprint = require("src.blueprints.blueprint")

local loader = {}

local registry = {}
local factories = {}

local function module_key(category, id)
    return string.format("%s:%s", category, id)
end

local function resolve_module_path(category, id)
    return string.format("src.blueprints.%s.%s", category, id)
end

local function fetch_entry(category, id)
    local key = module_key(category, id)
    local entry = registry[key]
    if entry then
        return entry
    end

    local module_path = resolve_module_path(category, id)
    local ok, mod = pcall(require, module_path)
    if not ok then
        error(string.format("Failed to load blueprint '%s/%s': %s", category, id, mod), 3)
    end

    local kind = type(mod)
    if kind ~= "table" and kind ~= "function" then
        error(string.format("Blueprint module '%s/%s' must return a table or function, got %s", category, id, kind), 3)
    end

    entry = { kind = kind, value = mod }
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

return loader
