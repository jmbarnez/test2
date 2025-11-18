local ItemLabel = {}

local function format_from_id(id)
    if type(id) ~= "string" or id == "" then
        return nil
    end

    local label = id:match(":(.+)$") or id
    label = label:gsub("_", " ")
    if #label == 0 then
        return nil
    end

    return label:sub(1, 1):upper() .. label:sub(2)
end

function ItemLabel.resolve(item)
    if type(item) ~= "table" then
        return "Item"
    end

    if type(item.name) == "string" and item.name ~= "" then
        return item.name
    end

    local label = format_from_id(item.id)
    if label then
        return label
    end

    if type(item.blueprint) == "table" then
        if type(item.blueprint.name) == "string" and item.blueprint.name ~= "" then
            return item.blueprint.name
        end
        label = format_from_id(item.blueprint.id)
        if label then
            return label
        end
    end

    return "Item"
end

return ItemLabel
