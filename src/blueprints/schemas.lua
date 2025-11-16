local schemas = {}

local function vector_schema(is_required)
    return {
        type = "table",
        allow_extra = true,
        fields = {
            x = { type = "number", optional = true },
            y = { type = "number", optional = true },
        },
        optional = not is_required,
        required = is_required,
    }
end

local function range_schema(is_required)
    return {
        type = "table",
        allow_extra = false,
        fields = {
            min = { type = "number", optional = true },
            max = { type = "number", optional = true },
        },
        optional = not is_required,
        required = is_required,
        custom = function(value)
            if value == nil then
                return true
            end

            local min = value.min
            local max = value.max
            if type(min) == "number" and type(max) == "number" and min > max then
                return false, "min must not exceed max"
            end
            return true
        end,
    }
end

local function weapon_reference_schema()
    return {
        type = "any",
        custom = function(value)
            local value_type = type(value)
            if value_type == "string" then
                return true
            end

            if value_type == "table" then
                if value.id or value.weapon or value.blueprint or value[1] then
                    return true
                end
                return false, "weapon entry table requires id/weapon/blueprint field"
            end

            if value == nil then
                return true
            end

            return false, "weapon entry must be string or table"
        end,
    }
end

local collider_schema = {
    type = "table",
    allow_extra = true,
    fields = {
        name = { type = "string", optional = true },
        type = { type = "string", optional = true, enum = { "polygon", "circle" } },
        points = { type = "array", optional = true, min_length = 6 },
        radius = { type = "number", optional = true },
        offset = vector_schema(),
    },
    custom = function(value)
        if type(value) ~= "table" then
            return false, "collider must be a table"
        end

        local collider_type = value.type or "polygon"
        if collider_type == "polygon" then
            if type(value.points) ~= "table" or #value.points < 6 then
                return false, "polygon collider requires 'points' array with at least 6 numbers"
            end
        elseif collider_type == "circle" then
            if type(value.radius) ~= "number" or value.radius <= 0 then
                return false, "circle collider requires positive radius"
            end
        end

        return true
    end,
}

local function colliders_schema(is_required)
    return {
        type = "array",
        elements = collider_schema,
        min_length = 1,
        optional = not is_required,
        required = is_required,
    }
end

local function physics_schema()
    return {
        type = "table",
        optional = true,
        allow_extra = true,
        fields = {
            body = {
                type = "table",
                optional = true,
                allow_extra = true,
                fields = {
                    type = { type = "string", optional = true },
                    fixedRotation = { type = "boolean", optional = true },
                    linearDamping = { type = "number", optional = true },
                    angularDamping = { type = "number", optional = true },
                    gravityScale = { type = "number", optional = true },
                },
            },
            fixture = {
                type = "table",
                optional = true,
                allow_extra = true,
                fields = {
                    density = { type = "number", optional = true },
                    friction = { type = "number", optional = true },
                    restitution = { type = "number", optional = true },
                    sensor = { type = "boolean", optional = true },
                },
            },
        },
    }
end

local function spawn_schema()
    return {
        type = "table",
        optional = true,
        allow_extra = true,
        fields = {
            strategy = { type = "string", optional = true },
            rotation = { type = "number", optional = true },
            x = { type = "number", optional = true },
            y = { type = "number", optional = true },
        },
    }
end

local ship_schema = {
    type = "table",
    allow_extra = true,
    fields = {
        id = { type = "string" },
        category = { type = "string", optional = true },
        name = { type = "string", optional = true },
        spawn = spawn_schema(),
        components = {
            type = "table",
            required = true,
            allow_extra = true,
            fields = {
                type = { type = "string", optional = true },
                player = { type = "boolean", optional = true },
                enemy = { type = "boolean", optional = true },
                position = vector_schema(),
                velocity = vector_schema(),
                rotation = { type = "number", optional = true },
                nonPhysical = { type = "boolean", optional = true },
                drawable = { type = "table", optional = true, allow_extra = true },
                stats = { type = "table", optional = true, allow_extra = true },
                hull = { type = "table", optional = true, allow_extra = true },
                health = { type = "table", optional = true, allow_extra = true },
                energy = { type = "table", optional = true, allow_extra = true },
                cargo = { type = "table", optional = true, allow_extra = true },
                colliders = colliders_schema(false),
                ai = { type = "table", optional = true, allow_extra = true },
            },
            custom = function(value)
                if type(value) ~= "table" then
                    return false, "components must be a table"
                end

                local require_colliders = not value.nonPhysical
                if require_colliders then
                    if type(value.colliders) ~= "table" or #value.colliders == 0 then
                        if value.collider == nil then
                            return false, "ship blueprint requires components.colliders array or components.collider table"
                        end
                        if type(value.collider) ~= "table" then
                            return false, "components.collider must be a table"
                        end
                    end
                end

                return true
            end,
        },
        weapons = {
            type = "array",
            optional = true,
            allow_extra = false,
            elements = {
                type = "any",
                custom = function(element)
                    if element == nil then
                        return false, "weapon entry cannot be nil"
                    end

                    local element_type = type(element)
                    if element_type == "string" then
                        return true
                    end

                    if element_type == "table" then
                        if element.id or element.weapon or element.blueprint or element[1] then
                            return true
                        end
                        return false, "weapon table entry requires id/weapon/blueprint"
                    end

                    return false, "weapon entry must be string or table"
                end,
            },
        },
        physics = physics_schema(),
    },
}

local weapon_component_schema = {
    type = "table",
    required = true,
    allow_extra = true,
    fields = {
        fireMode = { type = "string", optional = true },
        constantKey = { type = "string", optional = true },
        damage = { type = "number", optional = true },
        damagePerSecond = { type = "number", optional = true },
        energyPerShot = { type = "number", optional = true },
        energyPerSecond = { type = "number", optional = true },
        projectileBlueprint = { type = "table", optional = true, allow_extra = true },
    },
    custom = function(value)
        if type(value) ~= "table" then
            return false, "weapon component must be a table"
        end

        if value.fireMode == nil and value.constantKey == nil then
            return false, "weapon component requires fireMode or constantKey"
        end

        return true
    end,
}

local weapon_schema = {
    type = "table",
    allow_extra = true,
    fields = {
        id = { type = "string" },
        category = { type = "string", optional = true },
        name = { type = "string", optional = true },
        assign = { type = "string", optional = true },
        icon = { type = "table", optional = true, allow_extra = true },
        components = {
            type = "table",
            required = true,
            allow_extra = true,
            fields = {
                weapon = weapon_component_schema,
                weaponMount = { type = "table", optional = true, allow_extra = true },
            },
        },
    },
}

local module_schema = {
    type = "table",
    allow_extra = true,
    fields = {
        id = { type = "string" },
        category = { type = "string", optional = true },
        name = { type = "string", optional = true },
        slot = { type = "string", optional = true },
        rarity = { type = "string", optional = true },
        description = { type = "string", optional = true },
        icon = { type = "table", optional = true, allow_extra = true },
        item = { type = "table", optional = true, allow_extra = true },
        components = {
            type = "table",
            required = true,
            allow_extra = true,
            fields = {
                module = { type = "table", optional = true, allow_extra = true },
            },
            custom = function(value)
                if type(value) ~= "table" then
                    return false, "components must be a table"
                end

                local module_component = value.module
                if module_component == nil then
                    return false, "module blueprint requires components.module table"
                end

                if type(module_component) ~= "table" then
                    return false, "components.module must be a table"
                end

                return true
            end,
        },
    },
}

local asteroid_schema = {
    type = "table",
    allow_extra = true,
    fields = {
        id = { type = "string" },
        category = { type = "string", optional = true },
        name = { type = "string", optional = true },
        components = {
            type = "table",
            required = true,
            allow_extra = true,
            fields = {
                asteroid = { type = "boolean", optional = true },
                position = vector_schema(),
                velocity = vector_schema(),
                rotation = { type = "number", optional = true },
                drawable = { type = "table", optional = true, allow_extra = true },
                health = { type = "table", optional = true, allow_extra = true },
                healthBar = { type = "table", optional = true, allow_extra = true },
            },
        },
        physics = physics_schema(),
    },
}

local sector_enemy_schema = {
    type = "table",
    optional = true,
    allow_extra = true,
    fields = {
        id = { type = "string", optional = true },
        ship_id = { type = "string", optional = true },
        ship_ids = {
            type = "array",
            optional = true,
            elements = {
                type = "table",
                allow_extra = true,
                fields = {
                    id = { type = "string" },
                    weight = { type = "number", optional = true },
                },
            },
        },
        count = range_schema(),
        spawn_radius = { type = "number", optional = true },
        spawn_safe_radius = { type = "number", optional = true },
        wander_radius = { type = "number", optional = true },
    },
}

local sector_schema = {
    type = "table",
    allow_extra = true,
    fields = {
        id = { type = "string" },
        category = { type = "string", optional = true },
        name = { type = "string", optional = true },
        asteroids = {
            type = "table",
            optional = true,
            allow_extra = true,
            fields = {
                count = range_schema(),
            },
        },
        enemies = sector_enemy_schema,
        stations = {
            type = "array",
            optional = true,
            elements = {
                type = "table",
                allow_extra = true,
                fields = {
                    id = { type = "string" },
                    position = vector_schema(),
                },
            },
        },
        warpgates = {
            type = "array",
            optional = true,
            elements = {
                type = "table",
                allow_extra = true,
                fields = {
                    id = { type = "string" },
                    position = vector_schema(),
                    rotation = { type = "number", optional = true },
                    offset = vector_schema(),
                    context = {
                        type = "table",
                        optional = true,
                        allow_extra = true,
                    },
                },
            },
        },
        worldBounds = {
            type = "table",
            optional = true,
            allow_extra = true,
            fields = {
                x = { type = "number", optional = true },
                y = { type = "number", optional = true },
                width = { type = "number", optional = true },
                height = { type = "number", optional = true },
            },
        },
    },
}

local registry = {
    ships = ship_schema,
    stations = ship_schema,
    weapons = weapon_schema,
    modules = module_schema,
    asteroids = asteroid_schema,
    sectors = sector_schema,
}

function schemas.for_category(category)
    return registry[category]
end

return schemas
