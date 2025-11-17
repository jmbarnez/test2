local constants = require("src.constants.game")
local FloatingText = require("src.effects.floating_text")
local PlayerManager = require("src.player.manager")

local LootRewards = {}

local function resolve_player_id_from_entity(entity)
    if not entity then
        return nil
    end

    if entity.lastDamagePlayerId then
        return entity.lastDamagePlayerId
    end

    local source = entity.lastDamageSource
    if type(source) == "table" then
        return source.playerId
            or source.ownerPlayerId
            or source.lastDamagePlayerId
    end

    return nil
end

local function resolve_loot_player_id(drop, sourceEntity)
    local playerId = resolve_player_id_from_entity(sourceEntity)
    if playerId then
        return playerId
    end

    if drop and type(drop.source) == "table" then
        return resolve_player_id_from_entity(drop.source)
            or drop.source.playerId
            or drop.source.ownerPlayerId
            or drop.source.lastDamagePlayerId
    end

    return nil
end

local function floating_text_offset(localPlayer, extraOffset)
    local base = (localPlayer and localPlayer.mountRadius or 36) + 18
    if extraOffset then
        return base + extraOffset
    end
    return base
end

local function resolve_reward_position(drop, sourceEntity, fallback)
    if drop and drop.position then
        return drop.position
    end

    if sourceEntity and sourceEntity.position then
        return sourceEntity.position
    end

    if fallback and fallback.position then
        return fallback.position
    end

    return nil
end

function LootRewards.apply(state, drop, sourceEntity)
    if not (state and drop) then
        return nil
    end

    local localPlayer = PlayerManager.getLocalPlayer(state)
    local position = resolve_reward_position(drop, sourceEntity, localPlayer)

    local result = {
        xpAwarded = 0,
        creditsAwarded = 0,
    }

    local xpSpec = drop.xp_reward or (drop.raw and drop.raw.xp_reward)
    if type(xpSpec) == "table" and xpSpec.amount then
        local amount = tonumber(xpSpec.amount)
        if amount and amount > 0 then
            local progression_constants = constants.progression or {}
            local category = xpSpec.category or progression_constants.default_xp_category or "combat"
            local skill = xpSpec.skill or progression_constants.default_xp_skill or "weapons"
            local playerId = resolve_loot_player_id(drop, sourceEntity)
            if playerId then
                PlayerManager.addSkillXP(state, category, skill, amount, playerId)
                result.xpAwarded = amount

                if position and FloatingText and FloatingText.add then
                    local ui_constants = (constants.ui and constants.ui.floating_text) or {}
                    local xp_style = ui_constants.xp or {}
                    FloatingText.add(state, position, string.format("+%d XP", amount), {
                        offsetY = floating_text_offset(localPlayer),
                        color = xp_style.color or { 0.3, 0.9, 0.4, 1 },
                        rise = xp_style.rise or 40,
                        scale = xp_style.scale or 1.1,
                        font = xp_style.font or "bold",
                    })
                end
            end
        end
    end

    local credits = drop.credit_reward or (drop.raw and drop.raw.credit_reward)
    if type(credits) == "number" and credits > 0 then
        if localPlayer then
            PlayerManager.adjustCurrency(state, credits)
            result.creditsAwarded = credits

            if position and FloatingText and FloatingText.add then
                local ui_constants = (constants.ui and constants.ui.floating_text) or {}
                local credits_style = ui_constants.credits or {}
                local offset_y = credits_style.offset_y or 22
                FloatingText.add(state, position, string.format("+%d credits", credits), {
                    offsetY = floating_text_offset(localPlayer, offset_y),
                    color = credits_style.color or { 1.0, 0.9, 0.2, 1 },
                    rise = credits_style.rise or 40,
                    scale = credits_style.scale or 1.1,
                    font = credits_style.font or "bold",
                    icon = credits_style.icon or "currency",
                })
            end
        end
    end

    return result
end

return LootRewards
