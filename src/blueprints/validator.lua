local validator = {}

local type_checkers = {
    integer = function(value)
        return type(value) == "number" and math.floor(value) == value
    end,
    number = function(value)
        return type(value) == "number"
    end,
    string = function(value)
        return type(value) == "string"
    end,
    boolean = function(value)
        return type(value) == "boolean"
    end,
    table = function(value)
        return type(value) == "table"
    end,
    array = function(value)
        if type(value) ~= "table" then
            return false
        end

        local count = #value
        if count == 0 then
            return next(value) == nil
        end

        for i = 1, count do
            if value[i] == nil then
                return false
            end
        end

        return true
    end,
    func = function(value)
        return type(value) == "function"
    end,
    any = function()
        return true
    end,
}

local function add_error(errors, path, message)
    if path and path ~= "" then
        errors[#errors + 1] = string.format("%s: %s", path, message)
    else
        errors[#errors + 1] = message
    end
end

local function is_optional(schema)
    if schema.required ~= nil then
        return not schema.required
    end
    return schema.optional == true
end

local function validate_node(schema, value, path, errors)
    path = path or "blueprint"

    if schema == nil then
        return true
    end

    local has_value = value ~= nil
    if not has_value then
        if is_optional(schema) then
            return true
        end

        add_error(errors, path, "missing required value")
        return false
    end

    local expected_type = schema.type or schema.kind or "any"
    local checker = type_checkers[expected_type]

    if not checker then
        error(string.format("Unknown schema type '%s' at %s", tostring(expected_type), path))
    end

    if not checker(value) then
        add_error(errors, path, string.format("expected %s, got %s", expected_type, type(value)))
        return false
    end

    if schema.enum and value ~= nil then
        local valid = false
        for i = 1, #schema.enum do
            if schema.enum[i] == value then
                valid = true
                break
            end
        end
        if not valid then
            add_error(errors, path, string.format("expected one of %s, got %s", table.concat(schema.enum, ", "), tostring(value)))
        end
    end

    if expected_type == "number" or expected_type == "integer" then
        if schema.min and value < schema.min then
            add_error(errors, path, string.format("value %s is below minimum %s", tostring(value), tostring(schema.min)))
        end
        if schema.max and value > schema.max then
            add_error(errors, path, string.format("value %s exceeds maximum %s", tostring(value), tostring(schema.max)))
        end
    elseif expected_type == "string" then
        if schema.min and #value < schema.min then
            add_error(errors, path, string.format("string length %d is below minimum %d", #value, schema.min))
        end
        if schema.max and #value > schema.max then
            add_error(errors, path, string.format("string length %d exceeds maximum %d", #value, schema.max))
        end
    end

    if expected_type == "table" and schema.fields then
        local allow_extra = schema.allow_extra ~= false
        local processed = {}

        for field_name, field_schema in pairs(schema.fields) do
            processed[field_name] = true
            validate_node(field_schema, value[field_name], string.format("%s.%s", path, field_name), errors)
        end

        if not allow_extra then
            for key in pairs(value) do
                if not processed[key] then
                    add_error(errors, string.format("%s.%s", path, tostring(key)), "unexpected field")
                end
            end
        end
    end

    if expected_type == "array" then
        local length = #value
        if schema.min_length and length < schema.min_length then
            add_error(errors, path, string.format("expected at least %d entries, found %d", schema.min_length, length))
        end
        if schema.max_length and length > schema.max_length then
            add_error(errors, path, string.format("expected at most %d entries, found %d", schema.max_length, length))
        end

        if schema.elements then
            for index = 1, length do
                local element = value[index]
                validate_node(schema.elements, element, string.format("%s[%d]", path, index), errors)
            end
        end
    end

    if schema.map then
        if type(value) ~= "table" then
            add_error(errors, path, "expected table for map definition")
            return false
        end

        for key, child in pairs(value) do
            local child_path = string.format("%s[%s]", path, tostring(key))
            validate_node(schema.map, child, child_path, errors)
        end
    end

    if schema.custom then
        local ok, message_or_errors = schema.custom(value)
        if ok == false then
            if type(message_or_errors) == "table" then
                for i = 1, #message_or_errors do
                    add_error(errors, path, message_or_errors[i])
                end
            elseif type(message_or_errors) == "string" then
                add_error(errors, path, message_or_errors)
            else
                add_error(errors, path, "custom validator failed")
            end
        end
    end

    return #errors == 0
end

function validator.validate(schema, data)
    local errors = {}
    local ok = validate_node(schema, data, "blueprint", errors)
    if not ok then
        return false, errors
    end
    if #errors > 0 then
        return false, errors
    end
    return true
end

local function join_errors(errors)
    local lines = {}
    for i = 1, #errors do
        local err = errors[i]
        if err ~= nil then
            lines[#lines + 1] = tostring(err)
        end
    end
    return table.concat(lines, "\n - ")
end

validator.format_errors = join_errors

function validator.assert(schema, data, context)
    local ok, errors = validator.validate(schema, data)
    if ok then
        return data
    end

    local location = context or "blueprint"
    local message = string.format("%s failed validation:\n - %s", location, join_errors(errors))
    error(message, 2)
end

return validator
