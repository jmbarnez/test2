local validator = require("src.blueprints.validator")
local schemas = require("src.blueprints.schemas")

local Blueprint = {}

function Blueprint.schema_for(category)
    return schemas.for_category(category)
end

function Blueprint.validate(schema_or_category, data)
    local schema = schema_or_category

    if type(schema_or_category) == "string" then
        schema = schemas.for_category(schema_or_category)
    end

    if not schema then
        return true
    end

    return validator.validate(schema, data)
end

function Blueprint.assert(schema_or_category, data, context)
    local schema = schema_or_category
    local resolved_context = context

    if type(schema_or_category) == "string" then
        schema = schemas.for_category(schema_or_category)
        resolved_context = context or string.format("blueprint category '%s'", schema_or_category)
    end

    if not schema then
        return data
    end

    return validator.assert(schema, data, resolved_context)
end

function Blueprint.format_errors(errors)
    return validator.format_errors(errors)
end

return Blueprint
